#compute class proportions
computeClassProportions <- function(output_dir_in,
                                    output_dir_out,
                                    ncores = NULL) { 
  
  # --- Ensure output directory exists ---
  if (!is.null(output_dir_out) && !dir.exists(output_dir_out)) { 
    dir.create(output_dir_out, recursive = TRUE) 
  }
  
  
  # --- List and order rasters by land_coverX number ---
  raster_paths <- list.files(output_dir_in, pattern = "\\.tif$", full.names = TRUE)
  land_cover_index <- as.numeric(sub(".*land_cover(\\d+)_.*", "\\1", basename(raster_paths)))
  raster_paths <- raster_paths[order(land_cover_index)]
  
  if (is.null(ncores)) {
    if (nzchar(Sys.getenv("SLURM_JOB_ID"))) {
      ncores <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", unset = 1))
    } else {
      ncores <- max(1, parallel::detectCores() - 1)
    }
  }
  cat(sprintf(" Using %d cores for class proportion calculation\n", ncores))
  
  cl <- makeCluster(ncores, type = "PSOCK")
  registerDoParallel(cl)
  
  # --- Parallel loop with .combine='list' ---
  result_list <- foreach(r_path = raster_paths, .packages = c("terra", "dplyr")) %dopar% {
    r <- rast(r_path)
    vals <- values(r)
    vals <- vals[!is.na(vals)]
    total <- length(vals)
    
    pixel_count <- table(factor(vals, levels = sort(unique(vals))))
    
    df <- data.frame(
      land_cover_class = as.numeric(names(pixel_count)),
      pixel_count = as.integer(pixel_count),
      class_proportion_pct = round((as.integer(pixel_count) / total) * 100, 2),
      stringsAsFactors = FALSE
    )
    
    # --- Sort by descending pixel proportion ---
    df <- df %>% arrange(desc(class_proportion_pct))
    df
  }
  
  stopCluster(cl)
  
  # --- Assign names to result_list based on cropped land cover names ---
  names(result_list) <- tools::file_path_sans_ext(basename(raster_paths))
  
  
  # --- Save all results together ---
  saveRDS(result_list, file.path(output_dir_out, "class_proportions.rds"))
  
  # --- Save one CSV per raster ---
  # for (i in seq_along(result_list)) {
  #   raster_name <- tools::file_path_sans_ext(basename(raster_paths[i]))
  #   csv_file <- file.path(output_dir_out, paste0(raster_name, "_class_proportions.csv"))
  #   write.csv(result_list[[i]], csv_file, row.names = FALSE)
  # }
  
  
  # Save CSVs
  for (nm in names(result_list)) {
    write.csv(
      result_list[[nm]],
      file.path(output_dir_out, paste0(nm, "_class_proportions.csv")),
      row.names = FALSE
    )
  }
  
  
  message("\n✅ Land cover class proportions per land cover product computed")
  flush.console()
  
  
  return(result_list)
}