# Model Card for CarbonStockPredictor (SOC-PFSFG-NortheastChina)

A fully-connected artificial neural network (ANN) that predicts soil organic carbon (SOC) stocks (0-20 cm, kg C m^-2) from environmental and biotic predictors, used for regional spatial mapping across the permafrost-seasonally frozen ground (PF-SFG) transition zone of Northeast China.

## Model Details

### Model Description

CarbonStockPredictor is a tapered, fully-connected feedforward neural network (regression model) that maps nine environmental and biotic predictors to a single continuous output: SOC stock in the top 20 cm of soil (kg C m^-2). It was developed to support regional-scale spatial prediction of SOC stocks and to quantify the associated predictive uncertainty across heterogeneous frozen-ground and ecosystem types in Northeast China.

- **Developed by:** Yao Su, Junsheng Huang, Xingming Zhang, Pengfei Chang, Yuanhe Yang, Lingli Liu, Meifeng Deng (Institute of Botany, Chinese Academy of Sciences)
- **Funded by:** [insert grant/funding source(s), as listed in the manuscript Acknowledgements]
- **Shared by:** Meifeng Deng (corresponding author)
- **Model type:** Fully-connected feedforward neural network (tabular regression), implemented in PyTorch
- **License:** MIT
- **Finetuned from model:** N/A (trained from scratch)

### Model Sources

- **Repository:** [https://github.com/suyao6107-commits/SOC-PFSFG-NE]
- **Paper:** "Contrasting responses of soil carbon storage and climate vulnerability to ecosystem and frozen-ground transitions" (manuscript under review)

## Uses

### Direct Use

The model takes nine predictors (frozen-ground type, ecosystem type, dominant mycorrhizal type, soil pH, microbial biomass carbon, mean annual temperature, mean annual precipitation, normalized difference snow index, and normalized difference vegetation index) and outputs a predicted SOC stock (0-20 cm, kg C m^-2) for a given location. Combined with the spatial prediction pipeline (`predict_uncertainty.py`), it is used to generate gridded SOC stock maps with associated 95% prediction intervals across the Northeast China PF-SFG transition zone.

### Downstream Use

The predicted SOC stock maps and their uncertainty layers can be used as inputs for regional carbon budget assessments, or as a baseline against which future SOC monitoring data can be compared.

### Out-of-Scope Use

- The model is not intended for application outside the geographic domain and environmental gradients (frozen-ground type, ecosystem type, climate, soil, and vegetation ranges) represented in the training dataset (n = 1,121 field observations from Northeast China). Predictions for locations with predictor values well outside these ranges should be treated with caution.
- The model predicts SOC stock for the 0-20 cm depth interval only and should not be used to infer stocks at other depths.
- The model is a research tool and is not intended for regulatory, land-use policy, or carbon-credit certification decisions without independent field validation.
- Categorical predictors (frozen-ground type, ecosystem type, mycorrhizal type) are encoded using fixed category sets (see `config.py`); the model cannot meaningfully handle categories not present in the training data.

## Bias, Risks, and Limitations

- **Spatial autocorrelation:** Train/test splitting was performed via simple random sampling rather than spatial blocking. Because nearby sampling sites can be spatially autocorrelated, the reported test-set performance (R^2 ~ 0.80) may be a somewhat optimistic estimate of accuracy in entirely unsampled areas.
- **Sample size:** The training dataset (n = 1,121 in the full study; n = 180 in the demo subset distributed with this repository) is modest relative to the environmental heterogeneity of the study region. No separate validation set was held out; hyperparameters were tuned manually based on training/test loss curves.
- **Categorical encodings:** Frozen-ground type, ecosystem type, and mycorrhizal type are encoded as fixed integer categories (see `config.py`). Applying the model to data with different or additional categories requires updating these mappings and retraining.
- **Uncertainty quantification assumptions:** The reported 95% prediction intervals combine MC Dropout (epistemic uncertainty) and Monte Carlo Error Propagation with a fixed 5% relative noise assumption on each standardized predictor (aleatoric uncertainty). These intervals do not capture uncertainty arising from spatial extrapolation beyond the training data's environmental range.

### Recommendations

Users should consult the accompanying 95% prediction interval and percent-uncertainty layers (output by `predict_uncertainty.py`) alongside the mean SOC stock predictions, rather than relying on point predictions alone. Users applying this model to regions or conditions substantially different from Northeast China's PF-SFG transition zone are encouraged to retrain or recalibrate the model using locally representative data.

## How to Get Started with the Model

```python
import pickle
import torch
from model import CarbonStockPredictor
import config

# Load trained model and scaler
with open("output/scaler_X.pkl", "rb") as f:
    scaler = pickle.load(f)

model = CarbonStockPredictor(len(config.FEATURE_NAMES), dropout_rate=config.DROPOUT_RATE)
model.load_state_dict(torch.load("output/soc_ann_model.pth", map_location="cpu"))
model.eval()

# X_new: array of shape (n_samples, 9), columns ordered as config.FEATURE_NAMES
X_scaled = scaler.transform(X_new)
with torch.no_grad():
    pred = model(torch.tensor(X_scaled, dtype=torch.float32)).numpy().flatten()
```

See `train_model.py` for training from scratch and `predict_uncertainty.py` for spatial prediction with uncertainty quantification.

## Training Details

### Training Data

The training dataset comprises 1,121 field-based SOC observations (0-20 cm) compiled from 125 published studies and the China Soil Science Database, spanning the permafrost-seasonally frozen ground transition zone of Northeast China. Each observation includes nine predictors:

| Feature | Description | Type / encoding |
|---|---|---|
| FT | Frozen-ground type | Categorical: Permafrost = 1, Seasonal = 2 |
| ET | Ecosystem type | Categorical: Wetland = 1, Forest = 2, Grassland = 3 |
| MT | Dominant mycorrhizal type | Categorical: EM (EcM) = 1, AM = 2, ER (ErM) = 3, NM = 4 |
| pH | Soil pH | Numeric |
| MBC | Microbial biomass carbon (kg C m^-2) | Numeric |
| MAT | Mean annual temperature (degrees C) | Numeric |
| MAP | Mean annual precipitation (mm) | Numeric |
| NDSI | Normalized Difference Snow Index | Numeric |
| NDVI | Normalized Difference Vegetation Index | Numeric |

A demo subset (n = 180, `demo_data/demo_soc_data.csv`) covering all categorical levels is distributed with this repository for testing the pipeline.

### Training Procedure

#### Preprocessing

Categorical predictors (FT, ET, MT) are mapped to integer codes using fixed dictionaries (`config.FT_MAPPING`, `config.ET_MAPPING`, `config.MT_MAPPING`). All nine predictors are then standardized (zero mean, unit variance) using `sklearn.preprocessing.StandardScaler`, fit on the training split only and applied (transform-only) to the test split, to avoid data leakage.

#### Training Hyperparameters

- **Architecture:** Input(9) -> Linear(9,64) -> BatchNorm1d -> ReLU -> Dropout(0.2) -> Linear(64,64) -> ReLU -> Dropout(0.2) -> Linear(64,16) -> ReLU -> Dropout(0.2) -> Linear(16,8) -> ReLU -> Linear(8,1)
- **Loss:** Mean squared error (MSE)
- **Optimizer:** Adam, learning rate = 0.001, weight decay = 1e-3
- **Gradient clipping:** max norm = 1.0
- **Epochs:** 1,300 (full-batch training)
- **Train/test split:** 80% / 20%, random split, seed = 42
- **Training regime:** full-precision (fp32) CPU training

#### Speeds, Sizes, Times

The model has approximately 6,000 trainable parameters. A full training run (1,300 epochs, n = 1,121) completes in approximately 1-3 minutes on a standard desktop CPU (see `COMPUTE_RESOURCES.md` for measured timings).

## Evaluation

### Testing Data, Factors & Metrics

#### Testing Data

A random 20% holdout split of the full dataset (n ~ 224 observations in the full study; n = 36 in the demo subset), held out from training and from hyperparameter selection.

#### Metrics

Mean squared error (MSE), root mean squared error (RMSE), mean absolute error (MAE), and the coefficient of determination (R^2), computed on both the training and test sets.

### Results

On the full dataset (n = 1,121), the model achieved approximately R^2 = 0.86 on the training set and R^2 = 0.80 on the held-out test set (see Table S5 in the manuscript Supplementary Information for full RMSE/MAE values).

#### Summary

The model explains a substantial proportion of variance in observed SOC stocks across the study region, with no indication of overfitting (training and test loss curves converge over the 1,300 training epochs).

## Model Examination

Formal post-hoc interpretability methods (e.g., SHAP) were not applied directly to this ANN. As a complementary, model-agnostic check, an independent Random Forest permutation-importance analysis (`code/R/Figure2_G_H_Figure_S2.R`) was used to rank the relative importance of the same nine predictors for SOC stock variation; the resulting ranking is consistent with the spatial patterns produced by this ANN.

## Environmental Impact

- **Hardware Type:** standard desktop CPU (no GPU)
- **Hours used:** less than 1 hour (training + spatial prediction combined)
- **Cloud Provider:** none (run locally)
- **Compute Region:** N/A
- **Carbon Emitted:** negligible, given the short runtime and absence of GPU/cloud compute; see `COMPUTE_RESOURCES.md`

## Technical Specifications

### Model Architecture and Objective

CarbonStockPredictor is a tapered fully-connected feedforward network (9-64-64-16-8-1) trained to minimize mean squared error between predicted and observed SOC stocks (regression). See `model.py` for the full implementation.

### Compute Infrastructure

See `COMPUTE_RESOURCES.md` for hardware specifications and measured runtimes.

#### Hardware

Standard desktop workstation; no GPU required. See `COMPUTE_RESOURCES.md`.

#### Software

- Python 3.10
- PyTorch 2.6.0 (CPU build)
- numpy, pandas, scikit-learn, matplotlib
- rasterio, tqdm (spatial prediction only)

Exact versions are pinned in `requirements.txt`.

## Citation

**APA:**

Su, Y., Huang, J., Zhang, X., Chang, P., Yang, Y., Liu, L., & Deng, M. (in review). Responses of soil carbon storage and climate vulnerability to ecosystem and frozen-ground transitions.

## More Information

See `README.md` for full repository structure, installation instructions, and reproduction details.

## Model Card Authors

Yao Su, Meifeng Deng

## Model Card Contact

Meifeng Deng - dengmeifeng@ibcas.ac.cn
Institute of Botany, Chinese Academy of Sciences, Beijing 100093, China