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
library(sf)
library(rnaturalearth)
library(rnaturalearthdata)
# Northeast China sampling site distribution map ----------------------------------------------------
library(ggplot2)
library(sf)

china_pro <- sf::st_read(file.path(data_dir, "china_provinces.json"))
map <- ggplot(data = china_pro) + 
  geom_sf(
    color = "grey",
    fill  = "white",
    size  = 0.8
  ) + 
  coord_sf(
    xlim = c(115, 137),
    ylim = c(37, 55),
    expand = FALSE
  )

df <- read.csv(file.path(data_dir, "dca.csv"))

# Color mapping (Ecosystem)
border_colors <- c(
  "Wetland"   = "#2F7F4F",
  "Forest"    = "#B6B86A",
  "Grassland" = "#2AA6A1"
)
fill_colors <- alpha(border_colors, 0.25)

p1 <- map +
  geom_point(
    data = df,
    aes(
      x = long,
      y = lat,
      colour = Ecosystem,
      fill   = Ecosystem,
      size   = Datasize,
      shape  = Type
    ),
    stroke = 1.1
  ) +
  
  ylab("Latitude") +
  xlab("Longitude") +
  
  scale_color_manual(values = border_colors) +
  scale_fill_manual(values = fill_colors) +
  
  # Abbreviate the "Seasonal frozen ground" label to "SFG"
  scale_shape_manual(
    values = c("Permafrost" = 22, "Seasonal frozen ground" = 21),
    labels = c("Permafrost" = "Permafrost", "Seasonal frozen ground" = "SFG")
  ) +
  scale_size_continuous(range = c(4, 10)) +
  
  theme(
    panel.border = element_rect(fill = NA, color = "black", linewidth = 0.8),
    panel.background = element_rect(fill = "grey95", color = NA),
    panel.grid = element_blank(),
    axis.text  = element_text(size = 20, color = "black"),
    axis.title = element_text(size = 22, color = "black"),
    
    legend.title = element_blank(),
    legend.key.size = unit(20, "pt"),
    legend.text = element_text(size = 18),
    
    legend.background = element_rect(fill = "transparent", colour = NA),
    legend.key = element_rect(fill = "transparent", colour = NA),
    
    # Legend position adjustment:
    # Move the entire legend box toward the bottom-right (x=0.9, y=0.35) to avoid the main map outline
    legend.position = c(0.9, 0.1), 
    legend.justification = c(1, 0), # anchor point set to bottom-right
    legend.box = "vertical",
    legend.box.just = "right",      # right-align within the legend box
    
    # Increase spacing to push the frozen-type legend upward
    legend.spacing.y = unit(10, "cm"), 
    
    # Fine-tune the outer margin of the legend box to avoid being too close to the edge
    legend.margin = margin(t = 0, r = 10, b = 10, l = 0, unit = "pt")
  ) +
  
  guides(
    shape = guide_legend(
      order = 1,
      override.aes = list(size = 5, color = "black", fill = "transparent") 
    ),
    
    color = guide_legend(
      order = 2,
      override.aes = list(shape = 21, size = 5)
    ),
    fill = guide_legend(
      order = 2,
      override.aes = list(shape = 21, size = 5)
    ),
    
    size = "none"
  )

p1

# Save figure
ggsave(file.path(output_dir, "map_0427.png"), plot = p1, width = 6, height = 6, units = 'in', dpi = 600)