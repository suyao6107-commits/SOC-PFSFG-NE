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

library(lme4)
library(tidyverse)
library(Matrix)
library(effects)
library(moments)
library(lmerTest) # this package displays p-values
library(ggpubr)
library(sjstats)
# 0-60 cm depth layers - categorical variables only
soc<-read.csv(file.path(data_dir, "0-20_0402.csv"),header = T)
soc<-read.csv(file.path(data_dir, "20-40_0402.csv"),header = T)
soc <- na.omit(soc)
dim(soc)
sapply(lapply(soc, unique), length) # inspect the number of unique levels per variable
lmer <- lmer(log_stock ~ Type+Ecosystem+Mycorrhiza+
               Type:Ecosystem+Type:Mycorrhiza+Ecosystem:Mycorrhiza+
               (1|Species),
             data = soc)
summary(lmer)
anova(lmer, type=3)
ranova(lmer) # likelihood ratio test for the significance of the random effect


shapiro.test(resid(lmer))
ggqqplot(resid(lmer)) # QQ plot
hist(resid(lmer)) # histogram
ggdensity(resid(lmer)) # kernel density plot

# ---------------------------------------------------------------------------------------
# Normality tests
library(ggpubr)
hist(soc$log_stock) # histogram
shapiro.test(soc$pH) # p-value test
skewness(sqrt_F_B) # data skewness
# Normalizing transformation - data is right-skewed
sqrt_dat<-sqrt(soc$pH)
hist(sqrt_dat)
log_dat<-log(soc$soc_stock_60)
hist(log_dat)
dat<-(soc$pH)^(1/3)
hist(dat)

shapiro.test(sqrt_dat)
shapiro.test(log_dat)
shapiro.test(dat)
ggdensity(sqrt_dat)
ggqqplot(sqrt_dat)
# Set the export file path and name
file_path <- file.path(output_dir, "stock60.csv")
write.csv(log_dat, file = file_path, row.names = F)

# 0-40 cm depth layers - all variables
soc<-read.csv(file.path(data_dir, "0-20-all.csv"),header = T)
soc <- na.omit(soc)
dim(soc)
sapply(lapply(soc, unique), length) # inspect the number of unique levels per variable
lmer <- lmer(log_stock ~ Type+Ecosystem+Mycorrhiza+
               Type:Ecosystem+Type:Mycorrhiza+Ecosystem:Mycorrhiza+
               pH+MBC+MBN+MAT+MAP+NDSI+TS+PS+MTW+MTC+MPW+MPC+NDVI+
               (1|Species),
             data = soc)
summary(lmer)
anova(lmer, type=3)
ranova(lmer) # likelihood ratio test for the significance of the random effect


shapiro.test(resid(lmer))
ggqqplot(resid(lmer)) # QQ plot
hist(resid(lmer)) # histogram
ggdensity(resid(lmer)) # kernel density plot

# Normality tests
library(ggpubr)
hist(soc$log_stock) # histogram
shapiro.test(soc$pH) # p-value test
skewness(sqrt_F_B) # data skewness
# Normalizing transformation - data is right-skewed
sqrt_dat<-sqrt(soc$pH)
hist(sqrt_dat)
log_dat<-log(soc$soc_stock_60)
hist(log_dat)
dat<-(soc$pH)^(1/3)
hist(dat)

shapiro.test(sqrt_dat)
shapiro.test(log_dat)
shapiro.test(dat)
ggdensity(sqrt_dat)
ggqqplot(sqrt_dat)
# Set the export file path and name
file_path <- file.path(output_dir, "stock60.csv")
write.csv(log_dat, file = file_path, row.names = F)