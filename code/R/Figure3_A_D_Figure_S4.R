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

# 安装与加载包
# install.packages(c("ggplot2", "dplyr", "ggpubr", "ggpmisc", "scales"))
library(ggplot2)
library(dplyr)
library(ggpubr)
library(ggpmisc)
library(scales) # 必须加载，用于处理颜色透明度
library(cowplot)

# 0-20cm--------------------------------------------------------------------------
# 读取与预处理数据
dat <- read.csv(file.path(data_dir, "mat_stock.csv"), header = T)
newdat <- na.omit(dat)

# 定义缩写映射向量
et_abbr <- c('Wetland' = 'W', 'Forest' = 'F', 'Grassland' = 'G', 
             'Permafrost' = 'Permafrost', 'Seasonal frozen ground' = "SFG")

#-----------------------------MAT_ET---------------------------------------------
# 设置因子顺序
newdat$Type <- factor(newdat$Type, levels = c('Permafrost', 'Seasonal frozen ground'))

base_colors_et <- c("#08519C", "#6BAED6")
fill_colors_et <- scales::alpha(base_colors_et, 0.5)

shape_type <- c("Permafrost" = 22, "Seasonal frozen ground" = 21)

p0 <- ggplot(newdat, aes(x = MAT, y = log_stock,
                         color = Type, fill = Type, shape = Type)) +
  geom_point(size = 3.5, stroke = 0.8) +
  geom_smooth(method = 'lm', formula = y ~ x, se = FALSE, size = 1,
              aes(linetype = Type)) +
  # 颜色 / 填充 / 形状 / 线型 映射（颜色关系不变）
  scale_color_manual(values = base_colors_et, labels = et_abbr) +
  scale_fill_manual(values = fill_colors_et, labels = et_abbr) +
  scale_shape_manual(values = shape_type, labels = et_abbr) +
  scale_linetype_manual(values = c("dashed", "solid"), labels = et_abbr) +
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
  # 图例中点的样式同步：shape、fill 都要对齐顺序（用 unname 确保向量顺序）
  guides(color = guide_legend(override.aes = list(
    shape = unname(shape_type),
    size  = 5,
    stroke = 1,
    fill  = unname(fill_colors_et)
  )))

p0
#-----------------------------MAT_ET---------------------------------------------
# 设置因子顺序
newdat$Ecosystem <- factor(
  newdat$Ecosystem,
  levels = c("Wetland", "Forest", "Grassland")
)

# 颜色（保持你原来的）
base_colors_et <- c(
  "Wetland"   = "#2F7F4F",
  "Forest"    = "#B6B86A",
  "Grassland" = "#2AA6A1"
)

fill_colors_et <- scales::alpha(base_colors_et, 0.5)

# 形状映射（新增）
shape_et <- c(
  "Wetland"   = 21,
  "Forest"    = 24,
  "Grassland" = 22
)

p1 <- ggplot(
  newdat,
  aes(
    x = MAT,
    y = log_stock,
    color = Ecosystem,
    fill  = Ecosystem,
    shape = Ecosystem
  )
) +
  # 散点
  geom_point(
    size = 3.5,
    stroke = 0.8
  ) +
  # 拟合线（颜色随 Ecosystem）
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    size = 1,
    aes(linetype = Ecosystem)
  ) +
  # 颜色 / 填充 / 形状 / 线型
  scale_color_manual(values = base_colors_et, labels = et_abbr) +
  scale_fill_manual(values  = fill_colors_et, labels = et_abbr) +
  scale_shape_manual(values = shape_et, labels = et_abbr) +
  scale_linetype_manual(values = c("solid", "solid", "solid"), labels = et_abbr) +
  # 坐标轴
  scale_y_continuous(labels = scales::label_number(accuracy = 0.1)) +
  # R² 和 p 值（每个 Ecosystem 单独计算）
  stat_poly_eq(
    use_label(c("R2", "p.value.label")),
    label.x = 0.05,
    label.y = "bottom",
    size = 5.5
  ) +
  # 标签
  ylab(expression("log-transformed SOC (kg m"^-2 * ")")) +
  xlab("MAT (°C)") +
  # 主题
  theme_classic() +
  theme(
    legend.title = element_blank(),
    legend.position = c(0.8, 0.8),
    legend.text = element_text(size = 14),
    axis.text = element_text(size = 16, color = "black"),
    axis.title = element_text(size = 18, color = "black"),
    panel.border = element_rect(
      fill = NA,
      color = "black",
      linewidth = 0.5
    )
  ) +
  # 图例中点的样式同步
  guides(
    color = guide_legend(
      override.aes = list(
        size   = 5,
        stroke = 1,
        shape  = shape_et,
        fill   = fill_colors_et
      )
    )
  )

p1
#-----------------------------MAT_MT---------------------------------------------
# 设置因子顺序
newdat$Mycorrhiza <- factor(
  newdat$Mycorrhiza,
  levels = c("ErM", "EcM", "AM", "NM")
)

# 基础颜色（用于边框和拟合线）
base_colors <- c(
  "ErM" = "#3A3A3A",
  "EcM" = "#A02C2C",
  "AM"  = "#E6B86A",
  "NM"  = "#bea6a0"
)

# 填充颜色（透明度）
fill_colors <- scales::alpha(base_colors, 0.5)

# 形状映射（新增）
shape_myc <- c(
  "ErM" = 21,
  "EcM" = 22,
  "AM"  = 23,
  "NM"  = 24
)

p2 <- ggplot(
  newdat,
  aes(
    x = MAT,
    y = log_stock,
    color = Mycorrhiza,
    fill  = Mycorrhiza,
    shape = Mycorrhiza
  )
) +
  # 散点
  geom_point(
    size = 3.5,
    stroke = 0.8
  ) +
  # 拟合线
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    size = 1,
    aes(linetype = Mycorrhiza)
  ) +
  # 手动映射
  scale_color_manual(values = base_colors) +
  scale_fill_manual(values  = fill_colors) +
  scale_shape_manual(values = shape_myc) +
  scale_linetype_manual(values = c("dashed", "solid", "solid", "solid")) +
  # 坐标轴
  scale_y_continuous(labels = scales::label_number(accuracy = 0.1)) +
  # 回归统计量
  stat_poly_eq(
    use_label(c("R2", "p.value.label")),
    label.x = 0.05,
    label.y = "bottom",
    size = 5.5
  ) +
  # 标签
  ylab(expression("log-transformed SOC (kg m"^-2 * ")")) +
  xlab("MAT (°C)") +
  # 主题
  theme_classic() +
  theme(
    legend.title = element_blank(),
    legend.position = c(0.8, 0.8),
    legend.text = element_text(size = 14),
    axis.text = element_text(size = 16, color = "black"),
    axis.title = element_text(size = 18, color = "black"),
    panel.border = element_rect(
      fill = NA,
      color = "black",
      linewidth = 0.5
    )
  ) +
  # 图例同步（关键）
  guides(
    color = guide_legend(
      override.aes = list(
        shape  = shape_myc,
        size   = 5,
        fill   = fill_colors,
        stroke = 1
      )
    )
  )

p2

p_all <- cowplot::plot_grid(
  p0, p1, p2, 
  ncol = 3,
  align = "h",
  axis = "tb")
print(p_all)
ggsave(file.path(output_dir, "0_20_soc_MAT_sensitivity_FT_ET_MT.png"), p_all, width = 15, height = 5, dpi = 600)

#-----------------------------敏感性分析---------------------------------------------
library(tidyverse)
library(scales)

# 1. 数据准备与计算函数
sens_data <- newdat %>% filter(!is.na(MAT), !is.na(log_stock))

calc_sensitivity_log10_refined <- function(df) {
  if(nrow(df) < 3) return(tibble(b = NA_real_, se_b = NA_real_, sensitivity = NA_real_, lower = NA_real_, upper = NA_real_))
  fit <- lm(log_stock ~ MAT, data = df)
  s   <- summary(fit)
  b    <- coef(fit)[2]
  se_b <- s$coefficients[2,2]
  sens  <- 10^(-10 * b)
  tibble(b = b, se_b = se_b, sensitivity = sens, lower = 10^(-10 * (b + 1.96 * se_b)), upper = 10^(-10 * (b - 1.96 * se_b)))
}

# 2. 分组计算并设置缩写分面名称
sens_FT <- sens_data %>% filter(!is.na(Type)) %>% group_by(Type) %>% 
  group_modify(~ calc_sensitivity_log10_refined(.x)) %>% ungroup() %>% 
  mutate(Facet = "FT") %>% rename(Group = Type)

sens_ET <- sens_data %>% filter(!is.na(Ecosystem)) %>% group_by(Ecosystem) %>% 
  group_modify(~ calc_sensitivity_log10_refined(.x)) %>% ungroup() %>% 
  mutate(Facet = "ET") %>% rename(Group = Ecosystem)

sens_MT <- sens_data %>% filter(!is.na(Mycorrhiza)) %>% group_by(Mycorrhiza) %>% 
  group_modify(~ calc_sensitivity_log10_refined(.x)) %>% ungroup() %>% 
  mutate(Facet = "MT") %>% rename(Group = Mycorrhiza)

# 3. 合并与因子排序 (⚠️此处已修改：剔除ErM并更新因子顺序)
sens_all <- bind_rows(sens_FT, sens_ET, sens_MT) %>% 
  filter(Group != "ErM") # 仅在敏感性分析图数据中去除 ErM
print(sens_all)
sens_all$Facet <- factor(sens_all$Facet, levels = c("FT", "ET", "MT"))
# 从 levels 中移除 "ErM"，防止图表X轴出现空白占位
desired_order <- c("Permafrost", "Seasonal frozen ground", "Wetland", "Forest", "Grassland", "EcM", "AM", "NM")
sens_all$Group <- factor(sens_all$Group, levels = desired_order)

# 4. 定义颜色与形状映射 (颜色和形状字典保留完整不会报错)
color_map <- c(
  "Permafrost" = "#08519C", "Seasonal frozen ground" = "#6BAED6",
  "Wetland" = "#2F7F4F", "Forest" = "#B6B86A", "Grassland" = "#2AA6A1",
  "ErM" = "#3A3A3A", "EcM" = "#A02C2C", "AM" = "#E6B86A", "NM" = "#bea6a0"
)

shape_map <- c(
  "Permafrost" = 22, "Seasonal frozen ground" = 21,
  "Wetland" = 21, "Forest" = 24, "Grassland" = 22,
  "ErM" = 21, "EcM" = 22, "AM" = 23, "NM" = 24
)

# 5. 可视化绘制
p3 <- ggplot(sens_all, aes(x = Group, y = sensitivity, color = Group, shape = Group, fill = Group)) +
  facet_grid(. ~ Facet, scales = "free_x", space = "free_x", switch = "x") +
  
  geom_hline(yintercept = 1, linetype = "dashed", color = "black") + 
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.15, size = 0.8) +
  geom_point(size = 5, stroke = 1.2) +
  
  scale_color_manual(values = color_map) +
  scale_fill_manual(values = alpha(color_map, 0.35)) + 
  scale_shape_manual(values = shape_map) +
  
  labs(x = NULL, y = expression("Proportional decline in C (10 " * degree * "C)")) +
  
  coord_cartesian(ylim = c(NA, 35)) +
  
  theme_classic() +
  theme(
    legend.position = "none",
    # 分面标题 (FT, ET, MT)
    strip.background = element_blank(),
    strip.placement = "outside", 
    strip.text = element_text(size = 18, color = "black"),
    
    # 坐标轴设置
    axis.text.x = element_blank(), # 隐去 X 轴标签
    axis.text.y = element_text(size = 16, color = "black"),
    axis.title.y = element_text(size = 18),
    
    # 间隙与边框设置
    panel.spacing = unit(0, "lines"),
    panel.border = element_rect(fill = NA, color = "black", linewidth = 0.5),
    panel.background = element_blank()
  )

p3

ggsave(file.path(output_dir, "0_20_soc_MAT_sensitivity_FT_ET_MT_1.png"), p3, width = 5, height = 5, dpi = 600)

p1_all <- cowplot::plot_grid(
  p0, p1, p2, p3,
  ncol = 4,
  align = "h",
  axis = "tb")
print(p1_all)
ggsave(file.path(output_dir, "0_20_soc_MAT_sensitivity_1.png"), p1_all, width = 20, height = 5, dpi = 600)

p2_all <- cowplot::plot_grid(
  p0, p1, p2, p3,
  ncol = 2,
  align = "h",
  axis = "tb")
print(p2_all)
ggsave(file.path(output_dir, "0_20_soc_MAT_sensitivity_0429.png"), p2_all, width = 10, height = 10, dpi = 600)


# 20-40cm--------------------------------------------------------------------------
# 读取与预处理数据
dat <- read.csv(file.path(data_dir, "mat_stock.csv"), header = T)
newdat <- na.omit(dat)

# 定义缩写映射向量
et_abbr <- c('Wetland' = 'W', 'Forest' = 'F', 'Grassland' = 'G', 
             'Permafrost' = 'Permafrost', 'Seasonal frozen ground' = "SFG")

#-----------------------------MAT_ET---------------------------------------------
# 设置因子顺序
newdat$Type <- factor(newdat$Type, levels = c('Permafrost', 'Seasonal frozen ground'))

base_colors_et <- c("#08519C", "#6BAED6")
fill_colors_et <- scales::alpha(base_colors_et, 0.5)

shape_type <- c("Permafrost" = 22, "Seasonal frozen ground" = 21)

p0 <- ggplot(newdat, aes(x = MAT, y = log_stock,
                         color = Type, fill = Type, shape = Type)) +
  geom_point(size = 3.5, stroke = 0.8) +
  geom_smooth(method = 'lm', formula = y ~ x, se = FALSE, size = 1,
              aes(linetype = Type)) +
  # 颜色 / 填充 / 形状 / 线型 映射（颜色关系不变）
  scale_color_manual(values = base_colors_et, labels = et_abbr) +
  scale_fill_manual(values = fill_colors_et, labels = et_abbr) +
  scale_shape_manual(values = shape_type, labels = et_abbr) +
  scale_linetype_manual(values = c("dashed", "solid"), labels = et_abbr) +
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
  # 图例中点的样式同步：shape、fill 都要对齐顺序（用 unname 确保向量顺序）
  guides(color = guide_legend(override.aes = list(
    shape = unname(shape_type),
    size  = 5,
    stroke = 1,
    fill  = unname(fill_colors_et)
  )))

p0
#-----------------------------MAT_ET---------------------------------------------
# 设置因子顺序
newdat$Ecosystem <- factor(
  newdat$Ecosystem,
  levels = c("Wetland", "Forest", "Grassland")
)

# 颜色（保持你原来的）
base_colors_et <- c(
  "Wetland"   = "#2F7F4F",
  "Forest"    = "#B6B86A",
  "Grassland" = "#2AA6A1"
)

fill_colors_et <- scales::alpha(base_colors_et, 0.5)

# 形状映射（新增）
shape_et <- c(
  "Wetland"   = 21,
  "Forest"    = 24,
  "Grassland" = 22
)

p1 <- ggplot(
  newdat,
  aes(
    x = MAT,
    y = log_stock,
    color = Ecosystem,
    fill  = Ecosystem,
    shape = Ecosystem
  )
) +
  # 散点
  geom_point(
    size = 3.5,
    stroke = 0.8
  ) +
  # 拟合线（颜色随 Ecosystem）
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    size = 1,
    aes(linetype = Ecosystem)
  ) +
  # 颜色 / 填充 / 形状 / 线型
  scale_color_manual(values = base_colors_et, labels = et_abbr) +
  scale_fill_manual(values  = fill_colors_et, labels = et_abbr) +
  scale_shape_manual(values = shape_et, labels = et_abbr) +
  scale_linetype_manual(values = c("solid", "solid", "solid"), labels = et_abbr) +
  # 坐标轴
  scale_y_continuous(labels = scales::label_number(accuracy = 0.1)) +
  # R² 和 p 值（每个 Ecosystem 单独计算）
  stat_poly_eq(
    use_label(c("R2", "p.value.label")),
    label.x = 0.05,
    label.y = "bottom",
    size = 5.5
  ) +
  # 标签
  ylab(expression("log-transformed SOC (kg m"^-2 * ")")) +
  xlab("MAT (°C)") +
  # 主题
  theme_classic() +
  theme(
    legend.title = element_blank(),
    legend.position = c(0.8, 0.8),
    legend.text = element_text(size = 14),
    axis.text = element_text(size = 16, color = "black"),
    axis.title = element_text(size = 18, color = "black"),
    panel.border = element_rect(
      fill = NA,
      color = "black",
      linewidth = 0.5
    )
  ) +
  # 图例中点的样式同步
  guides(
    color = guide_legend(
      override.aes = list(
        size   = 5,
        stroke = 1,
        shape  = shape_et,
        fill   = fill_colors_et
      )
    )
  )

p1
#-----------------------------MAT_MT---------------------------------------------
# 设置因子顺序
newdat$Mycorrhiza <- factor(
  newdat$Mycorrhiza,
  levels = c("ErM", "EcM", "AM", "NM")
)

# 基础颜色（用于边框和拟合线）
base_colors <- c(
  "ErM" = "#3A3A3A",
  "EcM" = "#A02C2C",
  "AM"  = "#E6B86A",
  "NM"  = "#bea6a0"
)

# 填充颜色（透明度）
fill_colors <- scales::alpha(base_colors, 0.5)

# 形状映射（新增）
shape_myc <- c(
  "ErM" = 21,
  "EcM" = 22,
  "AM"  = 23,
  "NM"  = 24
)

p2 <- ggplot(
  newdat,
  aes(
    x = MAT,
    y = log_stock,
    color = Mycorrhiza,
    fill  = Mycorrhiza,
    shape = Mycorrhiza
  )
) +
  # 散点
  geom_point(
    size = 3.5,
    stroke = 0.8
  ) +
  # 拟合线
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    size = 1,
    aes(linetype = Mycorrhiza)
  ) +
  # 手动映射
  scale_color_manual(values = base_colors) +
  scale_fill_manual(values  = fill_colors) +
  scale_shape_manual(values = shape_myc) +
  scale_linetype_manual(values = c("dashed", "solid", "solid", "solid")) +
  # 坐标轴
  scale_y_continuous(labels = scales::label_number(accuracy = 0.1)) +
  # 回归统计量
  stat_poly_eq(
    use_label(c("R2", "p.value.label")),
    label.x = 0.05,
    label.y = "bottom",
    size = 5.5
  ) +
  # 标签
  ylab(expression("log-transformed SOC (kg m"^-2 * ")")) +
  xlab("MAT (°C)") +
  # 主题
  theme_classic() +
  theme(
    legend.title = element_blank(),
    legend.position = c(0.8, 0.8),
    legend.text = element_text(size = 14),
    axis.text = element_text(size = 16, color = "black"),
    axis.title = element_text(size = 18, color = "black"),
    panel.border = element_rect(
      fill = NA,
      color = "black",
      linewidth = 0.5
    )
  ) +
  # 图例同步（关键）
  guides(
    color = guide_legend(
      override.aes = list(
        shape  = shape_myc,
        size   = 5,
        fill   = fill_colors,
        stroke = 1
      )
    )
  )

p2

p_all <- cowplot::plot_grid(
  p0, p1, p2, 
  ncol = 3,
  align = "h",
  axis = "tb")
print(p_all)
ggsave(file.path(output_dir, "0_20_soc_MAT_sensitivity_FT_ET_MT.png"), p_all, width = 15, height = 5, dpi = 600)

#-----------------------------敏感性分析---------------------------------------------
library(tidyverse)
library(scales)

# 1. 数据准备与计算函数
sens_data <- newdat %>% filter(!is.na(MAT), !is.na(log_stock))

calc_sensitivity_log10_refined <- function(df) {
  if(nrow(df) < 3) return(tibble(b = NA_real_, se_b = NA_real_, sensitivity = NA_real_, lower = NA_real_, upper = NA_real_))
  fit <- lm(log_stock ~ MAT, data = df)
  s   <- summary(fit)
  b    <- coef(fit)[2]
  se_b <- s$coefficients[2,2]
  sens  <- 10^(-10 * b)
  tibble(b = b, se_b = se_b, sensitivity = sens, lower = 10^(-10 * (b + 1.96 * se_b)), upper = 10^(-10 * (b - 1.96 * se_b)))
}

# 2. 分组计算并设置缩写分面名称
sens_FT <- sens_data %>% filter(!is.na(Type)) %>% group_by(Type) %>% 
  group_modify(~ calc_sensitivity_log10_refined(.x)) %>% ungroup() %>% 
  mutate(Facet = "FT") %>% rename(Group = Type)

sens_ET <- sens_data %>% filter(!is.na(Ecosystem)) %>% group_by(Ecosystem) %>% 
  group_modify(~ calc_sensitivity_log10_refined(.x)) %>% ungroup() %>% 
  mutate(Facet = "ET") %>% rename(Group = Ecosystem)

sens_MT <- sens_data %>% filter(!is.na(Mycorrhiza)) %>% group_by(Mycorrhiza) %>% 
  group_modify(~ calc_sensitivity_log10_refined(.x)) %>% ungroup() %>% 
  mutate(Facet = "MT") %>% rename(Group = Mycorrhiza)

# 3. 合并与因子排序 (⚠️此处已修改：剔除ErM并更新因子顺序)
sens_all <- bind_rows(sens_FT, sens_ET, sens_MT) %>% 
  filter(Group != "ErM") # 仅在敏感性分析图数据中去除 ErM
print(sens_all)

sens_all$Facet <- factor(sens_all$Facet, levels = c("FT", "ET", "MT"))
# 从 levels 中移除 "ErM"，防止图表X轴出现空白占位
desired_order <- c("Permafrost", "Seasonal frozen ground", "Wetland", "Forest", "Grassland", "EcM", "AM", "NM")
sens_all$Group <- factor(sens_all$Group, levels = desired_order)

# 4. 定义颜色与形状映射 (颜色和形状字典保留完整不会报错)
color_map <- c(
  "Permafrost" = "#08519C", "Seasonal frozen ground" = "#6BAED6",
  "Wetland" = "#2F7F4F", "Forest" = "#B6B86A", "Grassland" = "#2AA6A1",
  "ErM" = "#3A3A3A", "EcM" = "#A02C2C", "AM" = "#E6B86A", "NM" = "#bea6a0"
)

shape_map <- c(
  "Permafrost" = 22, "Seasonal frozen ground" = 21,
  "Wetland" = 21, "Forest" = 24, "Grassland" = 22,
  "ErM" = 21, "EcM" = 22, "AM" = 23, "NM" = 24
)

# 5. 可视化绘制
p3 <- ggplot(sens_all, aes(x = Group, y = sensitivity, color = Group, shape = Group, fill = Group)) +
  facet_grid(. ~ Facet, scales = "free_x", space = "free_x", switch = "x") +
  
  geom_hline(yintercept = 1, linetype = "dashed", color = "black") + 
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.15, size = 0.8) +
  geom_point(size = 5, stroke = 1.2) +
  
  scale_color_manual(values = color_map) +
  scale_fill_manual(values = alpha(color_map, 0.35)) + 
  scale_shape_manual(values = shape_map) +
  
  labs(x = NULL, y = expression("Proportional decline in C (10 " * degree * "C)")) +
  
  #coord_cartesian(ylim = c(NA, 40)) +
  
  theme_classic() +
  theme(
    legend.position = "none",
    # 分面标题 (FT, ET, MT)
    strip.background = element_blank(),
    strip.placement = "outside", 
    strip.text = element_text(size = 18, color = "black"),
    
    # 坐标轴设置
    axis.text.x = element_blank(), # 隐去 X 轴标签
    axis.text.y = element_text(size = 16, color = "black"),
    axis.title.y = element_text(size = 18),
    
    # 间隙与边框设置
    panel.spacing = unit(0, "lines"),
    panel.border = element_rect(fill = NA, color = "black", linewidth = 0.5),
    panel.background = element_blank()
  )

p3

ggsave(file.path(output_dir, "0_20_soc_MAT_sensitivity_FT_ET_MT_1.png"), p3, width = 5, height = 5, dpi = 600)

p1_all <- cowplot::plot_grid(
  p0, p1, p2, p3,
  ncol = 4,
  align = "h",
  axis = "tb")
print(p1_all)
ggsave(file.path(output_dir, "0_20_soc_MAT_sensitivity_1.png"), p1_all, width = 20, height = 5, dpi = 600)

p2_all <- cowplot::plot_grid(
  p0, p1, p2, p3,
  ncol = 2,
  align = "h",
  axis = "tb")
print(p2_all)
ggsave(file.path(output_dir, "20_40_soc_MAT_sensitivity_0428.png"), p2_all, width = 10, height = 10, dpi = 600)