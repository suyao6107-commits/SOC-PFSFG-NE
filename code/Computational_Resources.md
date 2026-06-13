# Computational Resources

This document records the hardware, software, and measured runtimes used to train and run the models in this repository, in support of the "Computational resources" section of the Nature Portfolio Machine Learning Checklist.

## Hardware

| Item | Value |
|---|---|
| CPU | Intel(R) Core(TM) Ultra 5 125H |
| RAM | 32 GB |
| GPU | None used (training and prediction run on CPU only; PyTorch CPU build) |
| Operating system | Windows 11 Home, 64-bit |

## Software

| Package | Version |
|---|---|
| Python | 3.10 |
| PyTorch | 2.6.0+cpu |
| numpy | 1.26.4 |
| pandas | 2.2.3 |
| scikit-learn | 1.6.1 |
| matplotlib | 3.9.1 |
| rasterio | 1.3.6 |
| tqdm | 4.67.1 |

(Exact versions are also pinned in `requirements.txt`.)

## Measured Runtimes

| Script | Dataset | Measured wall-clock time |
|---|---|---|
| `train_model.py` | demo dataset (n = 180) | 17 s |
| `predict_uncertainty.py` | full Northeast China raster stack (1-km resolution, 100 MC + MCEP iterations) | 2 min 8 s |

## Estimated Computational Cost / Environmental Impact

A complete run of the pipeline (model training plus spatial prediction with uncertainty quantification across the full Northeast China study domain) completes in approximately 2.5 minutes on a standard laptop CPU, with no GPU or cloud compute involved. Given this short runtime and the absence of GPU/cloud resources, the associated energy consumption and carbon footprint are negligible. No parallelization or distributed training was used.