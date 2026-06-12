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

# Nonlinear quadratic fit
c("#D57B70", "#074166")
library(ggplot2)
library(dplyr)
library(ggpubr)
library(ggpmisc)
library(scales)
library(cowplot) # combine plots
library(emmeans)    # used for slope comparison
options(max.print=1000000) 
#stock_frozen
dat<-read.csv(file.path(data_dir, "mtc_stock_upland.csv"), header = T)
dat
newdat<-na.omit(dat) # remove missing values
newdat
#theme(legend.position = c(0.25,0.23)
## Plotting and statistical tests
newdat$Type <- factor(newdat$Type,levels = c('Permafrost','Seasonal frozen ground'))
# Fit the quadratic model
quad_model <- lm(log_stock ~ poly(MTC, 2), data = newdat)
# Fit the linear model
# quad_model <- lm(log_stock ~ MTC, data = newdat)
# Extract R^2 and p-value
summary_model <- summary(quad_model)
r_squared <- round(summary_model$r.squared, 2)
p_value <- signif(anova(quad_model)$`Pr(>F)`[1], 3)

# Identify the range over which the frozen-ground type transitions
# Set sliding-window parameters
x_min <- min(newdat$MTC)
x_max <- max(newdat$MTC)
window_size <- (x_max-x_min)/30  # window size
window_size
step_size <- window_size/5 # step size
step_size

# Initialize the results data frame
transition_resulMTC <- data.frame(
  start = numeric(),
  end = numeric(),
  Permafrost_freq = numeric(),
  Seasonal_freq = numeric()
)
# Compute frequencies using the sliding window
for (start in seq(x_min, x_max - window_size, by = step_size)) {
  end <- start + window_size
  # Filter data within the window
  window_data <- newdat %>% filter(MTC >= start & MTC < end)
  # Compute frequencies
  total_count <- nrow(window_data)  # total number of observations in the window
  freq_table <- table(window_data$Type)
  Permafrost_freq <- ifelse("Permafrost" %in% names(freq_table), freq_table["Permafrost"] / total_count, 0)
  Seasonal_freq <- ifelse("Seasonal frozen ground" %in% names(freq_table), freq_table["Seasonal frozen ground"] / total_count, 0)
  # Append results
  transition_resulMTC <- rbind(transition_resulMTC, data.frame(
    start = start,
    end = end,
    Permafrost_freq = Permafrost_freq,
    Seasonal_freq = Seasonal_freq
  ))
}
# Identify the transition point
transition_resulMTC <- transition_resulMTC %>%
  mutate(freq_diff = abs(Permafrost_freq - Seasonal_freq))  # compute the frequency difference
transition_resulMTC

# -----------------------------------------------
# Additional step: directly compare SOC ~ MTC slopes by frozen-ground type
# Build a model with an interaction term
type_model <- lm(log_stock ~ MTC * Type, data = newdat)

# Use emtrends() to extract MTC slopes for each type
emtrends_result <- emtrends(type_model, specs = "Type", var = "MTC")
emtrends_result
# Compare the slopes between the two groups
emtrends_diff <- contrast(emtrends_result, method = "pairwise")
emtrends_diff
# Extract slopes and p-values for each group
emtrends_result <- as.data.frame(emtrends_result)
emtrends_result
emtrends_diff <- as.data.frame(emtrends_diff)
emtrends_diff
permafrost_slope <- emtrends_result$MTC.trend[emtrends_result$Type == "Permafrost"]
seasonal_slope   <- emtrends_result$MTC.trend[emtrends_result$Type == "Seasonal frozen ground"]
p_val <- emtrends_diff$p.value[1]  # p-value for the comparison between the two groups
p_val

annotation_text <- paste0("p = ", round(p_val, 2))

# ggplot visualization
p1<-ggplot(newdat, aes(MTC, log_stock, color = Type)) +
  geom_point(aes(color = Type), size = 3, alpha = 0.6,shape = 16, stroke = 1.3) +
  geom_smooth(method = 'lm', formula = y ~ x, se = FALSE, size = 0.8, aes(linetype = Type)) +
  annotate("rect", xmin = -19.9373, xmax = -19.1663,
           ymin = -Inf, ymax = Inf, alpha = 0.15, fill = "#074166") +  # highlight the transition interval
  scale_color_manual(values = c("#D57B70", "#074166")) +
  scale_linetype_manual(values = c("solid", "dashed")) +
  stat_poly_eq(data = newdat, use_label(c("R2", "p.value.label")),
               label.x = 0.05,
               label.y = "bottom",
               size = 5.5) +
  ylab(bquote(SOC(kg/m^2))) + 
  xlab("") +
  theme_classic() +
  theme(legend.title = element_blank()) +
  theme(legend.position = "none", 
        legend.text = element_text(size = 14),
        legend.background = element_rect(fill = "transparent", color = NA)) +
  guides(color = guide_legend(override.aes = list(size = 4))) +
  theme(axis.text = element_text(size = 18, color = "black")) +
  theme(axis.title = element_text(size = 20, color = "black")) +
  theme(panel.border = element_rect(fill = NA, color = "black", linetype = 1, linewidth = 0.5))+
  scale_y_continuous(labels = label_number(accuracy = 0.1))+   # display y-axis with 1 decimal place
  scale_x_continuous(labels = label_number(accuracy = 1)) +
  # Add slope and p-value annotation (position can be adjusted based on data range)
  annotate("text", x = max(newdat$MTC) - 5, y = max(newdat$log_stock), 
           label = annotation_text, hjust = 0, size = 5, color = "black")
p1

p2<-ggplot(newdat, aes(MTC, log_stock, color = Type)) +
  geom_point(aes(color = Type), size = 3, alpha = 0.6,shape = 1, stroke = 1.3) +
  geom_smooth(method = 'lm', formula = y ~ x, se = FALSE, size = 0.8, aes(linetype = Type)) +
  annotate("rect", xmin = -22.44891, xmax = -20.57135,
           ymin = -Inf, ymax = Inf, alpha = 0.15, fill = "#074166") +  # highlight the transition interval
  scale_color_manual(values = c("#D57B70", "#074166")) +
  scale_linetype_manual(values = c("dashed", "solid")) +
  stat_poly_eq(data = newdat, use_label(c("R2", "p.value.label")),
               label.x = 0.05,
               label.y = "bottom",
               size = 6) +
  ylab(bquote(SOC(kg/m^2))) + 
  xlab("Mean temperature of coldest quarter(°C)") +
  theme_classic() +
  theme(legend.title = element_blank()) +
  theme(legend.position = "none", 
        legend.text = element_text(size = 14),
        legend.background = element_rect(fill = "transparent", color = NA)) +
  guides(color = guide_legend(override.aes = list(size = 4))) +
  theme(axis.text = element_text(size = 18, color = "black")) +
  theme(axis.title = element_text(size = 20, color = "black")) +
  theme(panel.border = element_rect(fill = NA, color = "black", linetype = 1, linewidth = 0.5))+
  scale_y_continuous(labels = label_number(accuracy = 0.1))+   # display y-axis with 1 decimal place
  scale_x_continuous(labels = label_number(accuracy = 1))+
  # Add slope and p-value annotation (position can be adjusted based on data range)
  annotate("text", x = max(newdat$MTC) - 5, y = max(newdat$log_stock), 
           label = annotation_text, hjust = 0, size = 5, color = "black")
p2

final_plot <- plot_grid(p1, p2, ncol = 1)
final_plot

# ---- Save combined figure (added: final_plot was previously built but
#      not saved to a file in the original script) ----
ggsave(file.path(output_dir, "FigureS3_MTC_threshold.png"), final_plot,
       width = 6, height = 11, dpi = 600)