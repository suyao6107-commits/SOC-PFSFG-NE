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

# Required packages
library(ggplot2)
library(dplyr)
library(agricolae)   # LSD.test
library(cowplot)
library(scales)      # alpha
# ========== Part 1: soc60_FT_ET_MT ==========================
# ========== 1. stock60_frozen type (boxplot) ==========
dat <- read.csv(file.path(data_dir, "stock60_type.csv"), header = TRUE)

anova <- aov(log_stock60 ~ Type, data = dat)
out <- LSD.test(anova, "Type", p.adj = "none")

mar <- out$groups
letters_df <- data.frame(group = rownames(mar), letters = mar$groups, stringsAsFactors = FALSE)

mean_df <- dat %>%
  group_by(Type) %>%
  summarise(mean_val = mean(log_stock60, na.rm = TRUE), .groups = "drop")

box_stats <- dat %>%
  group_by(Type) %>%
  summarise(ymax = max(log_stock60, na.rm = TRUE), .groups = "drop")

pos_df <- left_join(box_stats, letters_df, by = c("Type" = "group"))

dat$Type <- factor(dat$Type, levels = c("Permafrost", "Seasonal frozen ground"))
mean_df$Type <- factor(mean_df$Type, levels = levels(dat$Type))
pos_df$Type  <- factor(pos_df$Type, levels = levels(dat$Type))

border_colors <- c("Permafrost" = "#08519C", "Seasonal frozen ground" = "#6BAED6")
#fill_colors_box <- c("Permafrost" = "#08519C", "Seasonal frozen ground" = "#6BAED6")
fill_colors_box <- alpha(border_colors, 0.75)

yrange <- range(dat$log_stock60, na.rm = TRUE)
offset <- (yrange[2] - yrange[1]) * 0.02

p1 <- ggplot(dat, aes(x = Type, y = log_stock60,
                      fill = Type, color = Type)) +
  
  geom_boxplot(
    alpha = 0.75,
    width = 0.55,
    size  = 0.75,                # unify border thickness
    outlier.shape = 16,
    outlier.size  = 2,
    outlier.alpha = 0.25
  ) +
  
  geom_point(
    data = mean_df,
    aes(x = Type, y = mean_val),
    inherit.aes = FALSE,
    shape = 15, size = 2, color = "black"
  ) +
  
  geom_text(
    data = pos_df,
    aes(x = Type, y = ymax + offset, label = letters),
    inherit.aes = FALSE,
    vjust = 0, size = 5
  ) +
  
  scale_color_manual(values = border_colors, guide = "none") +
  scale_fill_manual(values = fill_colors_box, guide = "none") +
  
  labs(x = "Frozen type",
       y = expression("log-transformed SOC (kg m"^-2 * ")"))+
  
  scale_x_discrete(labels = c(
    "Permafrost" = "Permafrost",
    "Seasonal frozen ground" = "SFG"
  )) +
  
  scale_y_continuous(
    labels = function(x) sprintf("%.2f", x),
    limits = c(
      min(dat$log_stock60, na.rm = TRUE) - 0.05,
      max(dat$log_stock60, na.rm = TRUE) +
        (yrange[2] - yrange[1]) * 0.12
    )
  ) +
  
  theme_classic() +
  theme(
    axis.title.x = element_text(size = 18),
    axis.title.y = element_text(size = 18),
    axis.text.x  = element_text(size = 15, color = "black"),
    axis.text.y  = element_text(size = 15, color = "black")
  )
p1

# ========== 2. stock60_ecosystem type (boxplot) ==========
dat <- read.csv(file.path(data_dir, "stock60_ecosystem.csv"), header = TRUE)

anova <- aov(log_stock60 ~ Ecosystem, data = dat)
out <- LSD.test(anova, "Ecosystem", p.adj = "none")

mar <- out$groups
letters_df <- data.frame(group = rownames(mar), letters = mar$groups, stringsAsFactors = FALSE)

mean_df <- dat %>%
  group_by(Ecosystem) %>%
  summarise(mean_val = mean(log_stock60, na.rm = TRUE), .groups = "drop")

box_stats <- dat %>%
  group_by(Ecosystem) %>%
  summarise(ymax = max(log_stock60, na.rm = TRUE), .groups = "drop")

pos_df <- left_join(box_stats, letters_df, by = c("Ecosystem" = "group"))

dat$Ecosystem <- factor(dat$Ecosystem, levels = c("Wetland", "Forest", "Grassland"))
mean_df$Ecosystem <- factor(mean_df$Ecosystem, levels = levels(dat$Ecosystem))
pos_df$Ecosystem  <- factor(pos_df$Ecosystem, levels = levels(dat$Ecosystem))

border_colors <- c("Wetland" = "#2F7F4F", "Forest" = "#B6B86A", "Grassland" = "#2AA6A1")
#fill_colors_box <- c("Wetland" = "#2F7F4F", "Forest" = "#B6B86A", "Grassland" = "#2AA6A1")
fill_colors_box <- alpha(border_colors, 0.75)

yrange <- range(dat$log_stock60, na.rm = TRUE)
offset <- (yrange[2] - yrange[1]) * 0.02

p2 <- ggplot(dat, aes(x = Ecosystem, y = log_stock60,
                      fill = Ecosystem, color = Ecosystem)) +
  
  geom_boxplot(
    alpha = 0.75,
    width = 0.55,
    size  = 0.75,                # ★
    outlier.shape = 16,
    outlier.size  = 2,
    outlier.alpha = 0.45
  ) +
  
  geom_point(
    data = mean_df,
    aes(x = Ecosystem, y = mean_val),
    inherit.aes = FALSE,
    shape = 15, size = 2, color = "black"
  ) +
  
  geom_text(
    data = pos_df,
    aes(x = Ecosystem, y = ymax + offset, label = letters),
    inherit.aes = FALSE,
    vjust = 0, size = 5
  ) +
  
  scale_color_manual(values = border_colors, guide = "none") +
  scale_fill_manual(values = fill_colors_box, guide = "none") +
  
  labs(x = "Ecosystem type", y = "") +
  
  scale_y_continuous(
    labels = function(x) sprintf("%.2f", x),
    limits = c(
      min(dat$log_stock60, na.rm = TRUE) - 0.05,
      max(dat$log_stock60, na.rm = TRUE) +
        (yrange[2] - yrange[1]) * 0.12
    )
  ) +
  
  theme_classic() +
  theme(
    axis.title.x = element_text(size = 18),
    axis.text.x  = element_text(size = 15, color = "black"),
    axis.text.y  = element_text(size = 15, color = "black")
  )
p2

# ========== 3. stock60_mycorrhizal type (boxplot) ==========
dat <- read.csv(file.path(data_dir, "stock60_mycorrhiza.csv"), header = TRUE)
dat <- na.omit(dat)

anova <- aov(log_stock60 ~ Mycorrhiza, data = dat)
out <- LSD.test(anova, "Mycorrhiza", p.adj = "none")

mar <- out$groups
letters_df <- data.frame(group = rownames(mar), letters = mar$groups, stringsAsFactors = FALSE)

mean_df <- dat %>%
  group_by(Mycorrhiza) %>%
  summarise(mean_val = mean(log_stock60, na.rm = TRUE), .groups = "drop")

box_stats <- dat %>%
  group_by(Mycorrhiza) %>%
  summarise(ymax = max(log_stock60, na.rm = TRUE), .groups = "drop")

pos_df <- left_join(box_stats, letters_df, by = c("Mycorrhiza" = "group"))

dat$Mycorrhiza <- factor(dat$Mycorrhiza, levels = c("EcM", "AM", "NM"))
mean_df$Mycorrhiza <- factor(mean_df$Mycorrhiza, levels = levels(dat$Mycorrhiza))
pos_df$Mycorrhiza  <- factor(pos_df$Mycorrhiza, levels = levels(dat$Mycorrhiza))

border_colors <- c("EcM" = "#A02C2C", "AM" = "#E6B86A", "NM" = "#bea6a0")
#fill_colors_box <- c("EcM" = "#A02C2C", "AM" = "#E6B86A", "NM" = "#bea6a0")
fill_colors_box <- alpha(border_colors, 0.75)

yrange <- range(dat$log_stock60, na.rm = TRUE)
offset <- (yrange[2] - yrange[1]) * 0.02

p3 <- ggplot(dat, aes(x = Mycorrhiza, y = log_stock60,
                      fill = Mycorrhiza, color = Mycorrhiza)) +
  
  geom_boxplot(
    alpha = 0.75,
    width = 0.55,
    size  = 0.75,                # ★
    outlier.shape = 16,
    outlier.size  = 2,
    outlier.alpha = 0.45
  ) +
  
  geom_point(
    data = mean_df,
    aes(x = Mycorrhiza, y = mean_val),
    inherit.aes = FALSE,
    shape = 15, size = 2, color = "black"
  ) +
  
  geom_text(
    data = pos_df,
    aes(x = Mycorrhiza, y = ymax + offset, label = letters),
    inherit.aes = FALSE,
    vjust = 0, size = 5
  ) +
  
  scale_color_manual(values = border_colors, guide = "none") +
  scale_fill_manual(values = fill_colors_box, guide = "none") +
  
  labs(x = "Mycorrhizal type", y = "") +
  
  scale_y_continuous(
    labels = function(x) sprintf("%.2f", x),
    limits = c(
      min(dat$log_stock60, na.rm = TRUE) - 0.05,
      max(dat$log_stock60, na.rm = TRUE) +
        (yrange[2] - yrange[1]) * 0.12
    )
  ) +
  
  theme_classic() +
  theme(
    axis.title.x = element_text(size = 18),
    axis.text.x  = element_text(size = 15, color = "black"),
    axis.text.y  = element_text(size = 15, color = "black")
  )
p3

# ========== Combine plots ==========
p1_all <- cowplot::plot_grid(p1, p2, p3, ncol = 3)
p1_all
ggsave(file.path(output_dir, "soc60_FT_ET_MT.png"), p1_all, width = 12, height = 5, dpi = 600)

# ========== Part 2: grouped bar charts ==========================
# ========== 1. stock_layer (boxplot) ==========
dat <- read.csv(file.path(data_dir, "stock_layer.csv"), header = TRUE)

# ---- Statistics (unchanged) ----
anova <- aov(log_stock ~ layer, data = dat)
out   <- LSD.test(anova, "layer", p.adj = "none")

# ---- LSD letters ----
letters_df <- data.frame(
  layer   = rownames(out$groups),
  letters = out$groups$groups,
  stringsAsFactors = FALSE
)

# ---- Mean & max ----
mean_df <- dat %>%
  group_by(layer) %>%
  summarise(mean_val = mean(log_stock, na.rm = TRUE), .groups = "drop")

box_df <- dat %>%
  group_by(layer) %>%
  summarise(ymax = max(log_stock, na.rm = TRUE), .groups = "drop") %>%
  left_join(letters_df, by = "layer")

# ---- Factor order ----
dat$layer     <- factor(dat$layer, levels = c("40-60","20-40","0-20"))
mean_df$layer <- factor(mean_df$layer, levels = levels(dat$layer))
box_df$layer  <- factor(box_df$layer,  levels = levels(dat$layer))

# ---- Colors ----
border_colors <- c("0-20"="black","20-40"="black","40-60"="black")
fill_colors <- c("0-20"="gray35","20-40"="gray70","40-60"="gray90")
#fill_colors   <- alpha(border_colors, 0.35)

yrange <- range(dat$log_stock, na.rm = TRUE)
offset <- diff(yrange) * 0.02

# ---- Plot ----
p0 <- ggplot(dat, aes(x = layer, y = log_stock,
                      fill = layer, color = layer)) +
  
  geom_boxplot(
    alpha = 1,
    width = 0.55,
    size = 0.25,
    outlier.shape = 16,   # show outliers only
    outlier.size  = 2,
    outlier.alpha = 0.25
  ) +
  
  # ---- Mean point (kept) ----
geom_point(data = mean_df,
           aes(x = layer, y = mean_val),
           inherit.aes = FALSE,
           shape = 15, size = 2, color = "black") +
  
  # ---- LSD letters (kept) ----
geom_text(data = box_df,
          aes(x = layer, y = ymax + offset, label = letters),
          inherit.aes = FALSE, size = 6) +
  
  scale_fill_manual(values = fill_colors, guide = "none") +
  scale_color_manual(values = border_colors, guide = "none") +
  coord_flip() +
  labs(x = "Layer (cm)",
       y = expression("log-transformed SOC (kg m"^-2 * ")")) +
  theme_classic() +
  theme(axis.text  = element_text(size = 18),
        axis.title = element_text(size = 20))

p0
p0 <- p0 +
  theme(
    axis.text  = element_text(size = 14, color = "black"),  # 🔧
    legend.title = element_blank()                           # 🔧
  )
p0

ggsave(file.path(output_dir, "soc_layer.png"), p0, width = 5, height = 5, dpi = 600)

# =========================== SOC changes by depth layer, for each of the three classifications ===========================================
library(tidyverse)
library(agricolae)
library(cowplot)

# ==============================================================================
# 0. Global settings: color and alpha definitions
# ==============================================================================

# 1. Define color mapping for each group
# Frozen Type colors
ft_colors <- c(
  "Permafrost"             = "#08519C", 
  "Seasonal frozen ground" = "#6BAED6"
)

# Ecosystem Type colors
et_colors <- c(
  "Wetland"   = "#2F7F4F", 
  "Forest"    = "#B6B86A", 
  "Grassland" = "#2AA6A1"
)

# Mycorrhizal Type colors
mt_colors <- c(
  "ErM" = "#3A3A3A", 
  "EcM" = "#A02C2C", 
  "AM"  = "#E6B86A", 
  "NM"  = "#bea6a0"
)

# 2. Define alpha (transparency) mapping for soil depth layers
layer_alphas <- c(
  "0-20"  = 1, 
  "20-40" = 0.6, 
  "40-60" = 0.3
)

# 3. Generic LSD calculation function (unchanged)
get_layer_letters <- function(df, group_col_name, group_col_val){
  fit  <- aov(log_stock ~ layer, data = df)
  out  <- LSD.test(fit, "layer", p.adj = "none")
  res <- data.frame(
    layer   = rownames(out$groups),
    letters = out$groups$groups,
    stringsAsFactors = FALSE
  )
  res[[group_col_name]] <- group_col_val
  return(res)
}

# ==============================================================================
# 1. stock_FT (FT * Layer) -> bar chart + error bars
# ==============================================================================
dat <- read.csv(file.path(data_dir, "stock_type.csv"), header = TRUE)

# ---- LSD analysis ----
type_levels <- unique(dat$Type) 
letters_list <- list()
for(t in type_levels){
  sub_dat <- dat %>% filter(Type == t)
  letters_list[[t]] <- get_layer_letters(sub_dat, "Type", t)
}
letters_df <- bind_rows(letters_list)

# ---- Data aggregation ----
plot_df <- dat %>%
  group_by(Type, layer) %>%
  summarise(
    mean_val = mean(log_stock, na.rm = TRUE),
    sd_val   = sd(log_stock, na.rm = TRUE),
    n        = n(),
    se_val   = sd_val / sqrt(n),
    .groups  = "drop"
  ) %>%
  left_join(letters_df, by = c("Type", "layer"))

# ---- Factor order (unchanged) ----
dat$layer <- factor(dat$layer, levels = c("40-60", "20-40", "0-20")) 
dat$Type  <- factor(dat$Type, levels = c("Seasonal frozen ground", "Permafrost"))

plot_df$layer <- factor(plot_df$layer, levels = levels(dat$layer))
plot_df$Type  <- factor(plot_df$Type,  levels = levels(dat$Type))

# Offset
yrange <- range(c(0, dat$log_stock), na.rm = TRUE)
offset <- diff(yrange) * 0.05 

# ---- Plot (color mapped to Type, alpha mapped to Layer) ----
p4 <- ggplot(plot_df, aes(x = Type, y = mean_val, fill = Type, color = Type, alpha = layer, group = layer)) +
  # Note: group = layer is required, otherwise ggplot will not dodge bars because fill and x are the same
  
  geom_bar(
    stat = "identity",
    position = position_dodge(0.65),
    width = 0.55,
    size = 0.8
  ) +
  geom_errorbar(
    aes(ymin = mean_val - se_val, ymax = mean_val + se_val),
    position = position_dodge(0.65),
    width = 0.2,
    size = 0.8,
    alpha = 1 # error bars are kept fully opaque for clarity
  ) +
  geom_text(
    aes(y = mean_val + se_val + offset, label = letters),
    position = position_dodge(0.65),
    size = 6,
    color = "black", # keep letters black
    alpha = 1,       # keep letters fully opaque
    show.legend = FALSE
  ) +
  
  scale_x_discrete(labels = c("Seasonal frozen ground" = "SFG", "Permafrost" = "Permafrost")) +
  
  # Apply custom colors and alpha
  scale_fill_manual(values = ft_colors) +
  scale_color_manual(values = ft_colors) + # border color matches fill color
  scale_alpha_manual(values = layer_alphas) +
  
  coord_flip() +
  labs(x = "", y = expression("log-transformed SOC (kg m"^-2 * ")")) +
  theme_classic() +
  theme(
    axis.text  = element_text(size = 14, color = "black"),
    axis.title = element_text(size = 18),
    legend.position = "none" # hide legend
  )

p4

# ==============================================================================
# 2. stock_ET (Ecosystem * Layer) -> bar chart + error bars
# ==============================================================================
dat <- read.csv(file.path(data_dir, "stock_ecosystem.csv"), header = TRUE)

# ---- LSD ----
eco_levels <- unique(dat$Ecosystem)
letters_list <- list()
for(e in eco_levels){
  sub_dat <- dat %>% filter(Ecosystem == e)
  letters_list[[e]] <- get_layer_letters(sub_dat, "Ecosystem", e)
}
letters_df <- bind_rows(letters_list)

# ---- Aggregation ----
plot_df <- dat %>%
  group_by(Ecosystem, layer) %>%
  summarise(
    mean_val = mean(log_stock, na.rm = TRUE),
    sd_val   = sd(log_stock, na.rm = TRUE),
    n        = n(),
    se_val   = sd_val / sqrt(n),
    .groups  = "drop"
  ) %>%
  left_join(letters_df, by = c("Ecosystem", "layer"))

# ---- Factor order ----
dat$layer <- factor(dat$layer, levels = c("40-60", "20-40", "0-20"))
dat$Ecosystem <- factor(dat$Ecosystem, levels = c("Grassland", "Forest", "Wetland"))

plot_df$layer <- factor(plot_df$layer, levels = levels(dat$layer))
plot_df$Ecosystem <- factor(plot_df$Ecosystem, levels = levels(dat$Ecosystem))

yrange <- range(c(0, dat$log_stock), na.rm = TRUE)
offset <- diff(yrange) * 0.05

# ---- Plot ----
p5 <- ggplot(plot_df, aes(x = Ecosystem, y = mean_val, fill = Ecosystem, color = Ecosystem, alpha = layer, group = layer)) +
  geom_bar(
    stat = "identity",
    position = position_dodge(0.65),
    width = 0.55,
    size = 0.8
  ) +
  geom_errorbar(
    aes(ymin = mean_val - se_val, ymax = mean_val + se_val),
    position = position_dodge(0.65),
    width = 0.2,
    size = 0.8,
    alpha = 1
  ) +
  geom_text(
    aes(y = mean_val + se_val + offset, label = letters),
    position = position_dodge(0.65),
    size = 6,
    color = "black",
    alpha = 1,
    show.legend = FALSE
  ) +
  
  # Apply custom colors and alpha
  scale_fill_manual(values = et_colors) +
  scale_color_manual(values = et_colors) +
  scale_alpha_manual(values = layer_alphas) +
  
  coord_flip() +
  labs(x = "", y = expression("log-transformed SOC (kg m"^-2 * ")")) +
  theme_classic() +
  theme(
    axis.text  = element_text(size = 14, color = "black"),
    axis.title = element_text(size = 18),
    legend.position = "none"
  )

p5


# ==============================================================================
# 3. stock_MT (Mycorrhiza * Layer) -> bar chart + error bars
# ==============================================================================
dat <- read.csv(file.path(data_dir, "stock_mycorrhiza.csv"), header = TRUE)

# ---- LSD ----
myc_levels <- unique(dat$Mycorrhiza)
letters_list <- list()
for(m in myc_levels){
  sub_dat <- dat %>% filter(Mycorrhiza == m)
  letters_list[[m]] <- get_layer_letters(sub_dat, "Mycorrhiza", m)
}
letters_df <- bind_rows(letters_list)

# ---- Aggregation ----
plot_df <- dat %>%
  group_by(Mycorrhiza, layer) %>%
  summarise(
    mean_val = mean(log_stock, na.rm = TRUE),
    sd_val   = sd(log_stock, na.rm = TRUE),
    n        = n(),
    se_val   = sd_val / sqrt(n),
    .groups  = "drop"
  ) %>%
  left_join(letters_df, by = c("Mycorrhiza", "layer"))

# ---- Factor order ----
dat$layer <- factor(dat$layer, levels = c("40-60", "20-40", "0-20"))
dat$Mycorrhiza <- factor(dat$Mycorrhiza, levels = c("NM", "AM", "EcM", "ErM"))

plot_df$layer <- factor(plot_df$layer, levels = levels(dat$layer))
plot_df$Mycorrhiza <- factor(plot_df$Mycorrhiza, levels = levels(dat$Mycorrhiza))

yrange <- range(c(0, dat$log_stock), na.rm = TRUE)
offset <- diff(yrange) * 0.05

# ---- Plot ----
p6 <- ggplot(plot_df, aes(x = Mycorrhiza, y = mean_val, fill = Mycorrhiza, color = Mycorrhiza, alpha = layer, group = layer)) +
  geom_bar(
    stat = "identity",
    position = position_dodge(0.65),
    width = 0.55,
    size = 0.8
  ) +
  geom_errorbar(
    aes(ymin = mean_val - se_val, ymax = mean_val + se_val),
    position = position_dodge(0.65),
    width = 0.2,
    size = 0.8,
    alpha = 1
  ) +
  geom_text(
    aes(y = mean_val + se_val + offset, label = letters),
    position = position_dodge(0.65),
    size = 6,
    color = "black",
    alpha = 1,
    show.legend = FALSE
  ) +
  
  # Apply custom colors and alpha
  scale_fill_manual(values = mt_colors) +
  scale_color_manual(values = mt_colors) +
  scale_alpha_manual(values = layer_alphas) +
  
  coord_flip() +
  labs(x = "", y = expression("log-transformed SOC (kg m"^-2 * ")")) +
  theme_classic() +
  theme(
    axis.text  = element_text(size = 14, color = "black"),
    axis.title = element_text(size = 18),
    legend.position = "none"
  )

p6

# ==============================================================================
# 4. Combine and save
# ==============================================================================
p2_all <- cowplot::plot_grid(p4, p5, p6, ncol = 3)
print(p2_all)

# Adjust the output path as needed
ggsave(file.path(output_dir, "soc_layer_FT_ET_MT_1.png"), p2_all, width = 14, height = 5, dpi = 600)

p3_all <- cowplot::plot_grid(
  p1, p2, p3,
  p4, p5, p6,
  ncol = 3,
  align = "hv",
  axis = "tblr")
print(p3_all)
# Adjust the output path as needed
ggsave(file.path(output_dir, "Fig1_combined.png"), p3_all, width = 15, height = 10, dpi = 600)