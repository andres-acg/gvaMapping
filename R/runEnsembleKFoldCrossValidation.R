#smape ensemble raster
smapeEnsembleRaster <- function(
    output_dir_in,
    output_dir_out,
    hold_out_dataset,
    lon_col = "longitude",
    lat_col = "latitude",
    obs_col = "measure_plot",
    id_col = "plotID"
) {
  cat("     Calculating SMAPE for ensemble raster from folder:", output_dir_in, "...\n")
  flush.console()
  
  # --- Find raster file in folder ---
  raster_files <- list.files(output_dir_in, pattern = "\\.tif$", full.names = TRUE)
  if (length(raster_files) == 0) {
    stop("No raster file found in folder: ", output_dir_in)
  } else if (length(raster_files) > 1) {
    warning("Multiple raster files found. Using the first one: ", basename(raster_files[1]))
  }
  
  # --- Load raster ---
  raster <- terra::rast(raster_files[1])
  raster_name <- tools::file_path_sans_ext(basename(raster_files[1]))
  
  # --- Keep only unique plots ---
  hold_out_dataset <- hold_out_dataset[!duplicated(hold_out_dataset[[id_col]]), ]
  
  # --- Convert to SpatVector ---
  plot_points <- terra::vect(hold_out_dataset, geom = c(lon_col, lat_col), crs = "EPSG:4326")
  
  # --- Project points to raster CRS ---
  points_proj <- terra::project(plot_points, crs(raster))
  
  # --- Extract predicted values ---
  predicted <- terra::extract(raster, points_proj)[, 2]
  observed <- hold_out_dataset[[obs_col]]
  
  # --- Keep only complete cases ---
  valid <- complete.cases(predicted, observed)
  predicted <- predicted[valid]
  observed <- observed[valid]
  
  # --- Compute R² ---
  if (length(observed) < 2) {
    SMAPE <- NA  # NEW
  } else {
    
    # --- SMAPE (metrica, robust handling) ---
    
    # Identify (0,0) cases
    both_zero <- observed == 0 & predicted == 0
    
    observed2  <- observed
    predicted2 <- predicted
    
    # Treat (0,0) as perfect prediction → zero error
    observed2[both_zero]  <- 1
    predicted2[both_zero] <- 1
    
    # Compute SMAPE (%) – bounded 0–200
    SMAPE <- metrica::SMAPE(
      obs   = observed2,
      pred  = predicted2,
      na.rm = TRUE
    )$SMAPE
  }
  
  # --- Ensure output folder exists ---
  if (!dir.exists(output_dir_out)) {
    dir.create(output_dir_out, recursive = TRUE)
  }
  
  # --- Save SMAPE to CSV ---
  output_file <- file.path(output_dir_out, paste0("smape_", raster_name, ".csv"))
  
  write.csv(data.frame(Raster = raster_name, SMAPE = SMAPE), output_file, row.names = FALSE)
  
  cat("\n✅ SMAPE for ensemble raster saved to:", output_file, "\n")  
  
  return(list(SMAPE = SMAPE))  # NEW
}



runEnsembleKFoldCrossValidation <- function(dataset_list,
                                            n_folds = 10,
                                            holdout_ratio = 0.3,
                                            seed = seed,
                                            output_dir_in,
                                            output_dir_out) {
  # --- Combine datasets and remove duplicate plots ---
  combined_df <- do.call(rbind, dataset_list)
  combined_df <- combined_df[!duplicated(combined_df$plotID), ]
  combined_df <- combined_df[order(combined_df$plotID), ]
  # --- Transform coordinates to UTM ---
  coords_sf <- sf::st_as_sf(combined_df, coords = c("longitude", "latitude"), crs = 4326)
  coords_sf_utm <- sf::st_transform(coords_sf, crs = 32611)
  coords_matrix <- sf::st_coordinates(coords_sf_utm)
  combined_df$easting <- coords_matrix[,1]
  combined_df$northing <- coords_matrix[,2]
  
  # --- Initialize storage for fold R² ---
  fold_ensemble_SMAPE <- numeric(n_folds)
  
  for (fold in seq_len(n_folds)) {
    cat("     Ensemble fold", fold, "...\n")
    
    set.seed(seed + fold)
    
    # Create holdout indices
    N <- nrow(combined_df)
    h <- round(holdout_ratio * N)
    prob_holdout <- rep(h / N, N)
    X <- cbind(combined_df$easting, combined_df$northing)
    units_holdout <- lpm1(prob_holdout, X)
    
    hold_out_dataset <- combined_df[units_holdout, ]
    
    fold_results <- smapeEnsembleRaster(
      output_dir_in  = output_dir_in,
      output_dir_out = output_dir_out,
      hold_out_dataset = hold_out_dataset
    )
    
    fold_ensemble_SMAPE[fold] <- fold_results$SMAPE  
    
    cat("     Ensemble fold", fold, "SMAPE =", round(fold_ensemble_SMAPE[fold],3), "\n")
    flush.console()
  }
  
  # --- Compute mean SMAPE across folds ---
  mean_ensemble_SMAPE <- mean(fold_ensemble_SMAPE, na.rm = TRUE)
  cat("Mean ensemble SMAPE across folds:", round(mean_ensemble_SMAPE,3), "\n") 
  
  
  # --- Save results ---
  if (!is.null(output_dir_out)) {
    if (!dir.exists(output_dir_out)) dir.create(output_dir_out, recursive = TRUE)
    
    # Save per-fold SMAPE
    fold_smape_path <- file.path(output_dir_out, "ensemble_smape_per_fold.csv")
    write.csv(
      data.frame(fold = seq_len(n_folds), SMAPE = fold_ensemble_SMAPE),
      fold_smape_path,
      row.names = FALSE
    )
    
    # Save averaged SMAPE
    avg_smape_path <- file.path(output_dir_out, "ensemble_smape_averaged.csv")
    write.csv(
      data.frame(mean_SMAPE = mean_ensemble_SMAPE),
      avg_smape_path,
      row.names = FALSE
    )
    
    message("\n[SMAPE results saved]")
    message("  Per-fold: ", fold_smape_path)
    message("  Averaged: ", avg_smape_path)
    
    
  }
  
  
  # --- Return averaged SMAPE ---
  return(list(
    SMAPE = mean_ensemble_SMAPE
  ))
  
}
