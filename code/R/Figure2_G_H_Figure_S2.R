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

# Relative importance analysis (lollipop plot)
library(ggplot2)
library(rfPermute)
library(RColorBrewer)
library(randomForest)
library(cowplot)
options(max.print=1000000) 

# ====================== 1. RF relative importance - lollipop plot - all factors ============================
# --------------------------0_20cm (p1)------------------------------------
# Assuming data are read correctly; original logic preserved here
dat <- read.csv(file.path(data_dir, "all_20_0512.csv"), header = T) 
data <- na.omit(dat)

library(usdm)
# 1. Extract all predictor variables
predictors <- data[, c("MAT", "MAP", "NDSI", "NDVI", "pH", "MBC")]
# 2. Convert categorical variables to numeric/factor for collinearity check (assumes FT, ET, MT already handled)
# 3. Run VIF check, automatically flagging highly collinear variables
vif_results <- vifcor(predictors, th = 0.8) # threshold can be set to a correlation of 0.8
print(vif_results)

set.seed(2023)
fit_rf <- rfPermute(
  formula = log_stock ~ FT + ET + MT + NDVI + pH + MBC + MAT + MAP + NDSI,
  data = data,
  ntree = 2000, # number of trees
  mtry = 2, # number of candidate variables at each split
  importance = T # compute variable importance during tree building
)

importance(fit_rf)
importance1 <- data.frame(importance(fit_rf))
importance1$variable <- row.names(importance1)
# Note: ensure the variable order here matches the manually assigned sig and factor below
importance1$sig <- c(1,2,3,4,5,6,7,8,9) 
importance1$rel_importance <- importance1$X.IncMSE / sum(importance1$X.IncMSE)*100
importance1$factor <- c("Climate","Soil","Climate","Plant","Climate","Soil","Plant","ET","FT")

for (variable in rownames(importance1)) {      
  if (importance1[variable,"X.IncMSE.pval"] <= 0.001) importance1[variable,"sig"] <- "***"
  else if(importance1[variable,"X.IncMSE.pval"] > 0.001 & importance1[variable,"X.IncMSE.pval"] <= 0.01) importance1[variable,"sig"] <- "**"
  else if(importance1[variable,"X.IncMSE.pval"] > 0.01 & importance1[variable,"X.IncMSE.pval"] <= 0.05) importance1[variable,"sig"] <- "*"
  else importance1[variable,"sig"] <- ""
}

importance1$factor <- factor(importance1$factor, ordered=TRUE, levels=c("Climate","Soil","Plant","ET","FT"))
r_sq_value <- fit_rf$rf$rsq[2000] # the index in [] corresponds to ntree (number of trees)

# --- Plotting section: P1 ---
p1 <- ggplot(importance1, aes(x = rel_importance, y = reorder(variable, rel_importance), color = factor)) +
  # 1. Lollipop stick: forced to black (color="black")
  geom_segment(aes(xend = 0, yend = reorder(variable, rel_importance)), size = 1.5, color = "gray50") + 
  # 2. Lollipop head: shape=21 (fillable circle), fill="white", stroke=2 (thicker border for visibility)
  geom_point(size = 6, shape = 21, fill = "white", stroke = 2) +  
  annotate('text', label = '0-20cm', x = 14, y = 1.5, size = 6) +
  annotate('text', label = sprintf('italic(R^2) == %.2f', r_sq_value), x = 14, y = 1, size = 6, parse = TRUE) +
  scale_color_manual(values = c("#3666AB","#FAB701","#12A579","#d95f02","#7570b3")) +
  theme_classic() +
  theme(legend.title = element_blank()) +
  theme(legend.position = "none", legend.text = element_text(size = 14)) +
  theme(axis.text = element_text(size = 20, color = "black")) +
  theme(axis.title = element_text(size = 20, color = "black")) +
  geom_text(aes(x = rel_importance + 1.5, label = sig), size = 8, color = "black") + # significance asterisks kept black to avoid inheriting color
  xlab("%IncMSE") + ylab(NULL)

p1

# --------------------------20_40cm (p2)------------------------------------
# Re-read/process data (original logic preserved)
dat <- read.csv(file.path(data_dir, "all_40_0512.csv"), header = T)
data <- na.omit(dat)

set.seed(2023)
fit_rf <- rfPermute(
  formula = log_stock ~ FT + ET + MT + NDVI + pH + MBC + MAT + MAP + NDSI,
  data = data,
  ntree = 2000,
  mtry = 2,
  importance = T
)

importance(fit_rf)
importance1 <- data.frame(importance(fit_rf))
importance1$variable <- row.names(importance1)
# Note: ensure the variable order here matches the manually assigned sig and factor below
importance1$sig <- c(1,2,3,4,5,6,7,8,9) 
importance1$rel_importance <- importance1$X.IncMSE / sum(importance1$X.IncMSE)*100
importance1$factor <- c("Climate","Climate","Climate","Soil","Plant","ET","Soil","Plant","FT")

for (variable in rownames(importance1)) {      
  if (importance1[variable,"X.IncMSE.pval"] <= 0.001) importance1[variable,"sig"] <- "***"
  else if(importance1[variable,"X.IncMSE.pval"] > 0.001 & importance1[variable,"X.IncMSE.pval"] <= 0.01) importance1[variable,"sig"] <- "**"
  else if(importance1[variable,"X.IncMSE.pval"] > 0.01 & importance1[variable,"X.IncMSE.pval"] <= 0.05) importance1[variable,"sig"] <- "*"
  else importance1[variable,"sig"] <- ""
}

importance1$factor <- factor(importance1$factor, ordered=TRUE, levels=c("Climate","Soil","Plant","ET","FT"))
r_sq_value <- fit_rf$rf$rsq[2000] # the index in [] corresponds to ntree (number of trees)

# --- Plotting section: P1 ---
p2 <- ggplot(importance1, aes(x = rel_importance, y = reorder(variable, rel_importance), color = factor)) +
  # 1. Lollipop stick: forced to black (color="black")
  geom_segment(aes(xend = 0, yend = reorder(variable, rel_importance)), size = 1.5, color = "gray50") + 
  # 2. Lollipop head: shape=21 (fillable circle), fill="white", stroke=2 (thicker border for visibility)
  geom_point(size = 6, shape = 21, fill = "white", stroke = 2) +  
  annotate('text', label = '20-40cm', x = 14, y = 1.5, size = 6) +
  annotate('text', label = sprintf('italic(R^2) == %.2f', r_sq_value), x = 14, y = 1, size = 6, parse = TRUE) +
  scale_color_manual(values = c("#3666AB","#FAB701","#12A579","#d95f02","#7570b3")) +
  theme_classic() +
  theme(legend.title = element_blank()) +
  theme(legend.position = c(0.9, 0.3), legend.text = element_text(size = 14)) +
  theme(axis.text = element_text(size = 20, color = "black")) +
  theme(axis.title = element_text(size = 20, color = "black")) +
  geom_text(aes(x = rel_importance + 1.5, label = sig), size = 8, color = "black") + # significance asterisks kept black to avoid inheriting color
  xlab("%IncMSE") + ylab(NULL)

p2

# -------------------------- Combine and save ------------------------------------
p_all <- cowplot::plot_grid(
  p1, p2,
  ncol = 1,
  align = "h",
  axis = "tb")

print(p_all)
ggsave(file.path(output_dir, "relative_importance_all_factors_0512.png"), p_all, width = 6.5, height = 13, dpi = 600)

# ====================== 2. RF relative importance - bubble plot ============================
# ----------------------0-20cm---------------------------------------
# Bubble plot and stacked bar chart visualization
c("#78B7C7","#c399a2","#749e89","#D6D6D6","#DAA87C","#9CB0C3")
library(ggplot2)
library(dplyr)
library(scales)
library(cowplot)
# Color palette
border_colors <- c("Climate" = "#87C0CD", "Plant" = "#B0C88C", "Soil" = "#E9C992")
fill_colors   <- c("Climate" = "#87C0CD", "Plant" = "#B0C88C", "Soil" = "#E9C992")

# ==================== 0-20 cm plot (p1) ====================
df <- read.csv(file.path(data_dir, "IncMSE_20.csv")) 
df$Factor <- factor(df$Factor, levels = c('MAT','MAP','NDSI','NDVI','MT', 'MBC','pH'))
df$Group <- factor(df$Group, levels = c('All', 'Permafrost','Seasonal','Wetland','Forest','Grassland'))
df$Factor1 <- factor(df$Factor1, levels = c('Climate','Plant','Soil'))
df_R2_1 <- df %>% select(Group, R2) %>% distinct()

p1 <- ggplot(df, aes(Group, Factor)) +
  geom_point(aes(size = IncMSE, color = Factor1, fill = Factor1), 
             shape = 16, stroke = 1.1, alpha = 1) + 
  geom_text(aes(label = sprintf("%.2f", IncMSE)), 
            color = "black", hjust = 0.5, vjust = 0.5, size = 4, na.rm = FALSE) +
  geom_text(data = df_R2_1, 
            aes(x = Group, y = 0.4, label = sprintf("%.2f", R2)),
            inherit.aes = FALSE, angle = 45, hjust = 1, size = 5, color = "black") +
  ylab("") + xlab("") +
  scale_color_manual(values = border_colors) +
  scale_fill_manual(values = fill_colors) +
  scale_size_continuous(range = c(3, 28)) + # note: this range is large
  scale_x_discrete(position = "top") + 
  scale_y_discrete(limits = rev(levels(df$Factor))) + 
  theme_bw() +
  guides(color = "none", fill = "none", size = "none") + # keep the main plot legend-free
  theme(
    legend.position = "none",
    axis.text = element_text(size = 18, color = "black"),
    axis.title = element_text(size = 16, color = "black"),
    axis.text.x = element_text(angle = 60, hjust = 0),
    plot.margin = ggplot2::margin(t = 10, r = 10, b = 40, l = 10, unit = "pt")
  ) +
  coord_cartesian(clip = "off")
p1

# ==================== 20-40 cm plot (p2) ====================
df <- read.csv(file.path(data_dir, "IncMSE_40.csv"))
df$Factor <- factor(df$Factor, levels = c('MAT','MAP','NDSI','NDVI','MT', 'MBC','pH'))
df$Group <- factor(df$Group, levels = c('All', 'Permafrost','Seasonal','Wetland','Forest','Grassland'))
df$Factor1 <- factor(df$Factor1, levels = c('Climate','Plant','Soil'))
df_R2_2 <- df %>% select(Group, R2) %>% distinct()

p2 <- ggplot(df, aes(Group, Factor)) +
  geom_point(aes(size = IncMSE, color = Factor1, fill = Factor1), 
             shape = 16, stroke = 1.1, alpha = 1) + 
  geom_text(aes(label = sprintf("%.2f", IncMSE)), 
            color = "black", hjust = 0.5, vjust = 0.5, size = 4, na.rm = FALSE) +
  geom_text(data = df_R2_2, 
            aes(x = Group, y = 0.4, label = sprintf("%.2f", R2)),
            inherit.aes = FALSE, angle = 45, hjust = 1, size = 5, color = "black") +
  ylab("") + xlab("") +
  scale_color_manual(values = border_colors) +
  scale_fill_manual(values = fill_colors) +
  scale_size_continuous(range = c(3, 28)) +
  scale_x_discrete(position = "top") + 
  scale_y_discrete(limits = rev(levels(df$Factor))) + 
  theme_bw() +
  guides(color = "none", fill = "none", size = "none") + # keep the main plot legend-free
  theme(
    legend.position = "none",
    axis.text = element_text(size = 18, color = "black"),
    axis.title = element_text(size = 16, color = "black"),
    axis.text.x = element_text(angle = 60, hjust = 0),
    plot.margin = ggplot2::margin(t = 10, r = 10, b = 40, l = 10, unit = "pt")
  ) +
  coord_cartesian(clip = "off")
p2

# ==================== Key step: extract the size legend ====================
# 1. Create a dedicated object for legend extraction
p_legend_source <- p2 +
  theme(
    legend.position = "right", # enable legend position
    # adjust legend text and title size
    legend.text = element_text(size = 14),
    legend.title = element_text(size = 16),
    legend.key = element_blank(), # remove legend key background
    # increase spacing between legend items to reduce overlap of large circles
    legend.spacing.y = unit(10, "pt") 
  ) +
  guides(
    # turn off color and fill legends
    color = "none",
    fill = "none",
    # configure the size legend specifically
    size = guide_legend(
      title = "IncMSE",        # legend title
      label.position = "right",
      title.position = "top",
      order = 1,
      # [Important] override appearance: render legend circles in a neutral gray to avoid confusion
      override.aes = list(
        color = "grey80",   # border color (grey)
        fill = "grey80",   # fill color (grey)
        shape = 21         # ensures a fillable circular shape
      )
    )
  )

# 2. Extract the legend
legend_size <- get_legend(p_legend_source)

# ==================== Final combined plot ====================
p_all <- cowplot::plot_grid(
  p1, p2, legend_size,
  ncol = 3,
  # adjust width ratio: given the circle size (max 28), the legend may be wide; 0.2-0.3 is a reasonable allocation
  rel_widths = c(1, 1, 0.25) 
)

print(p_all)

ggsave(file.path(output_dir, "relative_importance_bubble.png"), p_all, width = 16, height = 8, dpi = 600)