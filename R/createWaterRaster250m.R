createWaterRaster250m <- function(
    land_cover_paths,
    water_classes_list,
    output_dir,
    target_res = 250
) {
  
  stopifnot(
    is.list(land_cover_paths),
    is.list(water_classes_list),
    length(land_cover_paths) == length(water_classes_list)
  )
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  library(terra)
  library(doParallel)
  library(foreach)
  
  # ------------------------------------------------------------
  # First land-cover product defines the grid (PATH ONLY)
  # ------------------------------------------------------------
  template_path <- land_cover_paths[[1]]
  
  if (!file.exists(template_path)) {
    stop("❌ First land-cover raster not found: ", template_path)
  }
  
  # ------------------------------------------------------------
  # Detect environment and set cores
  # ------------------------------------------------------------
  if (nzchar(Sys.getenv("SLURM_JOB_ID"))) {
    ncores <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", unset = 1))
  } else {
    ncores <- max(1, parallel::detectCores() - 1)
  }
  
  cl <- makeCluster(ncores, type = "PSOCK")
  on.exit(stopCluster(cl), add = TRUE)
  registerDoParallel(cl)
  
  # ------------------------------------------------------------
  # STEP 1: ALIGN LAND-COVER RASTERS IN PARALLEL
  # ------------------------------------------------------------
  aligned_paths <- foreach(
    i = seq_along(land_cover_paths),
    .packages = "terra",
    .errorhandling = "stop"
  ) %dopar% {
    
    r_path <- land_cover_paths[[i]]
    out_path <- file.path(output_dir, paste0("aligned_lc_", i, ".tif"))
    
    r <- rast(r_path)
    template <- rast(template_path)
    
    # terra:: qualified deliberately -- see the note on the resample() call in
    # STEP 4 below. Harmless here (this runs in a PSOCK worker that only loads
    # terra), but kept consistent so the hazard isn't reintroduced by copy-paste.
    if (!terra::compareGeom(template, r, stopOnError = FALSE)) {
      r <- terra::resample(r, template, method = "near")
    }
    crs(r) <- crs(template)
    
    writeRaster(r, out_path, overwrite = TRUE)
    out_path
  }
  
  # ------------------------------------------------------------
  # STEP 2: BUILD WATER MASKS (SEQUENTIAL, SAFE)
  # ------------------------------------------------------------
  lc_rasters <- lapply(aligned_paths, rast)
  
  water_masks <- lapply(seq_along(lc_rasters), function(i) {
    
    lc <- lc_rasters[[i]]
    water_classes <- water_classes_list[[i]]
    
    if (!is.atomic(water_classes)) {
      stop("❌ water_classes_list[[", i, "]] is not an atomic vector.")
    }
    
    rcl <- cbind(water_classes, water_classes, 1)
    
    water_mask <- classify(
      lc,
      rcl = rcl,
      others = 0,
      right = NA
    )
    
    water_mask == 1
  })
  
  water_union <- Reduce(`|`, water_masks)
  
  # ------------------------------------------------------------
  # STEP 3: AGGREGATE TO TARGET RESOLUTION (250 m)
  # ------------------------------------------------------------
  template_lc <- lc_rasters[[1]]
  current_res <- res(template_lc)[1]
  fact <- round(target_res / current_res)
  
  if (fact < 1) {
    stop("❌ Target resolution is finer than land-cover resolution.")
  }
  
  water_agg <- aggregate(
    water_union,
    fact = fact,
    fun = max,
    na.rm = TRUE
  )
  
  # ------------------------------------------------------------
  # STEP 4: FORCE FINAL ALIGNMENT TO 250 m TEMPLATE
  # ------------------------------------------------------------
  template_250m <- aggregate(
    template_lc,
    fact = fact,
    fun = mean,
    na.rm = TRUE
  )
  
  # MUST be terra::resample, not bare resample(). This runs in the main R
  # session, where R.utils is attached AFTER terra and masks terra's resample
  # with its own resample(x, size, ...) -- a sample() helper. The bare call then
  # became sample.int(length(x), template_250m, method = "near"), which failed
  # with 'unused argument (method = "near")' reported against `[`.
  water_250m <- terra::resample(
    water_agg,
    template_250m,
    method = "near"
  )
  crs(water_250m) <- crs(template_250m)
  
  # ------------------------------------------------------------
  # SAVE RESULT
  # ------------------------------------------------------------
  out_path <- file.path(output_dir, "water_mask_250m.tif")
  
  writeRaster(
    water_250m,
    out_path,
    overwrite = TRUE,
    wopt = list(gdal = c("COMPRESS=DEFLATE", "TILED=YES"))
  )
  
  return(out_path)
}
