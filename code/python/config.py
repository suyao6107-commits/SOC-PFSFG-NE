"""
config.py
=========

Central configuration for the SOC (soil organic carbon) stock prediction
pipeline. All paths, feature definitions, categorical encodings, and
hyperparameters used by train_model.py and predict_uncertainty.py are
defined here, so that the two scripts always stay consistent.

IMPORTANT
---------
The order of FEATURE_NAMES, and the order of TIF_FILES / VALID_RANGES,
MUST correspond 1:1. This ordering must also match the order of the
numeric predictor columns in the training CSV (after categorical
encoding). train_model.py checks this automatically against the training
CSV and will raise an AssertionError if the orders do not match.
"""

import os

# ---------------------------------------------------------------------------
# Directory configuration
# ---------------------------------------------------------------------------
# By default, all paths are relative to this file's location, so the
# repository can be run "as is" after cloning. Modify these if your data
# live elsewhere.

CODE_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(CODE_DIR)

# Folder containing the (demo) training CSV and, optionally, raster
# predictors and a validation CSV for spatial prediction.
DATA_DIR = os.path.join(REPO_DIR, "demo_data")

# Folder where trained model weights, scaler, and diagnostic plots are
# written by train_model.py, and read by predict_uncertainty.py.
MODEL_DIR = os.path.join(REPO_DIR, "output")

# Folder containing aligned, single-band GeoTIFF predictor rasters for
# spatial prediction (one file per entry in TIF_FILES).
TIF_DIR = os.path.join(DATA_DIR, "rasters")

# Folder where spatial prediction outputs (rasters, summary tables) are
# written by predict_uncertainty.py.
OUTPUT_DIR = os.path.join(MODEL_DIR, "uncertainty_maps")

# ---------------------------------------------------------------------------
# Data files
# ---------------------------------------------------------------------------
# Training/testing dataset (point observations). Replace with the full
# dataset for a complete re-run; the demo file is a small subset for
# testing that the pipeline runs correctly.
TRAIN_CSV = os.path.join(DATA_DIR, "demo_soc_data.csv")

# Optional independent validation dataset for spatial prediction
# (columns: longitude, latitude, observed SOC stock). If this file does
# not exist, the validation step in predict_uncertainty.py is skipped.
VALIDATION_CSV = os.path.join(DATA_DIR, "soc_points.csv")

# ---------------------------------------------------------------------------
# Feature configuration
# ---------------------------------------------------------------------------
# Order of predictors used by the model. This order is fixed once a model
# is trained, and predict_uncertainty.py relies on TIF_FILES being in the
# same order.
FEATURE_NAMES = ['FT', 'ET', 'MT', 'pH', 'MBC', 'MAT', 'MAP', 'NDSI', 'NDVI']

# Categorical variable encodings used when preparing the training CSV.
# FT: frozen-ground type; ET: ecosystem type; MT: mycorrhizal type.
# Note: 'EM' = ectomycorrhizal (EcM in the manuscript), 'ER' = ericoid
# mycorrhizal (ErM in the manuscript).
FT_MAPPING = {'Permafrost': 1, 'Seasonal': 2}
ET_MAPPING = {'Wetland': 1, 'Forest': 2, 'Grassland': 3}
MT_MAPPING = {'EM': 1, 'AM': 2, 'ER': 3, 'NM': 4}

# Reverse mappings (numeric code -> label), used when reporting regional
# statistics partitioned by frozen type / ecosystem type.
FT_LABELS = {v: k for k, v in FT_MAPPING.items()}
ET_LABELS = {v: k for k, v in ET_MAPPING.items()}

# Raster files used for spatial prediction. The i-th file must correspond
# to FEATURE_NAMES[i].
TIF_FILES = [
    'permafrost_final.tif',
    'MCD12Q1_LCType1_2020_1km_Reclass_NE_aligned.tif',
    'dominant_myc_final.tif',
    'd1_ph1_final.tif',
    'MBC_NE_kg_m2_aligned.tif',
    'wc2.1_30s_bio_1_final.tif',
    'wc2.1_30s_bio_12_final.tif',
    'ndsi_10mean_20212012_final.tif',
    'tenyr_ndvi_final.tif',
]

# Physically plausible (min, max) ranges for each predictor, used to mask
# out invalid/no-data pixels before prediction. Order must match
# FEATURE_NAMES / TIF_FILES.
VALID_RANGES = [
    (1, 2),       # FT
    (1, 3),       # ET
    (1, 4),       # MT
    (3.0, 9.0),   # pH
    (0, 10),      # MBC
    (-60, 50),    # MAT
    (0, 8000),    # MAP
    (-100, 100),  # NDSI
    (-1, 1),      # NDVI
]

# ---------------------------------------------------------------------------
# Model / training hyperparameters
# ---------------------------------------------------------------------------
SEED = 42
EPOCHS = 1300
CHECK_FREQ = 100          # report train/test metrics every N epochs
LEARNING_RATE = 0.001
WEIGHT_DECAY = 1e-3
DROPOUT_RATE = 0.2
TEST_SIZE = 0.2           # fraction of data held out for testing

# ---------------------------------------------------------------------------
# Spatial prediction / uncertainty quantification
# ---------------------------------------------------------------------------
MC_ITERATIONS = 100        # number of MC Dropout + MCEP forward passes
FEATURE_NOISE_RATIO = 0.05  # relative Gaussian noise added to each
                            # standardized predictor (5%), representing
                            # input measurement uncertainty (MCEP)
CONFIDENCE_Z = 1.96         # z-score for 95% prediction intervals