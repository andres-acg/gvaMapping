convertCroppedLandCoverToGVAMapSparse <- function(output_dir_in,
                                                  output_dir_out,
                                                  gva_df_list,
                                                  dataset_list,
                                                  inapplicable_classes_list = NULL,
                                                  list_of_land_cover_names) {
  

  # --- Step 0: Bind all plots ---
  df_plots <- do.call(rbind, dataset_list)
  df_plots <- df_plots[!duplicated(df_plots$plotID), ]   # keep unique plots
  
  # Check coords exist
  if (!all(c("longitude", "latitude") %in% colnames(df_plots))) {
    stop("dataset_list must contain longitude and latitude columns.")
  }
  
  # Convert to SpatVector in WGS84
  plot_pts <- vect(df_plots, geom = c("longitude", "latitude"), crs = "EPSG:4326")
  
  # --- Step 1: List and order rasters ---
  raster_paths <- list.files(output_dir_in, pattern = "\\.tif$", full.names = TRUE)
  
  land_cover_index <- as.numeric(sub(".*land_cover(\\d+)_.*", "\\1", basename(raster_paths)))
  raster_paths <- raster_paths[order(land_cover_index)]
  
  # --- Step 2: Make sure output folder exists ---
  if (!dir.exists(output_dir_out)) dir.create(output_dir_out, recursive = TRUE)
  
  gva_raster_list <- list()
  
  # --- Step 3: Loop through rasters ---
  for (i in seq_along(raster_paths)) {
    
    raster_name <- list_of_land_cover_names[[i]]
    cat("    Converting land cover to GVA raster (validation version) for:", raster_name, "\n")
    
    current_raster <- rast(raster_paths[[i]])
    
    # Reproject plot points to raster CRS
    plot_pts_r <- project(plot_pts, crs(current_raster))
    
    # Get cell numbers for plot locations
    plot_cells <- cellFromXY(current_raster, geom(plot_pts_r)[, c("x","y")])
    
    # --- Step 4: Prepare gva lookup table ---
    gva_df <- gva_df_list[[i]]
    gva_df <- gva_df[!is.na(gva_df$land_cover_class), ]
    
    # Remove water classes
    if (!is.null(inapplicable_classes_list) && length(inapplicable_classes_list) >= i) {
      gva_df <- gva_df[!gva_df$land_cover_class %in% inapplicable_classes_list[[i]], ]
    }
    
    # Reclassification matrix: LC → GVA
    reclass_mat <- as.matrix(gva_df[, c("land_cover_class", "wtd_mean")])
    
    # --- Step 5: Reclassify raster values to gva ---
    gva_full <- classify(current_raster, rcl = reclass_mat, others = NA)
    
    # --- Step 6: Create sparse raster ---
    sparse_raster <- current_raster
    sparse_raster[] <- NA
    
    # Extract gva predictions only at plot cells
    plot_gva_vals <- gva_full[plot_cells]
    
    # Fill sparse raster
    sparse_raster[plot_cells] <- plot_gva_vals
    
    names(sparse_raster) <- raster_name
    
    # Save sparse raster
    output_path <- file.path(
      output_dir_out,
      paste0("gva_land_cover", i, "_", raster_name, ".tif")
    )
    
    writeRaster(sparse_raster, output_path, overwrite = TRUE)
    gva_raster_list[[raster_name]] <- sparse_raster
  }
  
  message("\n✅ GVA rasters (validation version) created successfully!\n")
  return(gva_raster_list)
}


#smape gva rasters
smapeGVARasters <- function(
    output_dir_in,
    output_dir_out,
    plot_sf,
    training_datasets,
    obs_col = "measure_plot",
    id_col = "plotID"
) {
  # --- Ensure output folder exists ---
  if (!dir.exists(output_dir_out)) {
    dir.create(output_dir_out, recursive = TRUE)
  }
  
  # --- Build land_cover_list automatically ---
  land_cover_cols <- grep("^land_cover\\d+_", names(training_datasets), value = TRUE)
  land_cover_order <- as.numeric(sub("land_cover(\\d+)_.*", "\\1", land_cover_cols))
  land_cover_cols <- land_cover_cols[order(land_cover_order)]
  land_cover_list <- lapply(land_cover_cols, function(col) training_datasets[[col]])
  names(land_cover_list) <- sub(".*_(.*)$", "\\1", land_cover_cols)
  list_of_land_cover_names <- names(land_cover_list)
  
  # --- Load rasters automatically ---
  raster_files <- list.files(output_dir_in, pattern = "\\.tif$", full.names = TRUE)
  if (length(raster_files) == 0) stop("No raster files found in: ", output_dir_in)
  
  raster_list <- lapply(raster_files, terra::rast)
  names(raster_list) <- tools::file_path_sans_ext(basename(raster_files))
  
  # --- Keep only unique plots ---
  plot_sf <- plot_sf[!duplicated(plot_sf[[id_col]]), ]
  
  
  plot_sf <- plot_sf[order(plot_sf[[id_col]]), ]
  training_datasets <- lapply(
    training_datasets,
    function(df) df[order(df[[id_col]]), ]
  )
  
  smape_values <- list()   
  
  # --- Loop over each raster ---
  for (i in seq_along(raster_list)) {
    raster <- raster_list[[i]]
    raster_name <- names(raster_list)[i]
    lc_name <- list_of_land_cover_names[[i]]
    
    # --- Find land cover column dynamically ---
    lc_pattern <- paste0("^land_cover", i, "_", lc_name, "$")
    lc_col_name <- grep(lc_pattern, names(land_cover_list[[i]]), value = TRUE)
    
    if (length(lc_col_name) == 0) {
      warning(paste("No matching land cover column found for", lc_pattern))
      smape_values[[raster_name]] <- NA 
      next
    }
    
    lc_vector <- land_cover_list[[i]][[lc_col_name]]
    
    # --- Define test plots (NA = test) ---
    test_indices <- which(is.na(lc_vector))
    plot_sf_test <- plot_sf[test_indices, ]
    
    cat("        Land cover", lc_name, "testing plots for SMAPE:", nrow(plot_sf_test), "\n")
    
    if (nrow(plot_sf_test) == 0) {
      smape_values[[raster_name]] <- NA  
      next
    }
    
    # --- Reproject points ---
    plot_points <- terra::vect(plot_sf_test, geom = c("longitude", "latitude"), crs = "EPSG:4326")
    points_proj <- terra::project(plot_points, terra::crs(raster))
    
    # --- Extract predictions ---
    predicted <- terra::extract(raster, points_proj)[, 2]
    observed <- plot_sf_test[[obs_col]]
    
    valid <- complete.cases(predicted, observed)
    predicted <- predicted[valid]
    observed <- observed[valid]
    
    # --- Compute SMAPE ---
    if (length(observed) < 2) {
      smape_values[[raster_name]] <- NA 
    } else {
      
      # --- SMAPE ---
      # --- Compute SMAPE using metrica::SMAPE (robust) ---
      
      # Identify (0,0) cases
      both_zero <- observed == 0 & predicted == 0
      
      observed2  <- observed
      predicted2 <- predicted
      
      # Treat (0,0) as perfect match → zero error
      # Any equal non-zero value works
      observed2[both_zero]  <- 1
      predicted2[both_zero] <- 1
      
      # Compute SMAPE (%), bounded 0–200
      SMAPE <- metrica::SMAPE(
        obs   = observed2,
        pred  = predicted2,
        na.rm = TRUE
      )
      
      smape_values[[raster_name]] <- SMAPE
    }
  }
  
  
  results_df  <- data.frame(         
    Raster = names(smape_values),
    SMAPE  = unlist(smape_values)   
  )
  
  output_file <- file.path(output_dir_out, "smape_values.csv")  
  write.csv(results_df, output_file, row.names = FALSE)        
  
  cat("\n✅ SMAPE values saved to:", output_file, "\n") 
  
  # --- Return results ---
  return(list(
    SMAPE = setNames(results_df$SMAPE, results_df$Raster)
    
  ))
  
  
}





#K-fold CV - GVA raster

runGVARastersKFoldCrossValidation <- function(
    dataset_list,
    class_proportions_list,
    list_of_land_cover_names,
    inapplicable_classes_list = NULL,
    seed,
    n_folds,
    min_plots_per_class = 1,
    sample_fraction = 0.7,
    output_dir_fold,
    output_dir_cropped,
    output_dir_out,
    measure_class,
    measure_name,
    unit
    
) {
  message("\n Combining plots and transforming coordinates...")
  
  combined_df <- do.call(rbind, dataset_list)
  combined_df <- combined_df[!duplicated(combined_df$plotID), ]
  
  combined_df <- combined_df[order(combined_df$plotID), ]
  
  coords_sf <- sf::st_as_sf(combined_df, coords = c("longitude", "latitude"), crs = 4326)
  coords_sf_utm <- sf::st_transform(coords_sf, crs = 32611)
  coords_matrix <- sf::st_coordinates(coords_sf_utm)
  combined_df$easting <- coords_matrix[,1]
  combined_df$northing <- coords_matrix[,2]
  
  land_cover_cols <- grep("^land_cover\\d+_", names(combined_df), value = TRUE)
  lc_idx <- as.numeric(sub("^land_cover(\\d+)_.*", "\\1", land_cover_cols))
  land_cover_cols <- land_cover_cols[order(lc_idx)]
  
  cat("First 10 plotIDs entering sampling:\n")
  print(head(combined_df$plotID, 10))
  
  cat("Land-cover column order:\n")
  print(land_cover_cols)
  
  #land_cover_cols <- grep("^land_cover", names(combined_df), value = TRUE)
  
  message("     Variables initialized.")
  
  # Initialize storage for SMAPE results per fold
  fold_product_SMAPE <- matrix(NA, nrow = n_folds, ncol = length(land_cover_cols))
  colnames(fold_product_SMAPE) <- land_cover_cols
  
  # Loop over folds
  for (fold in 1:n_folds) {
    message("\n  Fold: ", fold, " of ", n_folds)
    
    set.seed(seed + fold)
    
    
    message("     Creating training datasets per land cover product...")
    training_datasets <- list()
    remaining_dataset <- combined_df
    coords_train <- cbind(remaining_dataset$easting, remaining_dataset$northing)
    
    for (i in seq_along(land_cover_cols)) {
      lc_col <- land_cover_cols[i]
      lc_values <- remaining_dataset[[lc_col]]
      
      class_sizes <- class_proportions_list[[i]]$pixel_count[
        match(lc_values, class_proportions_list[[i]]$land_cover_class)
      ]
      
      if (!is.null(inapplicable_classes_list) && length(inapplicable_classes_list) >= i)
        class_sizes[lc_values %in% inapplicable_classes_list[[i]]] <- 0
      
      class_counts <- table(lc_values)
      rare_classes <- names(class_counts[class_counts <= min_plots_per_class])
      class_sizes[lc_values %in% rare_classes] <- max(class_sizes, na.rm = TRUE) * 10
      
      n <- round(sample_fraction * nrow(remaining_dataset))
      pi <- inclusionprobabilities(class_sizes, n)
      units_train <- tryCatch(lpm1(pi, coords_train), error = function(e) NULL)
      
      if (is.null(units_train) || sum(units_train) < n) {
        message("     Failed to create training sample for land cover ", i)
        next
      }
      
      df_train <- remaining_dataset
      non_selected <- setdiff(seq_len(nrow(df_train)), units_train)
      df_train[[lc_col]][non_selected] <- NA
      
      training_datasets[[lc_col]] <- df_train
      message("     Training dataset for land cover ", i, " created. n = ", sum(!is.na(df_train[[lc_col]])))
    }
    
    message("     Computing weighted mean gva and rasters...")
    
    combined_training_df <- data.frame(plotID = remaining_dataset$plotID)
    for (i in seq_along(land_cover_cols)) {
      lc_col <- land_cover_cols[i]
      combined_training_df[[lc_col]] <- training_datasets[[lc_col]][[lc_col]]
    }
    combined_training_df$measure_plot <- remaining_dataset$measure_plot
    # combined_training_df$biomass_dens_plot <- remaining_dataset$biomass_dens_plot # change to $measure!!!!!!!!!!!!!!!!!!!
    combined_training_df$sampling_size_ha <- remaining_dataset$sampling_size_ha 
    
    weighted_mean_results_fold <- weightedMeanPerLandCover(
      dataset_list = list(combined_training_df),
      list_of_land_cover_names = list_of_land_cover_names,
      class_proportions_list = class_proportions_list,
      output_dir = output_dir_fold,
      measure_class = measure_class,
      measure_name = measure_name,
      unit = unit
    )
    
    
    weighted_mean_raster_fold <- convertCroppedLandCoverToGVAMapSparse( 
      output_dir_in = output_dir_cropped,
      output_dir_out = output_dir_fold,
      gva_df_list = weighted_mean_results_fold,
      dataset_list = dataset_list,
      inapplicable_classes_list = inapplicable_classes_list,
      list_of_land_cover_names = list_of_land_cover_names
    )
    


    message("     Computing individual SMAPE...")
    
    smape_results_fold <- smapeGVARasters(
      output_dir_in  = output_dir_fold,
      output_dir_out = output_dir_out,
      plot_sf        = remaining_dataset,
      training_datasets = training_datasets,
      obs_col        = "measure_plot", 
      id_col         = "plotID"
    )
    
    fold_product_SMAPE[fold, ] <- smape_results_fold$SMAPE   
    
    message("     Individual SMAPE for fold ", fold, ": ", paste(round(smape_results_fold$SMAPE, 3), collapse = ", ")) 
  }
  
  # Average SMAPE per product across folds
  smape_results <- colMeans(fold_product_SMAPE, na.rm = TRUE)
  message("\n     Averaged SMAPE across folds: ", paste(round(smape_results, 3), collapse = ", "))
  
  # --- Save both per-fold and averaged SMAPE ---
  if (!is.null(output_dir_out)) {
    if (!dir.exists(output_dir_out)) dir.create(output_dir_out, recursive = TRUE)
    
    # Save per-fold SMAPE
    smape_fold_path <- file.path(output_dir_out, "smape_per_fold.csv")
    write.csv(data.frame(fold = seq_len(n_folds), fold_product_SMAPE), smape_fold_path, row.names = FALSE)
    
    # Save averaged SMAPE
    smape_avg_path <- file.path(output_dir_out, "smape_averaged.csv")
    write.csv(data.frame(land_cover = names(smape_results), SMAPE = smape_results), smape_avg_path, row.names = FALSE)
    
  }
  
  message("\n✅ K-fold cross-validation complete for gva raster(s)\n")
  
  return(list(          
    SMAPE = smape_results   
  ))
}
