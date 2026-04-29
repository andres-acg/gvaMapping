
plotGVA250m <- function(
    raster_to_plot,
    raster_list_for_scale,
    study_area_path,
    water_raster_path,
    output_path,
    title,
    measure_name,
    unit,
    palette = c("darkblue", "white", "darkred"),
    width = 10,
    height = 8,
    dpi = 300
) {
  
  
  # ---- Load raster to plot ----
  gva_r <- terra::rast(raster_to_plot)
  
  # ---- Load study area ----
  study_area <- terra::vect(study_area_path)
  study_area <- terra::project(study_area, gva_r)
  study_area_sf <- sf::st_as_sf(study_area)
  
  # ---- Convert raster to data frame ----
  gva_df <- as.data.frame(gva_r, xy = TRUE, na.rm = TRUE)
  colnames(gva_df) <- c("x", "y", "value")
  
  # ---- Water mask ----
  water_r <- terra::rast(water_raster_path)
  water_r <- terra::project(water_r, gva_r)
  
  water_df <- as.data.frame(water_r, xy = TRUE, na.rm = FALSE)
  colnames(water_df) <- c("x", "y", "water")
  
  combined_df <- dplyr::left_join(water_df, gva_df, by = c("x", "y"))
  
  water_only_df <- combined_df %>%
    dplyr::filter(water == 1 & is.na(value))
  
  # ---- Compute shared colour scale ----
  raster_stack <- terra::rast(raster_list_for_scale)
  
  min_val <- min(terra::values(raster_stack), na.rm = TRUE)
  max_val <- max(terra::values(raster_stack), na.rm = TRUE)
  breaks <- pretty(c(min_val, max_val))
  
  # ---- Plot extent ----
  x_range <- terra::ext(gva_r)[1:2]
  y_range <- terra::ext(gva_r)[3:4]
  
  # legend
  legend_title <- paste0(measure_name, " (", unit, ")")
  
  # ---- Plot ----
  p <- ggplot() +
    
    # Water pixels
    geom_raster(
      data = water_only_df,
      aes(x = x, y = y),
      fill = "#ADD8E6"
    ) +
    
    # GVA raster
    geom_raster(
      data = gva_df,
      aes(x = x, y = y, fill = value)
    ) +
    
    scale_fill_gradientn(
      colors = colorRampPalette(palette)(100),
      name = legend_title,
      limits = c(min_val, max_val),
      breaks = breaks,
      labels = breaks
    ) +
    
    # Study area outline
    geom_sf(
      data = study_area_sf,
      fill = NA,
      linewidth = 0.2
    ) +
    
    coord_sf(
      xlim = x_range,
      ylim = y_range,
      expand = FALSE
    ) +
    
    labs(
      title = title,
      x = NULL,
      y = NULL
    ) +
    
    theme_minimal() +
    theme(
      panel.background = element_rect(fill = "grey90", color = NA),
      plot.background  = element_rect(fill = "white", color = NA),
      plot.title       = element_text(size = 16, face = "bold"),
      legend.title     = element_text(size = 14),
      legend.text      = element_text(size = 12),
      legend.key.height = unit(1.5, "cm"),
      legend.key.width  = unit(0.5, "cm")
    ) +
    
    annotation_north_arrow(
      location = "tl",
      which_north = "true",
      height = unit(1, "cm"),
      width  = unit(1, "cm"),
      style  = north_arrow_fancy_orienteering()
    ) +
    
    annotation_scale(
      location = "bl",
      width_hint = 0.2
    )
  
  # ---- Save ----
  ggplot2::ggsave(
    filename = output_path,
    plot = p,
    width = width,
    height = height,
    dpi = dpi
  )
  
  invisible(p)
}