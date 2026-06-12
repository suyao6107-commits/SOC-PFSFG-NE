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

# Load required packages
library(tidyverse)
library(cowplot)
# Additional packages for mixed-effects models
library(lmerTest)  # replaces aov; provides p-values for mixed models
library(emmeans)   # used to extract estimated marginal means (EMMs)
library(multcomp)  # provides emmeans-based cld (Compact Letter Display) significance letters

# ==============================================================================
# 0. Global settings: unified color scheme and helper functions
# ==============================================================================
et_colors <- c("Wetland" = "#2F7F4F", "Forest" = "#B6B86A", "Grassland" = "#2AA6A1")
mt_colors <- c("ErM" = "#3A3A3A", "EcM" = "#A02C2C", "AM" = "#E6B86A", "NM" = "#bea6a0")

# Unified dodge parameter: ensures bars of different widths are centered without gaps
pd <- position_dodge(width = 0.8, preserve = "single")

# Helper function: convert p-values to significance stars
get_stars <- function(p) {
  if (is.na(p)) return("")
  if (p < 0.001) return("***")
  if (p < 0.01) return("**")
  if (p < 0.05) return("*")
  return("ns")
}

# Helper function: extract significance letters from a linear mixed-effects model (LMM)
get_lmm_letters <- function(model, test_factor, by_factor) {
  form <- as.formula(paste("~", test_factor, "|", by_factor))
  emm <- emmeans(model, form)
  cld_res <- cld(emm, Letters = letters, adjust = "none", reversed = FALSE)
  
  cld_df <- as.data.frame(cld_res)
  cld_df$.group <- trimws(as.character(cld_df$.group))
  res <- cld_df[, c(test_factor, by_factor, ".group")]
  colnames(res)[3] <- "marker"
  return(res)
}

# ==============================================================================
# 1. stock20_type_eco interaction (Type * Ecosystem)
# ==============================================================================
dat1 <- read.csv(file.path(data_dir, "0-20.csv"), header = TRUE)
dat1$Type <- factor(dat1$Type, levels = c("Permafrost", "Seasonal frozen ground"), labels = c("Permafrost", "SFG"))
dat1$Ecosystem <- factor(dat1$Ecosystem, levels = c("Wetland", "Forest", "Grassland"))
dat1$Species <- as.factor(dat1$Species)

# Fit the mixed-effects model
fit_lmm1 <- lmer(log_stock ~ Type * Ecosystem + (1|Species), data = dat1)
res_anova1 <- anova(fit_lmm1)

lbl1 <- sprintf("Type: %s\nEcosystem: %s\nType × Ecosystem: %s", 
                get_stars(res_anova1$`Pr(>F)`[1]), get_stars(res_anova1$`Pr(>F)`[2]), get_stars(res_anova1$`Pr(>F)`[3]))

# Key step: extract estimated marginal means (EMMs) and combine with significance letters
letters1 <- get_lmm_letters(fit_lmm1, test_factor = "Ecosystem", by_factor = "Type")
emm_df1 <- as.data.frame(emmeans(fit_lmm1, ~ Type * Ecosystem))

plotdata1 <- emm_df1 %>%
  left_join(letters1, by = c("Type", "Ecosystem")) %>%
  mutate(
    Type = factor(Type, levels = c("Permafrost", "SFG")),
    Ecosystem = factor(Ecosystem, levels = c("Wetland", "Forest", "Grassland"))
  )

# Plot 1 (note: y is now emmean; error bars use the model SE)
p1 <- ggplot(plotdata1, aes(x = Type, y = emmean, fill = Ecosystem, color = Ecosystem)) +
  geom_bar(position = pd, width = 0.7, stat = "identity", alpha = 0.7, linewidth = 1) +
  geom_errorbar(aes(ymin = emmean, ymax = emmean + SE), position = pd, width = 0.2, linewidth = 1) +
  geom_text(aes(y = emmean + SE + 0.1, label = marker), size = 6, position = pd, color = "black", show.legend = FALSE) +
  scale_fill_manual(values = et_colors) +
  scale_color_manual(values = et_colors) +
  annotate("text", x = Inf, y = Inf, label = lbl1, hjust = 1.05, vjust = 1.2, size = 5) +
  labs(x = "Frozen type", y = expression("log-transformed SOC (kg m"^-2 * ")")) +
  scale_y_continuous(limits = c(0, 3.0), breaks = seq(0, 3.0, 0.5)) +
  theme_classic() +
  theme(legend.title = element_blank(), legend.position = 'top',
        legend.text = element_text(size = 14),
        axis.text = element_text(size = 14, color = "black"),
        axis.title = element_text(size = 16, color = "black"))
p1
# ==============================================================================
# 2. stock20_type_mycorr interaction (Type * Mycorrhiza)
# ==============================================================================
dat2 <- read.csv(file.path(data_dir, "0-20.csv"), header = TRUE)
dat2$Type <- factor(dat2$Type, levels = c("Permafrost", "Seasonal frozen ground"), labels = c("Permafrost", "SFG"))
dat2$Mycorrhiza <- factor(dat2$Mycorrhiza, levels = c("ErM", "EcM", "AM", "NM"))
dat2$Species <- as.factor(dat2$Species)

fit_lmm2 <- lmer(log_stock ~ Type * Mycorrhiza + (1|Species), data = dat2)
res_anova2 <- anova(fit_lmm2)

lbl2 <- sprintf("Type: %s\nMycorrhiza: %s\nType × Mycorrhiza: %s", 
                get_stars(res_anova2$`Pr(>F)`[1]), get_stars(res_anova2$`Pr(>F)`[2]), get_stars(res_anova2$`Pr(>F)`[3]))

letters2 <- get_lmm_letters(fit_lmm2, test_factor = "Mycorrhiza", by_factor = "Type")
emm_df2 <- as.data.frame(emmeans(fit_lmm2, ~ Type * Mycorrhiza))

plotdata2 <- emm_df2 %>%
  left_join(letters2, by = c("Type", "Mycorrhiza")) %>%
  mutate(
    Type = factor(Type, levels = c("Permafrost", "SFG")),
    Mycorrhiza = factor(Mycorrhiza, levels = c("ErM", "EcM", "AM", "NM"))
  )

p2 <- ggplot(plotdata2, aes(x = Type, y = emmean, fill = Mycorrhiza, color = Mycorrhiza)) +
  geom_bar(position = pd, width = 0.7, stat = "identity", alpha = 0.7, linewidth = 1) +
  geom_errorbar(aes(ymin = emmean, ymax = emmean + SE), position = pd, width = 0.2, linewidth = 1) +
  geom_text(aes(y = emmean + SE + 0.1, label = marker), size = 6, position = pd, color = "black", show.legend = FALSE) +
  scale_fill_manual(values = mt_colors) +
  scale_color_manual(values = mt_colors) +
  annotate("text", x = Inf, y = Inf, label = lbl2, hjust = 1.05, vjust = 1.2, size = 5) +
  labs(x = "Frozen type", y = expression("log-transformed SOC (kg m"^-2 * ")")) +
  scale_y_continuous(limits = c(0, 3.0), breaks = seq(0, 3.0, 0.5)) +
  theme_classic() +
  theme(legend.title = element_blank(), legend.position = 'top',
        legend.text = element_text(size = 14),
        axis.text = element_text(size = 14, color = "black"),
        axis.title = element_text(size = 16, color = "black"))
p2

# ==============================================================================
# 3. stock20_eco_mycorr interaction (Ecosystem * Mycorrhiza)
# ==============================================================================
dat3 <- read.csv(file.path(data_dir, "0-20.csv"), header = TRUE)
dat3$Ecosystem <- factor(dat3$Ecosystem, levels = c("Wetland", "Forest", "Grassland"))
dat3$Mycorrhiza <- factor(dat3$Mycorrhiza, levels = c("ErM", "EcM", "AM", "NM"))
dat3$Species <- as.factor(dat3$Species)

fit_lmm3 <- lmer(log_stock ~ Ecosystem * Mycorrhiza + (1|Species), data = dat3)
res_anova3 <- anova(fit_lmm3)

lbl3 <- sprintf("Ecosystem: %s\nMycorrhiza: %s\nEco × Mycorrhiza: %s", 
                get_stars(res_anova3$`Pr(>F)`[1]), get_stars(res_anova3$`Pr(>F)`[2]), get_stars(res_anova3$`Pr(>F)`[3]))

letters3 <- get_lmm_letters(fit_lmm3, test_factor = "Mycorrhiza", by_factor = "Ecosystem")
emm_df3 <- as.data.frame(emmeans(fit_lmm3, ~ Ecosystem * Mycorrhiza))

plotdata3 <- emm_df3 %>%
  left_join(letters3, by = c("Ecosystem", "Mycorrhiza")) %>%
  mutate(
    Ecosystem = factor(Ecosystem, levels = c("Wetland", "Forest", "Grassland")),
    Mycorrhiza = factor(Mycorrhiza, levels = c("ErM", "EcM", "AM", "NM"))
  )

p3 <- ggplot(plotdata3, aes(x = Ecosystem, y = emmean, fill = Mycorrhiza, color = Mycorrhiza)) +
  geom_bar(position = pd, width = 0.7, stat = "identity", alpha = 0.7, linewidth = 1) +
  geom_errorbar(aes(ymin = emmean, ymax = emmean + SE), position = pd, width = 0.2, linewidth = 1) +
  geom_text(aes(y = emmean + SE + 0.1, label = marker), size = 6, position = pd, color = "black", show.legend = FALSE) +
  scale_fill_manual(values = mt_colors) +
  scale_color_manual(values = mt_colors) +
  annotate("text", x = Inf, y = Inf, label = lbl3, hjust = 1.05, vjust = 1.2, size = 5) +
  labs(x = "Ecosystem type", y = expression("log-transformed SOC (kg m"^-2 * ")")) +
  scale_y_continuous(limits = c(0, 3.0), breaks = seq(0, 3.0, 0.5)) +
  theme_classic() +
  theme(legend.title = element_blank(), legend.position = 'top',
        legend.text = element_text(size = 14),
        axis.text = element_text(size = 14, color = "black"),
        axis.title = element_text(size = 16, color = "black"))
p3

# Combine and save 0-20 cm results
plot_grid_20 <- cowplot::plot_grid(p1, p2, p3, ncol = 3, align = "h")
print(plot_grid_20)
ggsave(file.path(output_dir, "Interaction_Bars_MixedModel_20_0428.png"), plot_grid_20, width = 16, height = 6, dpi = 600)

# ==============================================================================
# 20-40 cm interactions
# ==============================================================================

# ==============================================================================
# 4. stock40_type_eco interaction (Type * Ecosystem)
# ==============================================================================
dat4 <- read.csv(file.path(data_dir, "20-40.csv"), header = TRUE)
dat4$Type <- factor(dat4$Type, levels = c("Permafrost", "Seasonal frozen ground"), labels = c("Permafrost", "SFG"))
dat4$Ecosystem <- factor(dat4$Ecosystem, levels = c("Wetland", "Forest", "Grassland"))
dat4$Species <- as.factor(dat4$Species)

fit_lmm4 <- lmer(log_stock ~ Type * Ecosystem + (1|Species), data = dat4)
res_anova4 <- anova(fit_lmm4)

lbl4 <- sprintf("Type: %s\nEcosystem: %s\nType × Ecosystem: %s", 
                get_stars(res_anova4$`Pr(>F)`[1]), get_stars(res_anova4$`Pr(>F)`[2]), get_stars(res_anova4$`Pr(>F)`[3]))

letters4 <- get_lmm_letters(fit_lmm4, test_factor = "Ecosystem", by_factor = "Type")
emm_df4 <- as.data.frame(emmeans(fit_lmm4, ~ Type * Ecosystem))

plotdata4 <- emm_df4 %>%
  left_join(letters4, by = c("Type", "Ecosystem")) %>%
  mutate(
    Type = factor(Type, levels = c("Permafrost", "SFG")),
    Ecosystem = factor(Ecosystem, levels = c("Wetland", "Forest", "Grassland"))
  )

p4 <- ggplot(plotdata4, aes(x = Type, y = emmean, fill = Ecosystem, color = Ecosystem)) +
  geom_bar(position = pd, width = 0.7, stat = "identity", alpha = 0.7, linewidth = 1) +
  geom_errorbar(aes(ymin = emmean, ymax = emmean + SE), position = pd, width = 0.2, linewidth = 1) +
  geom_text(aes(y = emmean + SE + 0.1, label = marker), size = 6, position = pd, color = "black", show.legend = FALSE) +
  scale_fill_manual(values = et_colors) +
  scale_color_manual(values = et_colors) +
  annotate("text", x = Inf, y = Inf, label = lbl4, hjust = 1.05, vjust = 1.2, size = 5) +
  labs(x = "Frozen type", y = expression("log-transformed SOC (kg m"^-2 * ")")) +
  scale_y_continuous(limits = c(0, 3.0), breaks = seq(0, 3.0, 0.5)) +
  theme_classic() +
  theme(legend.title = element_blank(), legend.position = 'top',
        legend.text = element_text(size = 14),
        axis.text = element_text(size = 14, color = "black"),
        axis.title = element_text(size = 16, color = "black"))
p4

# ==============================================================================
# 5. stock40_type_mycorr interaction (Type * Mycorrhiza)
# ==============================================================================
dat5 <- read.csv(file.path(data_dir, "20-40.csv"), header = TRUE)
dat5$Type <- factor(dat5$Type, levels = c("Permafrost", "Seasonal frozen ground"), labels = c("Permafrost", "SFG"))
dat5$Mycorrhiza <- factor(dat5$Mycorrhiza, levels = c("ErM", "EcM", "AM", "NM"))
dat5$Species <- as.factor(dat5$Species)

fit_lmm5 <- lmer(log_stock ~ Type * Mycorrhiza + (1|Species), data = dat5)
res_anova5 <- anova(fit_lmm5)

lbl5 <- sprintf("Type: %s\nMycorrhiza: %s\nType × Mycorrhiza: %s", 
                get_stars(res_anova5$`Pr(>F)`[1]), get_stars(res_anova5$`Pr(>F)`[2]), get_stars(res_anova5$`Pr(>F)`[3]))

letters5 <- get_lmm_letters(fit_lmm5, test_factor = "Mycorrhiza", by_factor = "Type")
emm_df5 <- as.data.frame(emmeans(fit_lmm5, ~ Type * Mycorrhiza))

plotdata5 <- emm_df5 %>%
  left_join(letters5, by = c("Type", "Mycorrhiza")) %>%
  mutate(
    Type = factor(Type, levels = c("Permafrost", "SFG")),
    Mycorrhiza = factor(Mycorrhiza, levels = c("ErM", "EcM", "AM", "NM"))
  )

p5 <- ggplot(plotdata5, aes(x = Type, y = emmean, fill = Mycorrhiza, color = Mycorrhiza)) +
  geom_bar(position = pd, width = 0.7, stat = "identity", alpha = 0.7, linewidth = 1) +
  geom_errorbar(aes(ymin = emmean, ymax = emmean + SE), position = pd, width = 0.2, linewidth = 1) +
  geom_text(aes(y = emmean + SE + 0.1, label = marker), size = 6, position = pd, color = "black", show.legend = FALSE) +
  scale_fill_manual(values = mt_colors) +
  scale_color_manual(values = mt_colors) +
  annotate("text", x = Inf, y = Inf, label = lbl5, hjust = 1.05, vjust = 1.2, size = 5) +
  labs(x = "Frozen type", y = expression("log-transformed SOC (kg m"^-2 * ")")) +
  scale_y_continuous(limits = c(0, 3.0), breaks = seq(0, 3.0, 0.5)) +
  theme_classic() +
  theme(legend.title = element_blank(), legend.position = 'top',
        legend.text = element_text(size = 14),
        axis.text = element_text(size = 14, color = "black"),
        axis.title = element_text(size = 16, color = "black"))
p5

# ==============================================================================
# 6. stock40_eco_mycorr interaction (Ecosystem * Mycorrhiza)
# ==============================================================================
dat6 <- read.csv(file.path(data_dir, "20-40.csv"), header = TRUE)
dat6$Ecosystem <- factor(dat6$Ecosystem, levels = c("Wetland", "Forest", "Grassland"))
dat6$Mycorrhiza <- factor(dat6$Mycorrhiza, levels = c("ErM", "EcM", "AM", "NM"))
dat6$Species <- as.factor(dat6$Species)

fit_lmm6 <- lmer(log_stock ~ Ecosystem * Mycorrhiza + (1|Species), data = dat6)
res_anova6 <- anova(fit_lmm6)

lbl6 <- sprintf("Ecosystem: %s\nMycorrhiza: %s\nEco × Mycorrhiza: %s", 
                get_stars(res_anova6$`Pr(>F)`[1]), get_stars(res_anova6$`Pr(>F)`[2]), get_stars(res_anova6$`Pr(>F)`[3]))

letters6 <- get_lmm_letters(fit_lmm6, test_factor = "Mycorrhiza", by_factor = "Ecosystem")
emm_df6 <- as.data.frame(emmeans(fit_lmm6, ~ Ecosystem * Mycorrhiza))

plotdata6 <- emm_df6 %>%
  left_join(letters6, by = c("Ecosystem", "Mycorrhiza")) %>%
  mutate(
    Ecosystem = factor(Ecosystem, levels = c("Wetland", "Forest", "Grassland")),
    Mycorrhiza = factor(Mycorrhiza, levels = c("ErM", "EcM", "AM", "NM"))
  )

p6 <- ggplot(plotdata6, aes(x = Ecosystem, y = emmean, fill = Mycorrhiza, color = Mycorrhiza)) +
  geom_bar(position = pd, width = 0.7, stat = "identity", alpha = 0.7, linewidth = 1) +
  geom_errorbar(aes(ymin = emmean, ymax = emmean + SE), position = pd, width = 0.2, linewidth = 1) +
  geom_text(aes(y = emmean + SE + 0.1, label = marker), size = 6, position = pd, color = "black", show.legend = FALSE) +
  scale_fill_manual(values = mt_colors) +
  scale_color_manual(values = mt_colors) +
  annotate("text", x = Inf, y = Inf, label = lbl6, hjust = 1.05, vjust = 1.2, size = 5) +
  labs(x = "Ecosystem type", y = expression("log-transformed SOC (kg m"^-2 * ")")) +
  scale_y_continuous(limits = c(0, 3.0), breaks = seq(0, 3.0, 0.5)) +
  theme_classic() +
  theme(legend.title = element_blank(), legend.position = 'top',
        legend.text = element_text(size = 14),
        axis.text = element_text(size = 14, color = "black"),
        axis.title = element_text(size = 16, color = "black"))
p6

# Combine and save 20-40 cm results
plot_grid_40 <- cowplot::plot_grid(p4, p5, p6, ncol = 3, align = "h")
print(plot_grid_40)
ggsave(file.path(output_dir, "Interaction_Bars_MixedModel_40_0428.png"), plot_grid_40, width = 16, height = 6, dpi = 600)