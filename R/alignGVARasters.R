#gva raster alignment function
alignGVARasters <- function(output_dir_in,
                            study_area_path,
                            output_dir_out,
                            list_of_land_cover_names) {
  # -----------------------------------------------------------------------------
  # Step 1.1: Aligning gva rasters (Compute Canada or local)
  # -----------------------------------------------------------------------------
  cat("     Aligning gva rasters...\n")
  flush.console()
  
  library(terra)
  library(doParallel)
  library(foreach)
  
  # -----------------------------------------------------------------------------
  # Load gva rasters from directory
  # -----------------------------------------------------------------------------
  raster_paths <- list.files(output_dir_in, pattern = "\\.tif$", full.names = TRUE)
  land_cover_index <- as.numeric(sub(".*land_cover(\\d+)_.*", "\\1", basename(raster_paths)))
  raster_paths <- raster_paths[order(land_cover_index)]
  
  if (length(raster_paths) == 0) stop("No .tif rasters found in output_dir_in.")
  
  cat(sprintf("      Found %d gva raster(s) in %s\n", length(raster_paths), output_dir_in))
  flush.console()
  
  gva_rasters <- lapply(raster_paths, rast)
  target_raster <- gva_rasters[[1]]
  
  # -----------------------------------------------------------------------------
  # Load study area
  # -----------------------------------------------------------------------------
  study_area <- vect(study_area_path)
  cat(sprintf("      Loaded study area from: %s\n", study_area_path))
  flush.console()
  
  # -----------------------------------------------------------------------------
  # Create controlled temp directory
  # -----------------------------------------------------------------------------
  workdir <- file.path(tempdir(), "temp_rasters")  # safe temporary dir
  dir.create(workdir, showWarnings = FALSE, recursive = TRUE)
  dir.create(output_dir_out, showWarnings = FALSE, recursive = TRUE)
  
  # -----------------------------------------------------------------------------
  # Save rasters to disk
  # -----------------------------------------------------------------------------
  tmp_files <- sapply(seq_along(gva_rasters), function(i) {
    f <- file.path(workdir, paste0("ras_", i, ".tif"))
    writeRaster(gva_rasters[[i]], f, overwrite = TRUE)
    f
  })
  
  target_file <- file.path(workdir, "target.tif")
  writeRaster(target_raster, target_file, overwrite = TRUE)
  
  # -----------------------------------------------------------------------------
  # Reproject study area once
  # -----------------------------------------------------------------------------
  cat("      Aligning rasters in parallel...\n")
  flush.console()
  study_area_reproj <- project(study_area, crs(target_raster))
  study_area_file <- file.path(workdir, "study_area.gpkg")
  writeVector(study_area_reproj, study_area_file, overwrite = TRUE)
  
  # -----------------------------------------------------------------------------
  # Detect environment (SLURM or local)
  # -----------------------------------------------------------------------------
  if (nzchar(Sys.getenv("SLURM_JOB_ID"))) {
    ncores <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", unset = 1))
    cat(sprintf("      Detected SLURM environment: using %d cores\n", ncores))
  } else {
    ncores <- max(1, parallel::detectCores() - 1)
    cat(sprintf("      Detected local environment: using %d cores\n", ncores))
  }
  flush.console()
  
  cl <- makeCluster(ncores, type = "PSOCK")
  registerDoParallel(cl)
  
  # -----------------------------------------------------------------------------
  # Worker function
  # -----------------------------------------------------------------------------
  f_full <- function(infile, target_file, study_area_file, workdir) {
    library(terra)
    
    r <- rast(infile)
    target <- rast(target_file)
    
    # Project raster to match target
    projected <- project(r, target, method = "near", align = TRUE)
    
    # Crop to target extent
    cropped_target <- crop(projected, target)
    
    # Crop again to study area
    study_area_reproj <- vect(study_area_file)
    final <- crop(cropped_target, study_area_reproj)
    
    # Save properly named temporary file
    outfile <- file.path(workdir, paste0("aligned_temp_", basename(infile)))
    writeRaster(final, outfile, overwrite = TRUE)
    
    return(outfile)
  }
  
  
  # -----------------------------------------------------------------------------
  # Parallel alignment
  # -----------------------------------------------------------------------------
  final_files <- foreach(infile = tmp_files, .combine = c) %dopar% {
    f_full(infile, target_file, study_area_file, workdir)
  }
  
  stopCluster(cl)
  
  # -----------------------------------------------------------------------------
  # Load aligned rasters back into R
  # -----------------------------------------------------------------------------
  aligned_gva_rasters <- lapply(final_files, rast)
  
  # Assign names from list_of_land_cover_names
  for (i in seq_along(aligned_gva_rasters)) {
    names(aligned_gva_rasters[[i]]) <- list_of_land_cover_names[[i]]
  }
  
  names(aligned_gva_rasters) <- list_of_land_cover_names[seq_along(aligned_gva_rasters)]
  
  # -----------------------------------------------------------------------------
  # Save aligned rasters to output_dir_out
  # -----------------------------------------------------------------------------
  # --- Create output directory if provided ---
  if (!is.null(output_dir_out) && !dir.exists(output_dir_out)) {
    dir.create(output_dir_out, recursive = TRUE)
    cat(sprintf("      Created output directory: %s\n", output_dir_out))
  }
  
  aligned_paths <- sapply(seq_along(aligned_gva_rasters), function(i) {
    raster_name <- list_of_land_cover_names[[i]]
    f <- file.path(output_dir_out, paste0("aligned_gva_raster_land_cover", i, "_", raster_name, ".tif"))
    writeRaster(aligned_gva_rasters[[i]], f, overwrite = TRUE)
    f
  })
  
  message("\n✅ Mean GVA raster(s) aligned with each other", "\n")
  flush.console()
  
  return(aligned_gva_rasters)
}