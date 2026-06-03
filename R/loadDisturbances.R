loadDisturbances <- function(path_or_url) {
  
  input_dir <- getOption("spades.inputPath")
  dist_dir <- file.path(input_dir, "disturbances")
  
  # ✅ ensure folder exists
  dir.create(dist_dir, recursive = TRUE, showWarnings = FALSE)
  
  # ----------------------------------------------------------
  # Step 0 — Handle NA (optional)
  # ----------------------------------------------------------
  if (is.null(path_or_url) || is.na(path_or_url)) {
    return(NA)
  }
  
  # ----------------------------------------------------------
  # Step 1 — Check if URL
  # ----------------------------------------------------------
  is_url <- grepl("^https?://", path_or_url)
  
  # ----------------------------------------------------------
  # Step 2 — Local file
  # ----------------------------------------------------------
  if (!is_url) {
    
    if (!file.exists(path_or_url)) {
      stop("❌ Disturbance file does not exist: ", path_or_url)
    }
    
    if (tolower(tools::file_ext(path_or_url)) == "shp") {
      return(normalizePath(path_or_url))
    }
    
    stop("❌ Local disturbance file must be a .shp")
  }
  
  # ----------------------------------------------------------
  # Step 3 — Clean filename (fix ?download=1)
  # ----------------------------------------------------------
  clean_name <- basename(sub("\\?.*$", "", path_or_url))
  
  if (!grepl("\\.", clean_name)) {
    clean_name <- paste0(clean_name, ".zip")
  }
  
  local_file <- file.path(dist_dir, clean_name)
  
  # ----------------------------------------------------------
  # Step 4 — Download ONLY if needed (✅ caching)
  # ----------------------------------------------------------
  if (!file.exists(local_file)) {
    
    message("Downloading disturbance: ", clean_name)
    
    downloaded_path <- reproducible::prepInputs(
      url = path_or_url,
      destinationPath = dist_dir,
      targetFile = clean_name,
      fun = NA,
      overwrite = FALSE
    )
    
  } else {
    
    message("Using cached disturbance: ", local_file)
    downloaded_path <- local_file
  }
  
  # ----------------------------------------------------------
  # Step 5 — If ZIP → find shapefile INSIDE disturbances folder
  # ----------------------------------------------------------
  if (tolower(tools::file_ext(downloaded_path)) == "zip") {
    
    files <- list.files(
      path = dist_dir,              # ✅ restricted search (important!)
      recursive = TRUE,
      full.names = TRUE
    )
    
    shp_files <- grep("\\.shp$", files, value = TRUE)
    
    if (length(shp_files) == 0) {
      stop("❌ No shapefile found in disturbance archive.")
    }
    
    if (length(shp_files) > 1) {
      warning("⚠ Multiple shapefiles found. Returning the first.")
    }
    
    return(shp_files[1])
  }
  
  # ----------------------------------------------------------
  # Step 6 — Direct shapefile
  # ----------------------------------------------------------
  if (tolower(tools::file_ext(downloaded_path)) == "shp") {
    return(downloaded_path)
  }
  
  # ----------------------------------------------------------
  # Step 7 — Unsupported format
  # ----------------------------------------------------------
  stop("❌ Unsupported disturbance format.")
}