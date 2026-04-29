#extract LCC
extractPlotLCC_from_folder <- function(output_dir_in,       # folder with cropped rasters
                                       dataset_list,
                                       output_dir_out) {  # folder to save CSVs
  
  # --- Create output directory if needed ---
  if (!is.null(output_dir_out) && !dir.exists(output_dir_out)) {
    dir.create(output_dir_out, recursive = TRUE)
  }
  
  # --- List all .tif files in the input folder ---
  raster_files <- list.files(output_dir_in, pattern = "\\.tif$", full.names = TRUE)
  raster_names <- tools::file_path_sans_ext(basename(raster_files))
  
  # --- Loop over datasets ---
  for (j in seq_along(dataset_list)) {
    plot_df <- dataset_list[[j]]
    
    # Create SpatVector for plot coordinates
    points <- terra::vect(plot_df, geom = c("longitude", "latitude"),
                          crs = "+proj=longlat +datum=WGS84")
    
    # --- Loop over rasters ---
    for (i in seq_along(raster_files)) {
      raster <- terra::rast(raster_files[i])
      
      # Reproject points to match raster CRS
      points_proj <- terra::project(points, crs(raster))
      
      # Extract land cover values (second column)
      land_cover_vals <- terra::extract(raster, points_proj)[,2]
      
      # Column name (remove "cropped_" prefix if present)
      col_name <- sub("^cropped_", "", raster_names[i])
      
      # Assign to dataframe
      plot_df[[col_name]] <- land_cover_vals
    }
    
    # Update dataset in the list
    dataset_list[[j]] <- plot_df
    
    # --- Save each dataset individually ---
    dataset_name <- names(dataset_list)[j]
    if (is.null(dataset_name)) dataset_name <- paste0("dataset", j)
    
    if (!is.null(output_dir_out)) {
      output_path <- file.path(output_dir_out, paste0(dataset_name, "_with_lc_classes.csv"))
      write.csv(plot_df, output_path, row.names = FALSE)
    }
  }
  
  message("\n✅ Land cover classes extracted for each plot - dataset_list updated", "\n")
  return(dataset_list)
}