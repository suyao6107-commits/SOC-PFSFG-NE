"""
predict_uncertainty.py
=======================

Generates spatial predictions of SOC stocks across the study area using
the trained CarbonStockPredictor ANN (see model.py / train_model.py),
together with a joint uncertainty estimate combining:

  - MC Dropout (epistemic / model-structure uncertainty), and
  - Monte Carlo Error Propagation (MCEP; aleatoric uncertainty from
    input-feature measurement error, modeled as Gaussian noise on each
    standardized predictor, magnitude = config.FEATURE_NOISE_RATIO).

Usage
-----
    python predict_uncertainty.py

Requirements
------------
- A trained model (output/soc_ann_model.pth) and fitted scaler
  (output/scaler_X.pkl), produced by train_model.py.
- A set of aligned, single-band GeoTIFF raster layers, one per predictor
  in config.FEATURE_NAMES (file names given by config.TIF_FILES), all
  with identical extent, resolution, and CRS, located in config.TIF_DIR.
- (Optional) An independent validation CSV (config.VALIDATION_CSV) with
  longitude, latitude, and observed SOC stock columns, used to assess
  prediction-interval coverage and spatial autocorrelation of residuals.
  If this file is absent, the validation step is skipped automatically.

Outputs (written to config.OUTPUT_DIR)
---------------------------------------
- soc_pred_mean.tif, soc_pred_std.tif
- soc_pred_lower95.tif, soc_pred_upper95.tif, soc_pi_width95.tif
- soc_percent_uncertainty.tif
- soc_stock_stats.csv          : regional stock totals/densities,
                                   partitioned by frozen type and
                                   ecosystem type
- validation_detail.csv, calibration_curve.csv, uncertainty_summary.csv
  (only written if config.VALIDATION_CSV exists)
"""

import os
import pickle

import numpy as np
import pandas as pd
import rasterio
from rasterio.warp import transform as rio_transform
import torch
from tqdm import tqdm

from model import CarbonStockPredictor
import config


# ---------------------------------------------------------------------------
# Raster I/O helpers
# ---------------------------------------------------------------------------
def load_rasters():
    """Stack all predictor rasters listed in config.TIF_FILES into a
    single array, applying per-raster valid-value masking
    (config.VALID_RANGES).

    Returns
    -------
    X_valid : ndarray, shape (n_valid_pixels, n_features)
        Predictor values at pixels where all predictors are valid.
    mask : ndarray of bool, shape (height, width)
        True at pixels where all predictors are valid.
    meta : dict
        Rasterio profile of the first raster (used as a template for
        writing output rasters).
    ft_layer, et_layer : ndarray, shape (height, width)
        Raw frozen-type / ecosystem-type rasters, used to partition
        regional summary statistics.
    transform, crs, height, width
        Spatial reference information for the raster stack.
    """
    stack_list, meta = [], None
    ft_layer = et_layer = None
    transform = crs = height = width = None

    for i, fname in enumerate(config.TIF_FILES):
        path = os.path.join(config.TIF_DIR, fname)
        with rasterio.open(path) as src:
            arr = src.read(1).astype(np.float32)
            arr[arr <= -3e38] = np.nan
            if src.nodata is not None:
                arr[arr == src.nodata] = np.nan

            vmin, vmax = config.VALID_RANGES[i]
            arr[(arr < vmin) | (arr > vmax)] = np.nan

            stack_list.append(arr)
            if config.FEATURE_NAMES[i] == 'FT':
                ft_layer = arr.copy()
            if config.FEATURE_NAMES[i] == 'ET':
                et_layer = arr.copy()

            if meta is None:
                meta = src.profile.copy()
                transform = src.transform
                crs = src.crs
                height, width = src.height, src.width

    X_stack = np.stack(stack_list, axis=-1)
    mask = ~np.any(np.isnan(X_stack), axis=-1)
    return X_stack[mask], mask, meta, ft_layer, et_layer, transform, crs, height, width


def calculate_pixel_area(height, width, transform, crs):
    """Return a (height, width) array of pixel areas in m^2.

    For geographic (lon/lat) CRSs, pixel width varies with latitude, so
    pixel area is computed accordingly. For projected CRSs, pixel area is
    constant and derived directly from the affine transform.
    """
    if crs.is_projected:
        return np.full((height, width), abs(transform.a * transform.e), dtype=np.float32)

    earth_radius = 6378137.0
    rows = np.arange(height) + 0.5
    _, lats = rasterio.transform.xy(transform, rows, np.zeros(height), offset='center')
    pixel_width = earth_radius * np.radians(abs(transform.a)) * np.cos(np.radians(np.array(lats)))
    pixel_height = earth_radius * np.radians(abs(transform.e))
    return (np.outer(np.full(height, pixel_height), np.ones(width))
            * pixel_width[:, np.newaxis]).astype(np.float32)


def bilinear_sample(arr, r, c):
    """Bilinear interpolation of 2D array `arr` at fractional row/col
    (r, c). Returns NaN if (r, c) is outside the valid interpolation
    range."""
    h, w = arr.shape
    r0, c0 = int(np.floor(r)), int(np.floor(c))
    r1, c1 = r0 + 1, c0 + 1
    if r0 < 0 or c0 < 0 or r1 >= h or c1 >= w:
        return np.nan
    dr, dc = r - r0, c - c0
    return (arr[r0, c0] * (1 - dr) * (1 - dc) + arr[r0, c1] * (1 - dr) * dc +
            arr[r1, c0] * dr * (1 - dc) + arr[r1, c1] * dr * dc)


def nearest_sample(arr, r, c):
    """Nearest-neighbour lookup of 2D array `arr` at fractional row/col
    (r, c). Returns NaN if (r, c) is out of bounds. Used for categorical
    rasters (e.g. frozen type, ecosystem type) where interpolation is not
    meaningful."""
    h, w = arr.shape
    rr, cc = int(round(r)), int(round(c))
    if 0 <= rr < h and 0 <= cc < w:
        return arr[rr, cc]
    return np.nan


def save_tif(path, data, meta):
    """Write a 2D array to a single-band GeoTIFF, using -9999 as the
    nodata value for NaN pixels."""
    out = np.where(np.isnan(data), -9999, data).astype(np.float32)
    out_meta = meta.copy()
    out_meta.update(dtype=rasterio.float32, count=1, compress='lzw', nodata=-9999)
    with rasterio.open(path, "w", **out_meta) as dst:
        dst.write(out, 1)


# ---------------------------------------------------------------------------
# Uncertainty quantification
# ---------------------------------------------------------------------------
def mc_dropout_with_input_noise(model, inputs, n_iter, feature_noise_ratios,
                                 batch_size=50000):
    """Joint MC Dropout + Monte Carlo Error Propagation (MCEP).

    For each of `n_iter` forward passes:

    1. Gaussian noise proportional to `feature_noise_ratios` (relative to
       the magnitude of each standardized feature) is added to the
       inputs, representing measurement/observation error in the
       environmental covariates (aleatoric uncertainty, MCEP).
    2. Dropout layers remain stochastic (model.enable_mc_dropout()),
       while BatchNorm layers stay in eval mode with fixed running
       statistics, representing model-structure uncertainty (epistemic,
       MC Dropout) without introducing batch-size-dependent noise.

    Predictions are clipped at zero to respect the physical
    non-negativity of SOC stocks.

    Parameters
    ----------
    model : CarbonStockPredictor
    inputs : torch.Tensor, shape (n_pixels, n_features)
    n_iter : int
        Number of Monte Carlo forward passes.
    feature_noise_ratios : torch.Tensor, shape (n_features,)
        Relative noise magnitude for each (standardized) feature.
    batch_size : int
        Pixels are processed in batches to limit memory usage.

    Returns
    -------
    mc_preds : ndarray, shape (n_iter, n_pixels)
        Predictions from each Monte Carlo forward pass.
    """
    model.enable_mc_dropout()
    n = len(inputs)
    mc_preds = np.zeros((n_iter, n), dtype=np.float32)
    device = inputs.device if isinstance(inputs, torch.Tensor) else 'cpu'

    with torch.no_grad():
        for i in tqdm(range(n_iter), desc="MC + MCEP sampling"):
            for s in range(0, n, batch_size):
                e = min(s + batch_size, n)
                batch_inputs = inputs[s:e].clone()

                if feature_noise_ratios is not None:
                    noise_std = torch.abs(batch_inputs) * feature_noise_ratios.to(device)
                    noise = torch.randn_like(batch_inputs) * noise_std
                    batch_inputs = batch_inputs + noise

                out = model(batch_inputs).cpu().numpy().flatten()
                mc_preds[i, s:e] = out

    return np.maximum(mc_preds, 0)  # enforce SOC stock >= 0


# ---------------------------------------------------------------------------
# Calibration and spatial autocorrelation diagnostics
# ---------------------------------------------------------------------------
def calibration_analysis(y_true, pred_mean, pred_std, output_path):
    """Compare nominal vs. empirical coverage of prediction intervals
    across a range of confidence levels, and return the Expected
    Calibration Error (ECE) -- the mean absolute difference between
    expected and observed coverage."""
    alphas = np.arange(0.05, 1.0, 0.05)
    records = []
    for a in alphas:
        if a <= 0.05:
            z = 1.96
        elif a <= 0.1:
            z = 1.645
        else:
            z = np.percentile(np.random.standard_normal(100000), (1 - a / 2) * 100)

        lower = pred_mean - z * pred_std
        upper = pred_mean + z * pred_std
        actual = np.mean((y_true >= lower) & (y_true <= upper))
        records.append({"Expected_Coverage": round(1 - a, 2),
                         "Actual_Coverage": round(float(actual), 4)})

    df = pd.DataFrame(records)
    df.to_csv(output_path, index=False)
    ece = float(np.mean(np.abs(df['Expected_Coverage'] - df['Actual_Coverage'])))
    return df, ece


def morans_i_simplified(residuals_map, mask, n_sample=5000, seed=42, k_neighbors=8):
    """Compute a simplified global Moran's I statistic for spatial
    autocorrelation of residuals, using a k-nearest-neighbour weight
    matrix over a random subsample of valid pixels.

    Returns None if fewer than 100 valid residuals are available.
    """
    rng = np.random.RandomState(seed)
    rows, cols = np.where(mask)
    if len(rows) > n_sample:
        idx = rng.choice(len(rows), n_sample, replace=False)
        rows, cols = rows[idx], cols[idx]

    vals = residuals_map[rows, cols]
    valid = ~np.isnan(vals)
    rows, cols, vals = rows[valid], cols[valid], vals[valid]
    if len(vals) < 100:
        return None

    deviations = vals - vals.mean()
    coords = np.stack([rows, cols], axis=1).astype(float)

    numerator, weight_sum = 0.0, 0.0
    for i in range(len(coords)):
        dists = np.sum((coords - coords[i]) ** 2, axis=1)
        neighbor_idx = np.argsort(dists)[1:k_neighbors + 1]
        for j in neighbor_idx:
            numerator += deviations[i] * deviations[j]
            weight_sum += 1.0

    denom = np.sum(deviations ** 2)
    n = len(vals)
    return (n / weight_sum) * (numerator / denom) if (denom > 0 and weight_sum > 0) else 0.0


# ---------------------------------------------------------------------------
# Optional validation against independent field observations
# ---------------------------------------------------------------------------
def run_validation(val_path, pred_mean, pred_std, pred_lower, pred_upper,
                    pred_pct_uncertainty, ft_layer, et_layer, mask, height, width,
                    transform, crs):
    """Compare gridded predictions against an independent point dataset
    of field-observed SOC stocks.

    Computes RMSE, MAE, bias, empirical 95% prediction-interval coverage,
    a calibration curve, the Expected Calibration Error, and Moran's I of
    the spatial residuals. Results are written to
    config.OUTPUT_DIR/validation_detail.csv,
    config.OUTPUT_DIR/calibration_curve.csv, and
    config.OUTPUT_DIR/uncertainty_summary.csv.

    The validation CSV must contain longitude/latitude columns (named
    'lon'/'lat' or 'x'/'y') and an observed-SOC column (named 'soc_obs' or
    'soc'); if these are not found, validation is skipped with a warning.
    """
    df_val = pd.read_csv(val_path)
    cols = {c.lower(): c for c in df_val.columns}
    lon_c = cols.get('lon') or cols.get('x')
    lat_c = cols.get('lat') or cols.get('y')
    obs_c = cols.get('soc_obs') or cols.get('soc')

    if not (lon_c and lat_c and obs_c):
        print("  Validation CSV must contain longitude, latitude, and observed "
              "SOC columns (e.g. 'lon', 'lat', 'soc_obs'); skipping validation.")
        return

    def make_map(values):
        m = np.full((height, width), np.nan, dtype=np.float32)
        m[mask] = values
        return m

    map_mean = make_map(pred_mean)
    map_std = make_map(pred_std)
    map_lower = make_map(pred_lower)
    map_upper = make_map(pred_upper)
    map_uncert = make_map(pred_pct_uncertainty)

    xs, ys = (rio_transform('EPSG:4326', crs, df_val[lon_c].values, df_val[lat_c].values)
              if crs.is_projected else (df_val[lon_c].values, df_val[lat_c].values))
    inv_t = ~transform

    samples = []
    for i, (x, y) in enumerate(zip(xs, ys)):
        c_px, r_px = inv_t * (x, y)
        p = bilinear_sample(map_mean, r_px, c_px)
        if np.isnan(p):
            continue
        sd = bilinear_sample(map_std, r_px, c_px)
        lo = bilinear_sample(map_lower, r_px, c_px)
        hi = bilinear_sample(map_upper, r_px, c_px)
        un = bilinear_sample(map_uncert, r_px, c_px)
        ft = nearest_sample(ft_layer, r_px, c_px)
        et = nearest_sample(et_layer, r_px, c_px)
        obs = df_val[obs_c].values[i]

        samples.append({
            "Lon": df_val[lon_c].values[i],
            "Lat": df_val[lat_c].values[i],
            "Observed": obs,
            "Predicted": p,
            "Pred_Std": sd,
            "Lower95": lo,
            "Upper95": hi,
            "In_95PI": int(lo <= obs <= hi),
            "PI_Width": hi - lo,
            "Uncertainty_pct": un,
            "FT_Code": ft,
            "ET_Code": et,
        })

    df_res = pd.DataFrame(samples)
    df_res.to_csv(os.path.join(config.OUTPUT_DIR, "validation_detail.csv"), index=False)

    overall_cov = df_res['In_95PI'].mean()
    print(f"  95% PI empirical coverage: {overall_cov:.3f} (nominal: 0.95)")

    _, ece = calibration_analysis(
        df_res['Observed'].values, df_res['Predicted'].values, df_res['Pred_Std'].values,
        os.path.join(config.OUTPUT_DIR, "calibration_curve.csv"))

    res_map = np.full((height, width), np.nan, dtype=np.float32)
    inv = ~transform
    for _, row in df_res.iterrows():
        c_px, r_px = inv * (row['Lon'], row['Lat'])
        ri, ci = int(round(r_px)), int(round(c_px))
        if 0 <= ri < height and 0 <= ci < width:
            res_map[ri, ci] = row['Observed'] - row['Predicted']

    mi = morans_i_simplified(res_map, ~np.isnan(res_map))

    y_obs = df_res['Observed'].values
    y_pred = df_res['Predicted'].values
    rmse = float(np.sqrt(np.mean((y_obs - y_pred) ** 2)))
    mae = float(np.mean(np.abs(y_obs - y_pred)))
    bias = float(np.mean(y_pred - y_obs))
    pi_width = float(df_res['PI_Width'].mean())

    summary = pd.DataFrame([{
        "N_Validation": len(df_res),
        "RMSE": round(rmse, 4),
        "MAE": round(mae, 4),
        "Bias": round(bias, 4),
        "Coverage_95PI": round(float(overall_cov), 4),
        "Mean_PI_Width": round(pi_width, 4),
        "ECE": round(ece, 4),
        "Morans_I": round(float(mi) if mi is not None else np.nan, 4),
    }])
    summary.to_csv(os.path.join(config.OUTPUT_DIR, "uncertainty_summary.csv"), index=False)

    print("\n" + "=" * 55)
    print("Independent validation summary")
    print("=" * 55)
    print(summary.to_string(index=False))


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------
def main():
    print("=" * 60)
    print("SOC spatial prediction with MC Dropout + MCEP uncertainty")
    print("=" * 60)

    os.makedirs(config.OUTPUT_DIR, exist_ok=True)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    # --- A. Load trained model and scaler ---
    with open(os.path.join(config.MODEL_DIR, "scaler_X.pkl"), "rb") as f:
        scaler = pickle.load(f)

    model = CarbonStockPredictor(len(config.FEATURE_NAMES),
                                  dropout_rate=config.DROPOUT_RATE).to(device)
    model.load_state_dict(
        torch.load(os.path.join(config.MODEL_DIR, "soc_ann_model.pth"),
                   map_location=device))
    print("Model loaded.")

    # --- B. Load and stack raster predictors ---
    print("\nLoading raster predictors...")
    X_valid, mask, meta, ft_layer, et_layer, transform, crs, height, width = load_rasters()
    print(f"  Valid pixels: {np.count_nonzero(mask):,}")

    X_scaled = np.clip(scaler.transform(X_valid), -10, 10)
    inputs = torch.tensor(X_scaled, dtype=torch.float32).to(device)

    # --- C. Joint uncertainty quantification (MC Dropout + MCEP) ---
    print(f"\nRunning {config.MC_ITERATIONS} MC + MCEP iterations "
          f"(feature noise ratio = {config.FEATURE_NOISE_RATIO})...")
    noise_ratios = torch.full((len(config.FEATURE_NAMES),),
                               config.FEATURE_NOISE_RATIO, dtype=torch.float32).to(device)

    mc_preds = mc_dropout_with_input_noise(
        model, inputs, n_iter=config.MC_ITERATIONS, feature_noise_ratios=noise_ratios)

    pred_mean = mc_preds.mean(axis=0)
    pred_std = mc_preds.std(axis=0)

    z = config.CONFIDENCE_Z
    pred_lower = np.maximum(pred_mean - z * pred_std, 0)
    pred_upper = pred_mean + z * pred_std
    pred_pi_width = pred_upper - pred_lower
    pred_pct_uncertainty = np.where(pred_mean > 1e-6,
                                     (z * pred_std) / pred_mean * 100.0, np.nan)

    print(f"  Mean predicted SOC = {pred_mean.mean():.3f} kg/m^2 "
          f"| mean relative uncertainty = {np.nanmean(pred_pct_uncertainty):.1f}%")

    # --- D. Save raster outputs ---
    print("\nSaving uncertainty rasters...")

    def make_map(values):
        m = np.full((height, width), np.nan, dtype=np.float32)
        m[mask] = values
        return m

    layers = {
        "soc_pred_mean.tif": make_map(pred_mean),
        "soc_pred_std.tif": make_map(pred_std),
        "soc_percent_uncertainty.tif": make_map(pred_pct_uncertainty),
        "soc_pred_lower95.tif": make_map(pred_lower),
        "soc_pred_upper95.tif": make_map(pred_upper),
        "soc_pi_width95.tif": make_map(pred_pi_width),
    }
    for fname, data in layers.items():
        save_tif(os.path.join(config.OUTPUT_DIR, fname), data, meta)
        print(f"  Wrote {fname}")

    # --- E. Regional stock statistics, partitioned by FT and ET ---
    print("\nComputing regional stock statistics...")
    area_grid = calculate_pixel_area(height, width, transform, crs)
    v_area = area_grid[mask]
    v_stock = pred_mean * v_area
    v_lo = pred_lower * v_area
    v_hi = pred_upper * v_area
    v_ft, v_et = ft_layer[mask], et_layer[mask]

    def get_stats(selection, type_str, category_str):
        area = np.sum(v_area[selection])
        stock = np.sum(v_stock[selection])
        lo = np.sum(v_lo[selection])
        hi = np.sum(v_hi[selection])
        density = stock / area if area > 0 else 0

        mu_sel = pred_mean[selection]
        std_sel = pred_std[selection]
        pct_uncert_px = np.where(mu_sel > 1e-6, (z * std_sel) / mu_sel * 100.0, np.nan)
        valid = ~np.isnan(pct_uncert_px)
        a_sel = v_area[selection]
        avg_pct_uncert = (float(np.sum(pct_uncert_px[valid] * a_sel[valid]) / np.sum(a_sel[valid]))
                          if valid.any() else np.nan)

        # Spatial heterogeneity (coefficient of variation of pixel means)
        spatial_sd = np.std(mu_sel)
        spatial_cv = (spatial_sd / density * 100.0) if density > 0 else np.nan

        return {
            "Type": type_str,
            "Category": category_str,
            "Area_km2": round(area / 1e6, 2),
            "Stock_PgC": round(stock / 1e12, 6),
            "Stock_95PI_Lo_PgC": round(lo / 1e12, 6),
            "Stock_95PI_Hi_PgC": round(hi / 1e12, 6),
            "Avg_Density_kg_m2": round(density, 4),
            "Spatial_CV_pct": round(spatial_cv, 2),
            "Uncertainty_pct": round(avg_pct_uncert, 2),
        }

    stats = [get_stats(np.ones(len(v_area), dtype=bool), "Total", "All")]
    for code, label in config.FT_LABELS.items():
        stats.append(get_stats(v_ft == code, "FT", label))
    for code, label in config.ET_LABELS.items():
        stats.append(get_stats(v_et == code, "ET", label))

    df_stats = pd.DataFrame(stats)
    df_stats.to_csv(os.path.join(config.OUTPUT_DIR, "soc_stock_stats.csv"), index=False)
    print(df_stats.to_string(index=False))

    # --- F. Optional validation against independent field observations ---
    if os.path.exists(config.VALIDATION_CSV):
        print("\nValidating against independent field observations...")
        run_validation(config.VALIDATION_CSV, pred_mean, pred_std, pred_lower, pred_upper,
                        pred_pct_uncertainty, ft_layer, et_layer, mask, height, width,
                        transform, crs)
    else:
        print(f"\nNo validation CSV found at {config.VALIDATION_CSV}; skipping validation step.")

    print(f"\nDone. All outputs written to: {config.OUTPUT_DIR}")


if __name__ == "__main__":
    main()