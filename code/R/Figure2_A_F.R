# ============================================================================
# Path configuration (edit if your directory structure differs)
# This script assumes the working directory is set to code/R/ within the
# repository (e.g. via an RStudio Project rooted at the repository root, or
# setwd("path/to/code/R")). Input data are read from data_dir and all output
# figures/files are written to output_dir.
# ============================================================================
data_dir   <- "../../data"
output_dir <- "../../output/figures"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

library(ggplot2)
library(dplyr)
library(ggpubr)
library(ggpmisc)
library(scales) 
library(cowplot)

# -------------------- Color definitions --------------------
# Border and line colors (solid)
base_colors_et <- c("#3666AB", "#FAB701")
# Fill colors (with transparency)
legend_fill_colors <- scales::alpha(base_colors_et, 0.25)
et_abbr <- c('0-20' = '0-20cm', '20-40' = '20-40cm')

# ==================== 1. MAT ====================
dat <- read.csv(file.path(data_dir, "mat_stock.csv"), header = T)
newdat <- na.omit(dat)
newdat$layer <- factor(newdat$layer, levels = c('0-20', '20-40'))

p_MAT <- ggplot(newdat, aes(MAT, log_stock, color = layer, fill = layer)) + # [Edit 1] add fill mapping
  # [Edit 2] shape=21, stroke controls border width; alpha removed (transparency controlled via fill color)
  geom_point(shape = 21, size = 3.5, stroke = 0.8) + 
  
  geom_smooth(method = 'lm', formula = y ~ x, se = F, size = 1, aes(linetype = layer)) +
  
  scale_color_manual(values = base_colors_et, labels = et_abbr) +
  # [Edit 3] add fill scale using transparent colors
  scale_fill_manual(values = legend_fill_colors, labels = et_abbr) +
  
  scale_linetype_manual(values = c("solid", "solid"), labels = et_abbr) +
  scale_y_continuous(labels = scales::label_number(accuracy = 0.1)) +
  
  stat_poly_eq(data = newdat, 
               use_label(c("R2", "p.value.label")),
               label.x = 0.05, label.y = "bottom", size = 5.5) +
  
  ylab(expression("log-transformed SOC (kg m"^-2 * ")")) + xlab("MAT(°C)") +
  theme_classic() +
  theme(legend.title = element_blank(),
        legend.position = c(0.8, 0.8), 
        legend.text = element_text(size = 14),
        axis.text = element_text(size = 16, color = "black"),
        axis.title = element_text(size = 18, color = "black"),
        panel.border = element_rect(fill = NA, color = "black", linetype = 1, linewidth = 0.5)) +
  
  # [Edit 4] simplify guides. Since the mappings are consistent, ggplot merges the legends automatically.
  # only override.aes is needed to adjust point size/shape in the legend
  guides(color = guide_legend(override.aes = list(shape = 21, size = 5, stroke = 1)),
         fill = guide_legend(override.aes = list(shape = 21, size = 5, stroke = 1)),
         linetype = guide_legend())

p_MAT

# ==================== 2. MAP ====================
dat <- read.csv(file.path(data_dir, "map_stock.csv"), header = T)
newdat <- na.omit(dat)
newdat$layer <- factor(newdat$layer, levels = c('0-20', '20-40'))

p_MAP <- ggplot(newdat, aes(MAP, log_stock, color = layer, fill = layer)) +
  geom_point(shape = 21, size = 3.5, stroke = 0.8) + # shape 21
  geom_smooth(method = 'lm', formula = y ~ x, se = F, size = 1, aes(linetype = layer)) +
  scale_color_manual(values = base_colors_et, labels = et_abbr) +
  scale_fill_manual(values = legend_fill_colors, labels = et_abbr) + # fill scale
  scale_linetype_manual(values = c("solid", "dashed"), labels = et_abbr) +
  scale_y_continuous(labels = scales::label_number(accuracy = 0.1)) +
  stat_poly_eq(data = newdat, 
               use_label(c("R2", "p.value.label")),
               label.x = 0.95, label.y = "bottom", size = 5.5) +
  ylab(expression("log-transformed SOC (kg m"^-2 * ")")) + xlab("MAP(mm)") +
  theme_classic() +
  theme(legend.title = element_blank(),
        legend.position = "none", 
        legend.text = element_text(size = 14),
        axis.text = element_text(size = 16, color = "black"),
        axis.title = element_text(size = 18, color = "black"),
        panel.border = element_rect(fill = NA, color = "black", linetype = 1, linewidth = 0.5)) 
p_MAP

# ==================== 3. NDSI ====================
dat <- read.csv(file.path(data_dir, "ndsi_stock.csv"), header = T)
newdat <- na.omit(dat)
newdat$layer <- factor(newdat$layer, levels = c('0-20', '20-40'))

p_NDSI <- ggplot(newdat, aes(NDSI, log_stock, color = layer, fill = layer)) +
  geom_point(shape = 21, size = 3.5, stroke = 0.8) +
  geom_smooth(method = 'lm', formula = y ~ x, se = F, size = 1, aes(linetype = layer)) +
  scale_color_manual(values = base_colors_et, labels = et_abbr) +
  scale_fill_manual(values = legend_fill_colors, labels = et_abbr) +
  scale_linetype_manual(values = c("solid", "dashed"), labels = et_abbr) +
  scale_y_continuous(labels = scales::label_number(accuracy = 0.1)) +
  stat_poly_eq(data = newdat, 
               use_label(c("R2", "p.value.label")),
               label.x = 0.95, label.y = "bottom", size = 5.5) +
  ylab(expression("log-transformed SOC (kg m"^-2 * ")")) + xlab("NDSI") +
  theme_classic() +
  theme(legend.title = element_blank(),
        legend.position = "none", 
        legend.text = element_text(size = 14),
        axis.text = element_text(size = 16, color = "black"),
        axis.title = element_text(size = 18, color = "black"),
        panel.border = element_rect(fill = NA, color = "black", linetype = 1, linewidth = 0.5))
p_NDSI
# ==================== 4. pH ====================
dat <- read.csv(file.path(data_dir, "ph_stock.csv"), header = T)
newdat <- na.omit(dat)
newdat$layer <- factor(newdat$layer, levels = c('0-20', '20-40'))

p_pH <- ggplot(newdat, aes(pH, log_stock, color = layer, fill = layer)) +
  geom_point(shape = 21, size = 3.5, stroke = 0.8) +
  geom_smooth(method = 'lm', formula = y ~ x, se = F, size = 1, aes(linetype = layer)) +
  scale_color_manual(values = base_colors_et, labels = et_abbr) +
  scale_fill_manual(values = legend_fill_colors, labels = et_abbr) +
  scale_linetype_manual(values = c("solid", "solid"), labels = et_abbr) +
  scale_y_continuous(labels = scales::label_number(accuracy = 0.1)) +
  stat_poly_eq(data = newdat, 
               use_label(c("R2", "p.value.label")),
               label.x = 0.05, label.y = "bottom", size = 5.5) +
  ylab(expression("log-transformed SOC (kg m"^-2 * ")")) + xlab("Soil pH") +
  theme_classic() +
  theme(legend.title = element_blank(),
        legend.position = "none", 
        legend.text = element_text(size = 14),
        axis.text = element_text(size = 16, color = "black"),
        axis.title = element_text(size = 18, color = "black"),
        panel.border = element_rect(fill = NA, color = "black", linetype = 1, linewidth = 0.5))
p_pH
# ==================== 5. MBC ====================
dat <- read.csv(file.path(data_dir, "mbc_stock_0512.csv"), header = T)
newdat <- na.omit(dat)
newdat$layer <- factor(newdat$layer, levels = c('0-20', '20-40'))

p_MBC <- ggplot(newdat, aes(log_MBC, log_stock, color = layer, fill = layer)) +
  geom_point(shape = 21, size = 3.5, stroke = 0.8) +
  geom_smooth(method = 'lm', formula = y ~ x, se = F, size = 1, aes(linetype = layer)) +
  scale_color_manual(values = base_colors_et, labels = et_abbr) +
  scale_fill_manual(values = legend_fill_colors, labels = et_abbr) +
  scale_linetype_manual(values = c("solid", "solid"), labels = et_abbr) +
  scale_y_continuous(labels = scales::label_number(accuracy = 0.1)) +
  stat_poly_eq(data = newdat, 
               use_label(c("R2", "p.value.label")),
               label.x = 0.95, label.y = "bottom", size = 5.5) +
  ylab(expression("log-transformed SOC (kg m"^-2 * ")")) + xlab(expression("log-transformed MBC (kg m"^-2 * ")")) +
  theme_classic() +
  theme(legend.title = element_blank(),
        legend.position = "none", 
        legend.text = element_text(size = 14),
        axis.text = element_text(size = 16, color = "black"),
        axis.title = element_text(size = 18, color = "black"),
        panel.border = element_rect(fill = NA, color = "black", linetype = 1, linewidth = 0.5))
p_MBC
# ==================== 6. NDVI ====================
dat <- read.csv(file.path(data_dir, "ndvi_stock.csv"), header = T)
newdat <- na.omit(dat)
newdat$layer <- factor(newdat$layer, levels = c('0-20', '20-40'))

p_NDVI <- ggplot(newdat, aes(NDVI, log_stock, color = layer, fill = layer)) +
  geom_point(shape = 21, size = 3.5, stroke = 0.8) +
  geom_smooth(method = 'lm', formula = y ~ x, se = F, size = 1, aes(linetype = layer)) +
  scale_color_manual(values = base_colors_et, labels = et_abbr) +
  scale_fill_manual(values = legend_fill_colors, labels = et_abbr) +
  scale_linetype_manual(values = c("solid", "dashed"), labels = et_abbr) +
  scale_y_continuous(labels = scales::label_number(accuracy = 0.1)) +
  stat_poly_eq(data = newdat, 
               use_label(c("R2", "p.value.label")),
               label.x = 0.95, label.y = "bottom", size = 5.5) +
  ylab(expression("log-transformed SOC (kg m"^-2 * ")")) + xlab("NDVI") +
  theme_classic() +
  theme(legend.title = element_blank(),
        legend.position = "none", 
        legend.text = element_text(size = 14),
        axis.text = element_text(size = 16, color = "black"),
        axis.title = element_text(size = 18, color = "black"),
        panel.border = element_rect(fill = NA, color = "black", linetype = 1, linewidth = 0.5))
p_NDVI
# ==================== Combine and save ====================
p_all <- cowplot::plot_grid(
  p_MAT, p_MAP, p_NDSI,
  p_pH, p_MBC, p_NDVI,
  ncol = 3,
  align = "h",
  axis = "tb")

print(p_all) 
ggsave(file.path(output_dir, "soc_layer_6_factors_0512.png"), p_all, width = 15, height = 10, dpi = 600)