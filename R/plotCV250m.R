plotCV250m <- function(
    cv_raster_path,
    study_area_path,
    water_raster_path,
    output_path,
    split_cv = 0.2,
    title = "Coefficient of Variation (CV)",
    palette = c("white", "white", "darkred"),
    width = 10,
    height = 8,
    dpi = 300
) {
  
  
  # ---- Load rasters ----
  cv_r <- terra::rast(cv_raster_path)
  
  water_r <- terra::rast(water_raster_path)
  if (!terra::same.crs(water_r, cv_r)) {
    water_r <- terra::project(water_r, cv_r)
  }
  water_r <- terra::resample(water_r, cv_r, method = "near")
  
  # ---- Study area ----
  study_area <- terra::vect(study_area_path)
  study_area <- terra::project(study_area, cv_r)
  study_area_sf <- sf::st_as_sf(study_area)
  
  # ---- Raster to data frame ----
  cv_df <- as.data.frame(cv_r, xy = TRUE, na.rm = TRUE)
  colnames(cv_df) <- c("x", "y", "CV")
  
  water_df <- as.data.frame(water_r, xy = TRUE, na.rm = FALSE)
  colnames(water_df) <- c("x", "y", "water")
  
  combined_df <- left_join(water_df, cv_df, by = c("x", "y"))
  
  water_only_df <- combined_df %>%
    filter(water == 1 & is.na(CV))
  
  # ---- CV scale parameters ----
  min_cv <- min(cv_df$CV, na.rm = TRUE)
  max_cv <- max(cv_df$CV, na.rm = TRUE)
  
  values_pos <- c(
    0,
    (split_cv - min_cv) / (max_cv - min_cv),
    1
  )
  
  # ---- Extent ----
  x_range <- terra::ext(cv_r)[1:2]
  y_range <- terra::ext(cv_r)[3:4]
  
  # ---- Plot ----
  p <- ggplot() +
    
    # Water mask
    geom_raster(
      data = water_only_df,
      aes(x = x, y = y),
      fill = "#ADD8E6"
    ) +
    
    # CV raster
    geom_raster(
      data = cv_df,
      aes(x = x, y = y, fill = CV)
    ) +
    
    scale_fill_gradientn(
      colors = palette,
      values = values_pos,
      name = "CV"
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
      plot.title = element_text(size = 16, face = "bold"),
      legend.title = element_text(size = 14),
      legend.text = element_text(size = 12),
      legend.key = element_rect(fill = NA, color = NA)
    ) +
    
    annotation_north_arrow(
      location = "tl",
      which_north = "true",
      style = north_arrow_fancy_orienteering()
    ) +
    
    annotation_scale(
      location = "bl",
      width_hint = 0.2
    )
  
  # ---- Save ----
  ggsave(
    filename = output_path,
    plot = p,
    width = width,
    height = height,
    dpi = dpi
  )
  
  invisible(p)
}
