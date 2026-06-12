"""
train_model.py
==============

Trains the CarbonStockPredictor ANN (see model.py) to predict soil
organic carbon (SOC) stocks from environmental and biotic predictors.

Usage
-----
    python train_model.py

Input
-----
A CSV file (default: config.TRAIN_CSV, i.e. demo_data/demo_soc_data.csv)
with the following columns:

    FT, ET, MT, pH, MBC, MAT, MAP, NDSI, NDVI, stock

where FT/ET/MT are categorical strings encoded according to
config.FT_MAPPING / config.ET_MAPPING / config.MT_MAPPING, and 'stock' is
the SOC stock target variable (kg C m^-2).

Output (written to ../output/, relative to this file)
-------------------------------------------------------
- soc_ann_model.pth          : trained model weights (state_dict)
- scaler_X.pkl                : fitted StandardScaler for input features
- feature_names.txt           : feature order used for training (must
                                  match config.FEATURE_NAMES and the
                                  TIF_FILES order used by
                                  predict_uncertainty.py)
- training_diagnostics.png    : training/test loss curves and
                                  predicted-vs-observed scatter plot
- test_error_distribution.png : percentage-error boxplot (test set)
- soc_distribution.png        : histogram of observed SOC stocks
"""

import os
import pickle
import math

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")  # allow running on headless systems
import matplotlib.pyplot as plt
import torch
import torch.nn as nn
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score

from model import CarbonStockPredictor
import config


# ---------------------------------------------------------------------------
# Reproducibility
# ---------------------------------------------------------------------------
def set_seed(seed):
    """Set random seeds for numpy and torch (and CUDA, if available) to
    make results reproducible."""
    torch.manual_seed(seed)
    np.random.seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)
        torch.backends.cudnn.deterministic = True
        torch.backends.cudnn.benchmark = False


# ---------------------------------------------------------------------------
# Data loading and preprocessing
# ---------------------------------------------------------------------------
def load_data(csv_path):
    """Load the SOC dataset, encode categorical variables, and return the
    feature matrix X, target vector y, and the feature column order.

    Raises
    ------
    AssertionError
        If the order of numeric predictor columns in the CSV does not
        match config.FEATURE_NAMES. This check exists because
        predict_uncertainty.py assumes the same feature order when
        stacking raster predictors (config.TIF_FILES); a silent mismatch
        here would otherwise produce incorrect spatial predictions.
    """
    df = pd.read_csv(csv_path).dropna()

    df['FT'] = df['FT'].map(config.FT_MAPPING).astype('float32')
    df['ET'] = df['ET'].map(config.ET_MAPPING).astype('float32')
    df['MT'] = df['MT'].map(config.MT_MAPPING).astype('float32')

    numeric_cols = df.select_dtypes(include=np.number).columns
    feature_cols = numeric_cols.drop('stock')

    print("Feature order found in training CSV:")
    print(feature_cols.tolist())
    assert feature_cols.tolist() == config.FEATURE_NAMES, (
        "Feature order in the input CSV does not match config.FEATURE_NAMES.\n"
        f"  CSV order:    {feature_cols.tolist()}\n"
        f"  Expected (config.FEATURE_NAMES): {config.FEATURE_NAMES}\n"
        "Reorder the CSV columns or update config.FEATURE_NAMES (and "
        "config.TIF_FILES / config.VALID_RANGES accordingly) so that all "
        "three stay consistent."
    )

    X = df[feature_cols].values
    y = df['stock'].values
    return X, y, feature_cols.tolist()


# ---------------------------------------------------------------------------
# Evaluation helper
# ---------------------------------------------------------------------------
def compute_metrics(y_true, y_pred):
    """Return (MSE, RMSE, MAE, R^2) for predictions vs. observations."""
    mse = float(mean_squared_error(y_true, y_pred))
    rmse = float(math.sqrt(mse))
    mae = float(mean_absolute_error(y_true, y_pred))
    r2 = float(r2_score(y_true, y_pred))
    return mse, rmse, mae, r2


# ---------------------------------------------------------------------------
# Training loop
# ---------------------------------------------------------------------------
def train(model, X_train, y_train, X_test, y_test,
          epochs=config.EPOCHS, check_freq=config.CHECK_FREQ,
          lr=config.LEARNING_RATE, weight_decay=config.WEIGHT_DECAY):
    """Train the model with Adam + MSE loss, logging train/test metrics
    every `check_freq` epochs.

    Returns
    -------
    train_log, test_log : list of dict
        Per-checkpoint metrics (epoch, mse, rmse, mae, r2).
    stored_epochs : list of int
        Epoch numbers corresponding to train_log / test_log entries.
    """
    criterion = nn.MSELoss()
    optimizer = torch.optim.Adam(model.parameters(), lr=lr, weight_decay=weight_decay)

    X_train_t = torch.tensor(X_train, dtype=torch.float32)
    y_train_t = torch.tensor(y_train, dtype=torch.float32).unsqueeze(1)
    X_test_t = torch.tensor(X_test, dtype=torch.float32)

    train_log, test_log, stored_epochs = [], [], []

    for epoch in range(epochs):
        model.train()
        optimizer.zero_grad()
        outputs = model(X_train_t)
        loss = criterion(outputs, y_train_t)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        optimizer.step()

        if (epoch + 1) % check_freq == 0:
            model.eval()
            with torch.no_grad():
                train_preds = model(X_train_t).numpy().flatten()
                test_preds = model(X_test_t).numpy().flatten()

            train_mse, train_rmse, train_mae, train_r2 = compute_metrics(y_train, train_preds)
            test_mse, test_rmse, test_mae, test_r2 = compute_metrics(y_test, test_preds)

            train_log.append(dict(epoch=epoch + 1, mse=train_mse, rmse=train_rmse,
                                   mae=train_mae, r2=train_r2))
            test_log.append(dict(epoch=epoch + 1, mse=test_mse, rmse=test_rmse,
                                  mae=test_mae, r2=test_r2))
            stored_epochs.append(epoch + 1)

            print(f"Epoch {epoch + 1}/{epochs}:")
            print(f"  Train -> n={len(y_train)} | MSE={train_mse:.4f} RMSE={train_rmse:.4f} "
                  f"MAE={train_mae:.4f} R2={train_r2:.4f}")
            print(f"  Test  -> n={len(y_test)}  | MSE={test_mse:.4f} RMSE={test_rmse:.4f} "
                  f"MAE={test_mae:.4f} R2={test_r2:.4f}")

    return train_log, test_log, stored_epochs


# ---------------------------------------------------------------------------
# Final evaluation and plots
# ---------------------------------------------------------------------------
def evaluate_and_plot(model, X_train, y_train, X_test, y_test,
                       train_log, test_log, stored_epochs, output_dir):
    """Compute final train/test metrics, save diagnostic plots, and print
    a summary to the console."""
    model.eval()
    with torch.no_grad():
        test_preds = model(torch.tensor(X_test, dtype=torch.float32)).numpy().flatten()
        train_preds = model(torch.tensor(X_train, dtype=torch.float32)).numpy().flatten()

    train_mse, train_rmse, train_mae, train_r2 = compute_metrics(y_train, train_preds)
    test_mse, test_rmse, test_mae, test_r2 = compute_metrics(y_test, test_preds)

    # --- Training progress + predicted-vs-observed scatter ---
    fig, axes = plt.subplots(1, 2, figsize=(12, 6))

    train_mse_series = [item['mse'] for item in train_log]
    test_mse_series = [item['mse'] for item in test_log]
    axes[0].plot(stored_epochs, train_mse_series, label='Train MSE')
    axes[0].plot(stored_epochs, test_mse_series, label='Test MSE')
    axes[0].set_xlabel(f'Epoch (every {config.CHECK_FREQ})')
    axes[0].set_ylabel('MSE (original scale)')
    axes[0].set_title('Training progress (MSE)')
    axes[0].legend()

    axes[1].scatter(y_test, test_preds, alpha=0.6, s=10)
    mn = min(y_test.min(), test_preds.min())
    mx = max(y_test.max(), test_preds.max())
    axes[1].plot([mn, mx], [mn, mx], 'r--')
    axes[1].set_xlabel('Observed SOC stock (kg C m$^{-2}$)')
    axes[1].set_ylabel('Predicted SOC stock (kg C m$^{-2}$)')
    axes[1].set_title(f'Test set predictions (R² = {test_r2:.3f})')

    fig.tight_layout()
    fig.savefig(os.path.join(output_dir, "training_diagnostics.png"), dpi=300)
    plt.close(fig)

    # --- Percentage error distribution (test set) ---
    error_percent = np.abs((test_preds - y_test) / (y_test + 1e-6)) * 100
    fig2, ax2 = plt.subplots(figsize=(6, 4))
    ax2.boxplot(error_percent)
    ax2.set_title('Percentage error distribution (test set)')
    ax2.set_ylabel('Error (%)')
    fig2.tight_layout()
    fig2.savefig(os.path.join(output_dir, "test_error_distribution.png"), dpi=300)
    plt.close(fig2)

    print("\n===== Final Evaluation Summary =====")
    print(f"Train samples: {len(y_train)}")
    print(f"  Train MSE  = {train_mse:.4f}")
    print(f"  Train RMSE = {train_rmse:.4f}")
    print(f"  Train MAE  = {train_mae:.4f}")
    print(f"  Train R^2  = {train_r2:.4f}\n")

    print(f"Test samples: {len(y_test)}")
    print(f"  Test MSE  = {test_mse:.4f}")
    print(f"  Test RMSE = {test_rmse:.4f}")
    print(f"  Test MAE  = {test_mae:.4f}")
    print(f"  Test R^2  = {test_r2:.4f}\n")

    print(f"Median error (%):      {np.median(error_percent):.2f}%")
    print(f"95th percentile error: {np.percentile(error_percent, 95):.2f}%")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    set_seed(config.SEED)
    os.makedirs(config.MODEL_DIR, exist_ok=True)

    # --- Load and split data ---
    X, y, feature_names = load_data(config.TRAIN_CSV)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=config.TEST_SIZE, random_state=config.SEED)

    print(f"\nTrain samples: {len(y_train)}, Test samples: {len(y_test)}")
    print(f"y range: min = {y.min():.4f}, max = {y.max():.4f}")

    # --- Standardize features ---
    # IMPORTANT: fit the scaler on the training set only, then apply it
    # (transform only) to the test set, to avoid data leakage.
    scaler_X = StandardScaler()
    X_train = scaler_X.fit_transform(X_train)
    X_test = scaler_X.transform(X_test)
    print(f"X_train (scaled) range: min = {X_train.min():.4f}, max = {X_train.max():.4f}")

    # --- Build and train model ---
    model = CarbonStockPredictor(input_dim=X_train.shape[1],
                                  dropout_rate=config.DROPOUT_RATE)
    train_log, test_log, stored_epochs = train(
        model, X_train, y_train, X_test, y_test)

    # --- Final evaluation & plots ---
    evaluate_and_plot(model, X_train, y_train, X_test, y_test,
                       train_log, test_log, stored_epochs, config.MODEL_DIR)

    # --- Save model, scaler, and feature order ---
    torch.save(model.state_dict(), os.path.join(config.MODEL_DIR, "soc_ann_model.pth"))
    with open(os.path.join(config.MODEL_DIR, "scaler_X.pkl"), "wb") as f:
        pickle.dump(scaler_X, f)
    with open(os.path.join(config.MODEL_DIR, "feature_names.txt"), "w") as f:
        f.write("\n".join(feature_names))

    print(f"\nModel, scaler, and feature order saved to: {config.MODEL_DIR}")

    # --- Summary statistics and distribution of the target variable ---
    df = pd.read_csv(config.TRAIN_CSV).dropna()
    print("\nSOC stock (kg C m^-2) summary statistics:")
    print(df['stock'].describe())

    fig, ax = plt.subplots()
    ax.hist(df['stock'], bins=50, color='skyblue', edgecolor='black')
    ax.set_title("Distribution of SOC stock (kg C m$^{-2}$)")
    ax.set_xlabel("SOC stock (kg C m$^{-2}$)")
    ax.set_ylabel("Frequency")
    ax.grid(True)
    fig.tight_layout()
    fig.savefig(os.path.join(config.MODEL_DIR, "soc_distribution.png"), dpi=300)
    plt.close(fig)


if __name__ == "__main__":
    main()