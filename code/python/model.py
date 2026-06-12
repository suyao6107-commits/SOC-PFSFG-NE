"""
model.py
========

Shared ANN model architecture for SOC stock prediction.

This module defines `CarbonStockPredictor`, used both by train_model.py
(to fit the model) and predict_uncertainty.py (to load the trained
weights and generate spatial predictions). Keeping the architecture in a
single shared module guarantees that the prediction script always
instantiates a model identical in structure to the one used at training
time, avoiding "size mismatch" errors when loading saved weights.
"""

import torch.nn as nn


class CarbonStockPredictor(nn.Module):
    """
    Tapered fully-connected feedforward neural network for predicting
    soil organic carbon (SOC) stocks from environmental and biotic
    predictors.

    Architecture
    ------------
    Input (p features)
      -> Linear(p, 64)  -> BatchNorm1d(64) -> ReLU -> Dropout(rate)
      -> Linear(64, 64) -> ReLU -> Dropout(rate)
      -> Linear(64, 16) -> ReLU -> Dropout(rate)
      -> Linear(16, 8)  -> ReLU
      -> Linear(8, 1)   (output)

    Parameters
    ----------
    input_dim : int
        Number of input features (= len(config.FEATURE_NAMES)).
    dropout_rate : float, default 0.2
        Dropout probability applied after the first three hidden layers.
    """

    def __init__(self, input_dim, dropout_rate=0.2):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, 64),
            nn.BatchNorm1d(64),
            nn.ReLU(),
            nn.Dropout(dropout_rate),

            nn.Linear(64, 64),
            nn.ReLU(),
            nn.Dropout(dropout_rate),

            nn.Linear(64, 16),
            nn.ReLU(),
            nn.Dropout(dropout_rate),

            nn.Linear(16, 8),
            nn.ReLU(),

            nn.Linear(8, 1),
        )

    def forward(self, x):
        return self.net(x)

    def enable_mc_dropout(self):
        """Enable MC Dropout for uncertainty quantification.

        Switches the model to eval mode (so BatchNorm uses its fixed
        running statistics, avoiding batch-size-dependent noise), but
        then switches only the Dropout layers back to train mode so
        that they remain stochastic across repeated forward passes.
        """
        self.eval()
        for module in self.modules():
            if isinstance(module, nn.Dropout):
                module.train()

    def disable_mc_dropout(self):
        """Restore standard evaluation mode (Dropout and BatchNorm both
        in eval mode)."""
        self.eval()