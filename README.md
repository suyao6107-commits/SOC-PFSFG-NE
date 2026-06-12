# SOC-PFSFG-NE
Code and data for "Contrasting responses of soil carbon storage and climate vulnerability to ecosystem and frozen-ground transitions"

> **Contrasting responses of soil carbon storage and climate vulnerability to ecosystem and frozen-ground transitions**
> Yao Su, Junsheng Huang, Xingming Zhang, Pengfei Chang, Yuanhe Yang, Lingli Liu, Meifeng Deng*
> Key Laboratory of Vegetation and Environmental Change, Institute of Botany, Chinese Academy of Sciences

This repository contains two components:

1. **R scripts** (`code/R/`) reproducing the statistical analyses and figures (boxplots, regressions, linear mixed-effects models, random forest variable importance, climatological Q10 / threshold analyses) presented in the manuscript and Supplementary Information.
2. **Python scripts** (`code/python/`) implementing the artificial neural network (ANN) used for spatial SOC stock prediction and uncertainty quantification (Figure 4).

---

## 1. Repository structure

```
SOC-PFSFG-NortheastChina/
├── README.md
├── LICENSE
├── .gitignore
├── code/
│   ├── python/
│   │   ├── config.py
│   │   ├── model.py
│   │   ├── train_model.py
│   │   ├── predict_uncertainty.py
│   │   └── requirements.txt
│   └── R/
│       ├── Figure1_A.R              # Fig. 1A - site map
│       ├── Figure1_B_H.R            # Fig. 1B-H - SOC boxplots/barplots by FT/ET/MT and depth
│       ├── Figure2_A_F.R            # Fig. 2A-F - SOC vs. environmental predictors (regressions)
│       ├── Figure2_G_H_Figure_S2.R  # Fig. 2G-H, Fig. S2 - random forest variable importance
│       ├── Figure3_A_D_Figure_S4.R  # Fig. 3A-D, Fig. S4 - climatological Q10 / sensitivity analysis
│       ├── FigureS1.R               # Fig. S1 - FT x ET x MT interaction plots (LMM + emmeans)
│       ├── FigureS3.R               # Fig. S3 - frozen-stage transition threshold (MTC)
│       └── lmer.R                   # Tables S1-S3 - linear mixed-effects models
├── demo_data/                        # Demo data for the Python ANN pipeline
│   ├── demo_soc_data.csv
│   ├── soc_points.csv               (optional)
│   └── rasters/                      (optional)
│       └── ... 9 predictor GeoTIFFs
├── data/                              # Input data for the R analysis scripts (see Section 5)
│   ├── china_provinces.json
│   └── ... CSV files listed in Section 5
└── output/                            # Created automatically by the running scripts

---

## 2. System requirements

### Python (ANN pipeline)

- Python 3.10
- PyTorch 2.6.0+cpu
- pandas, numpy, scikit-learn, matplotlib
- rasterio, tqdm (required only for `predict_uncertainty.py`)

Exact versions are pinned in `code/python/requirements.txt`. Tested on Windows 10/11.

### R (statistical analyses and figures)

- R (please record the R version used for the reported analyses here, e.g. via `R.version.string`)
- Required packages:

| Package(s) | Used in |
|---|---|
| ggplot2, dplyr, tidyverse, scales, cowplot | all figure scripts |
| sf, rnaturalearth, rnaturalearthdata | Figure1_A.R (site map) |
| agricolae (LSD.test) | Figure1_B_H.R |
| ggpubr, ggpmisc (stat_poly_eq) | Figure2_A_F.R, Figure3_A_D_Figure_S4.R, FigureS3.R |
| rfPermute, randomForest, RColorBrewer, usdm (vifcor) | Figure2_G_H_Figure_S2.R |
| lme4, lmerTest, emmeans, multcomp | FigureS1.R, lmer.R |
| Matrix, effects, moments, sjstats | lmer.R |

**Hardware**: no non-standard hardware required; all analyses run on a standard desktop CPU.

---

## 3. Installation guide

### Python

```bash
cd code/python
pip install -r requirements.txt
```

Typical install time: ~5-10 minutes. If `rasterio` fails to install via pip on Windows, use:

```bash
conda install -c conda-forge rasterio
```

### R

Install required packages (run once):

```r
install.packages(c(
  "ggplot2", "dplyr", "tidyverse", "scales", "cowplot",
  "sf", "rnaturalearth", "rnaturalearthdata",
  "agricolae", "ggpubr", "ggpmisc",
  "rfPermute", "randomForest", "RColorBrewer", "usdm",
  "lme4", "lmerTest", "emmeans", "multcomp",
  "Matrix", "effects", "moments", "sjstats"
))
```

> **Note**: the original `lmer.R` script contains `install.packages(...)` calls at the top and a reference to a package `learnasreml`, which does not exist on CRAN and appears to be left over from script development. Before running `lmer.R`, remove or comment out the `install.packages(...)` lines and the line `library(learnasreml)`. All functions used in this script (`lmer`, `anova`, `ranova`, `shapiro.test`, `ggqqplot`, etc.) are provided by `lmerTest`, base R `stats`, and `ggpubr`, which are already loaded elsewhere in the script.

---

## 4. Demo — Python ANN pipeline

### 4.1 Model training (`train_model.py`)

```bash
cd code/python
python train_model.py
```

Trains `CarbonStockPredictor` on `demo_data/demo_soc_data.csv` (n = 180; 80/20 train/test split, fixed seed). Console output reports the detected feature order, train/test sample sizes, and MSE/RMSE/MAE/R^2 at each 100-epoch checkpoint (1300 epochs total) plus a final summary. Outputs (`soc_ann_model.pth`, `scaler_X.pkl`, `feature_names.txt`, three diagnostic PNGs) are written to `../../output/`.

Expected run time: ~1-3 minutes on a standard CPU.

### 4.2 Spatial prediction with uncertainty (`predict_uncertainty.py`)

```bash
cd code/python
python predict_uncertainty.py
```

Requires `train_model.py` to have been run first, and the 9 predictor rasters (`config.TIF_FILES`) to be present in `demo_data/rasters/`. Outputs raster layers (mean/SD/95% PI/percent uncertainty), `soc_stock_stats.csv`, and (if `demo_data/soc_points.csv` is present) validation diagnostics to `output/uncertainty_maps/`.

Expected run time: a few minutes on a standard CPU, depending on raster extent.

---

## 5. R analysis scripts: required inputs and outputs

All R scripts use relative paths and expect input CSV files (and, for Figure1_A.R, a GeoJSON file of China's province boundaries) to be located in the working directory. Set this to the data/ folder (e.g. via setwd("path/to/data") or by opening an RStudio project rooted there). The CSV files listed below are pre-processed subsets/views of the full compiled SOC dataset (n ~ 1,121), each filtered/reshaped for a specific figure or analysis.

| Script | Figure(s) | Required input file(s) | Output file(s) |
|---|---|---|---|
| Figure1_A.R | Fig. 1A | china_provinces.json, dca.csv | map_0427.png |
| Figure1_B_H.R | Fig. 1B-H | stock60_type.csv, stock60_ecosystem.csv, stock60_mycorrhiza.csv, stock_layer.csv, stock_type.csv, stock_ecosystem.csv, stock_mycorrhiza.csv | soc60_FT_ET_MT.png, soc_layer.png, soc_layer_FT_ET_MT_1.png, Fig_1_combined.png |
| Figure2_A_F.R | Fig. 2A-F | mat_stock.csv, map_stock.csv, ndsi_stock.csv, ph_stock.csv, mbc_stock_0512.csv, ndvi_stock.csv | soc_layer_6_factors_0512.png |
| Figure2_G_H_Figure_S2.R | Fig. 2G-H, Fig. S2 | all_20_0512.csv, all_40_0512.csv, IncMSE_20.csv, IncMSE_40.csv | relative_importance_all_factors_0512.png, relative_importance_bubble.png |
| Figure3_A_D_Figure_S4.R | Fig. 3A-D, Fig. S4 | mat_stock.csv (same file as Figure2_A_F.R) | 0_20_soc_MAT_sensitivity_*.png, 20_40_soc_MAT_sensitivity_0428.png |
| FigureS1.R | Fig. S1 | 0-20.csv, 20-40.csv | Interaction_Bars_MixedModel_20_0428.png, Interaction_Bars_MixedModel_40_0428.png |
| FigureS3.R | Fig. S3 | mtc_stock_upland.csv | final_plot (combined plot object; no ggsave() call in the current script - add one if a saved file is required) |
| lmer.R | Tables S1-S3 | 0-20_0402.csv, 20-40_0402.csv, 0-20-all.csv | stock60.csv (intermediate, written during normality checks) |

### Consolidated list of data files to place in `data/`

```
china_provinces.json
dca.csv
stock60_type.csv
stock60_ecosystem.csv
stock60_mycorrhiza.csv
stock_layer.csv
stock_type.csv
stock_ecosystem.csv
stock_mycorrhiza.csv
mat_stock.csv
map_stock.csv
ndsi_stock.csv
ph_stock.csv
mbc_stock_0512.csv
ndvi_stock.csv
all_20_0512.csv
all_40_0512.csv
IncMSE_20.csv
IncMSE_40.csv
0-20.csv
20-40.csv
mtc_stock_upland.csv
0-20_0402.csv
20-40_0402.csv
0-20-all.csv
```

Each file's columns should match the variables referenced in the corresponding script (e.g. `log_stock`, `Type`, `Ecosystem`, `Mycorrhiza`, `Species`, `layer`, `MAT`, `MAP`, `NDSI`, `NDVI`, `pH`, `MBC`, `MTC`, etc.).

---

## 6. Before running: known issues to address

- **lmer.R**: remove the `install.packages(...)` calls (lines 1-7) and the line `library(learnasreml)` (package does not exist on CRAN; appears to be unused/leftover from development).
- **FigureS3.R**: the script builds `final_plot` via `cowplot::plot_grid(p1, p2, ncol = 1)` but does not call `ggsave()`. Add a `ggsave(...)` call if a saved output file is required for the demo.

---

## 7. License

This project is released under the MIT License (see `LICENSE`).

---

## 8. Code availability after publication

This repository will remain publicly accessible at this URL following publication. A permanent, version-specific archive with a DOI is also available via [Zenodo / Figshare - insert DOI here once created].

---

## 9. Contact

For questions regarding the code, please contact the corresponding author:
Meifeng Deng - dengmeifeng@ibcas.ac.cn
Institute of Botany, Chinese Academy of Sciences, Beijing 100093, China
