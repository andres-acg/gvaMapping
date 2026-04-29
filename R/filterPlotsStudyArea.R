#filter plots within study area
filterPlotsStudyArea <- function(dataset_list, 
                                 study_area_path,
                                 output_dir = NULL) {
  # Load required packages
  library(terra)
  library(purrr)
  
  # Ensure the output directory exists
  if (!is.null(output_dir)) {
    # Handle relative vs absolute paths
    if (!grepl("^(/|[A-Za-z]:)", output_dir)) {
      output_dir <- file.path(getwd(), output_dir)
    }
    if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  }
  
  # --- Flatten one level of nesting ---
  # if (any(sapply(dataset_list, is.list))) {
  #   dataset_list <- purrr::flatten(dataset_list)
  # }
  
  # --- Check study area input ---
  if (!exists("study_area", inherits = FALSE) || is.null(study_area)) {
    if (!is.null(study_area_path) && file.exists(study_area_path)) {
      study_area <- terra::vect(study_area_path)
    } else {
      stop("❌ No study_area object or valid study_area_path provided. Please provide one.")
    }
  }
  
  # --- Filter each dataset ---
  filtered_list <- lapply(seq_along(dataset_list), function(i) {
    df <- dataset_list[[i]]
    if (!is.data.frame(df)) return(NULL)
    
    # Ensure coordinates are numeric
    df$latitude <- as.numeric(df$latitude)
    df$longitude <- as.numeric(df$longitude)
    df <- df[!is.na(df$latitude) & !is.na(df$longitude), ]
    if (nrow(df) == 0) return(NULL)
    
    # Convert to SpatVector and reproject
    points <- terra::vect(df, geom = c("longitude", "latitude"), crs = "EPSG:4326")
    points_proj <- terra::project(points, terra::crs(study_area))
    
    # Intersect with study area
    intersected_points <- terra::intersect(points_proj, study_area)
    if (nrow(intersected_points) == 0) return(NULL)
    
    # Keep only plots inside study area
    plot_ids_inside <- unique(intersected_points$plotID)
    df_filtered <- df[df$plotID %in% plot_ids_inside, ]
    
    # --- Save filtered dataset ---
    output_path <- file.path(output_dir, paste0("dataset_", i, "_within_study_area.csv"))
    write.csv(df_filtered, output_path)
    
    #message(sprintf("✅ Saved filtered dataset %d to: %s", i, output_path))
    
    return(df_filtered)
  })
  
  # --- Clean up list ---
  filtered_list <- Filter(Negate(is.null), filtered_list)
  names(filtered_list) <- paste0("dataset", seq_along(filtered_list))
  
  message("\n✅ Only plots within study area kept - dataset_list updated", "\n")
  return(filtered_list)
}


