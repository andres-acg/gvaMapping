#Undisturbed plots
keepUndisturbedPlots <- function(dataset_list, 
                                 disturbances_path, 
                                 land_cover_year, 
                                 output_dir = NULL) {
  
  message("\nKeeping undisturbed plots between field survey and land cover years...")
  
  # --- Create output directory if provided ---
  if (!is.null(output_dir) && !dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # --- Load disturbance shapefile ---
  disturbance_polygons <- terra::vect(disturbances_path)
  
  # --- Handle disturbance date column ---
  if ("REP_DATE" %in% names(disturbance_polygons)) {
    disturbance_polygons$REP_DATE <- as.Date(disturbance_polygons$REP_DATE)
  } else if ("YEAR" %in% names(disturbance_polygons)) {
    disturbance_polygons$REP_DATE <- as.Date(paste0(disturbance_polygons$YEAR, "-07-01"))  # approximate mid-year
  } else {
    stop("❌ Neither 'REP_DATE' nor 'YEAR' column found in disturbance shapefiles.")
  }
  
  # --- Filter each dataset ---
  filtered_list <- lapply(names(dataset_list), function(dataset_name) {
    df <- dataset_list[[dataset_name]]
    
    # Skip datasets missing essential columns
    if (!all(c("plotID", "longitude", "latitude", "sample_date") %in% names(df))) {
      warning(sprintf("⚠️ Skipping dataset '%s' (missing required columns)", dataset_name))
      return(df)
    }
    
    # Ensure numeric coordinates and proper date
    df$longitude <- as.numeric(df$longitude)
    df$latitude <- as.numeric(df$latitude)
    df$sample_date <- as.Date(df$sample_date)
    
    # Convert plots to SpatVector
    points <- terra::vect(df, geom = c("longitude", "latitude"), crs = "EPSG:4326")
    points <- terra::project(points, terra::crs(disturbance_polygons))
    
    # Intersect plots with disturbances
    disturbed <- terra::intersect(points, disturbance_polygons)
    if (nrow(disturbed) == 0) {
      message(sprintf("\n✔ %s: Removed 0 disturbed plots (remaining: %d)", dataset_name, length(unique(df$plotID))))
      return(df)
    }
    
    # Keep only unique plotID for joining sample_date
    unique_sample_dates <- df %>%
      select(plotID, sample_date) %>%
      distinct(plotID, .keep_all = TRUE)
    
    disturbed_df <- as.data.frame(disturbed)[, c("plotID", "REP_DATE")] %>%
      left_join(unique_sample_dates, by = "plotID")
    
    # Identify plots that disturbed between land cover year and sample date
    removed_info <- disturbed_df %>%
      filter(
        !is.na(REP_DATE) &
          (
            (REP_DATE >= as.Date(paste0(land_cover_year, "-01-01")) & REP_DATE <= sample_date) |
              (REP_DATE <= as.Date(paste0(land_cover_year, "-12-31")) & REP_DATE >= sample_date)
          )
      ) %>%
      distinct(plotID, .keep_all = TRUE)
    
    # Remove disturbed plots (keep duplicated rows)
    df_filtered <- df[!df$plotID %in% removed_info$plotID, ]
    
    # Message with removed plots
    if (nrow(removed_info) > 0) {
      removed_msg <- paste(
        apply(removed_info, 1, function(x) paste0(x["plotID"], ": disturbance=", x["REP_DATE"], ", sample=", x["sample_date"])),
        collapse = "\n"
      )
      message(sprintf(
        "✔ %s: Removed %d disturbed plots (remaining: %d).\nRemoved plots info:\n%s",
        dataset_name,
        nrow(removed_info),
        length(unique(df_filtered$plotID)),
        removed_msg
      ))
    } else {
      message(sprintf(
        "✔ %s: Removed 0 disturbed plots (remaining: %d)",
        dataset_name,
        length(unique(df_filtered$plotID))
      ))
    }
    
    
    # 💾 Save filtered dataset
    if (!is.null(output_dir)) {
      output_path <- file.path(output_dir, paste0(dataset_name, "_undisturbed.csv"))
      write.csv(df_filtered, output_path, row.names = FALSE)
      #message(sprintf("💾 Saved: %s", output_path))
    }
    
    return(df_filtered)
  })
  
  names(filtered_list) <- names(dataset_list)
  message("\n✅ Only undisturbed plots kept - dataset_list updated", "\n")
  return(filtered_list)
}