cropLandCoverProduct <- function(
    study_area_path,
    land_cover_paths,
    list_of_land_cover_names,
    output_dir = cropped_lc_dir
) {
  
  cat("Cropping land cover product(s) to study area in parallel...\n")
  flush.console()
  
  # --- Create output directory ---
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  
  library(terra)
  library(doParallel)
  library(foreach)
  
  # --- Detect environment and set cores ---
  if (nzchar(Sys.getenv("SLURM_JOB_ID"))) {
    ncores <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", unset = 1))
    cat(sprintf("  Detected SLURM environment: using %d cores\n", ncores))
  } else {
    ncores <- max(1, parallel::detectCores() - 1)
    cat(sprintf("  Detected local environment: using %d cores\n", ncores))
  }
  flush.console()
  
  # --- Create temporary working directory ---
  workdir <- file.path(tempdir(), "crop_temp")
  dir.create(workdir, showWarnings = FALSE)
  
  # --- Load original study area ---
  study_area <- vect(study_area_path)
  
  # --- Pre-project study area for each land cover raster ---
  cat("  Pre-projecting study areas for each land cover product...\n")
  study_area_files <- vector("character", length(land_cover_paths))
  for (i in seq_along(land_cover_paths)) {
    r <- rast(land_cover_paths[[i]])
    sa_proj <- project(study_area, crs(r))
    sa_file <- file.path(workdir, paste0("study_area_", i, ".gpkg"))
    writeVector(sa_proj, sa_file, overwrite = TRUE)
    study_area_files[i] <- sa_file
  }
  
  # --- Setup parallel cluster ---
  cl <- makeCluster(ncores, type = "PSOCK")
  registerDoParallel(cl)
  
  # --- Worker function ---
  f_crop <- function(raster_path, study_area_file, lc_name, out_index, output_dir) {
    library(terra)
    r <- rast(raster_path)
    sa <- vect(study_area_file)
    
    cropped <- crop(r, sa)
    cropped <- mask(cropped, sa)
    
    outname <- paste0("cropped_land_cover", out_index, "_", lc_name, ".tif")
    outfile <- file.path(output_dir, outname)
    writeRaster(cropped, outfile, overwrite = TRUE)
    return(outfile)
  }
  
  # --- Run crops in parallel ---
  cat("  Running crop operations in parallel...\n")
  flush.console()
  final_files <- foreach(i = seq_along(land_cover_paths), .combine = c) %dopar% {
    f_crop(
      raster_path = land_cover_paths[[i]],
      study_area_file = study_area_files[i],
      lc_name = list_of_land_cover_names[[i]],
      out_index = i,
      output_dir = output_dir
    )
  }
  
  stopCluster(cl)
  
  # --- Load cropped rasters into R ---
  cropped_raster_list <- lapply(final_files, rast)
  names(cropped_raster_list) <- paste0("cropped_land_cover", seq_along(list_of_land_cover_names), "_", list_of_land_cover_names)
  
  message("\n✅ Land cover product(s) successfully cropped to study area", "\n")
  return(cropped_raster_list)
}
