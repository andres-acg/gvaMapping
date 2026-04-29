# Function to convert cropped land cover rasters to gva rasters
convertCroppedLandCoverToGVAMap <- function(output_dir_in,
                                            output_dir_out,
                                            weighted_mean_results,
                                            inapplicable_classes_list,
                                            list_of_land_cover_names) {
  
  
  # --- List and order rasters by land_coverX number ---
  raster_paths <- list.files(output_dir_in, pattern = "\\.tif$", full.names = TRUE)
  land_cover_index <- as.numeric(sub(".*land_cover(\\d+)_.*", "\\1", basename(raster_paths)))
  raster_paths <- raster_paths[order(land_cover_index)]
  
  # --- Create output directory if missing ---
  if (!dir.exists(output_dir_out)) dir.create(output_dir_out, recursive = TRUE)
  
  gva_raster_list <- list()
  
  for (i in seq_along(raster_paths)) {
    cat("    Converting land cover to GVA raster for", list_of_land_cover_names[[i]], "...\n")
    flush.console()
    
    current_raster <- terra::rast(raster_paths[[i]])
    gva_df <- weighted_mean_results[[i]]
    
    # Keep only non-NA land cover classes
    gva_df <- gva_df[!is.na(gva_df$land_cover_class), ]
    
    # Exclude inapplicable classes safely
    if (!is.null(inapplicable_classes_list) && length(inapplicable_classes_list) >= i && !all(is.na(inapplicable_classes_list[[i]]))) {
      gva_df <- gva_df[!gva_df$land_cover_class %in% inapplicable_classes_list[[i]], ]
    }
    
    
    # Reclassify land cover → gva (use your updated variable name)
    reclass_mat <- as.matrix(gva_df[, c("land_cover_class", "wtd_mean")])
    gva_raster <- classify(current_raster, rcl = reclass_mat, others = NA)
    
    # Assign name and save raster
    raster_name <- list_of_land_cover_names[[i]]
    names(gva_raster) <- raster_name
    
    # Assign name and save raster
    raster_name <- list_of_land_cover_names[[i]]
    names(gva_raster) <- raster_name
    
    # Include land cover index in filename
    output_path <- file.path(output_dir_out, 
                             paste0("gva_land_cover", i, "_", raster_name, ".tif"))
    writeRaster(gva_raster, output_path, overwrite = TRUE)
    
    gva_raster_list[[raster_name]] <- gva_raster
  }
  
  message("\n✅ Mean GVA raster(s) created", "\n")
  return(gva_raster_list)
}