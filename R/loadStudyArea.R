loadStudyArea <- function(path_or_url) {
  
  input_dir <- getOption("spades.inputPath")
  vectors_dir <- file.path(input_dir, "study_area")
  
  # ✅ ensure vectors folder exists
  dir.create(vectors_dir, recursive = TRUE, showWarnings = FALSE)
  
  # ----------------------------------------------------------
  # Step 1 — Check if URL
  # ----------------------------------------------------------
  is_url <- grepl("^https?://", path_or_url)
  
  # ----------------------------------------------------------
  # Step 2 — Local file
  # ----------------------------------------------------------
  if (!is_url) {
    
    if (!file.exists(path_or_url)) {
      stop("❌ Local file does not exist: ", path_or_url)
    }
    
    return(normalizePath(path_or_url))
  }
  
  # ----------------------------------------------------------
  # Step 3 — CLEAN filename (fix ?download=1 issue)
  # ----------------------------------------------------------
  clean_name <- basename(sub("\\?.*$", "", path_or_url))
  
  # If no extension → assume zip
  if (!grepl("\\.", clean_name)) {
    clean_name <- paste0(clean_name, ".zip")
  }
  
  # ----------------------------------------------------------
  # Step 4 — Download into vectors/
  # ----------------------------------------------------------
  downloaded_path <- reproducible::prepInputs(
    url = path_or_url,
    destinationPath = vectors_dir,   # ✅ changed here
    targetFile = clean_name,
    fun = NA,
    overwrite = TRUE
  )
  
  # ----------------------------------------------------------
  # Step 5 — If ZIP → find shapefile
  # ----------------------------------------------------------
  if (tolower(tools::file_ext(downloaded_path)) == "zip") {
    
    files <- list.files(
      path = dirname(downloaded_path),
      recursive = TRUE,
      full.names = TRUE
    )
    
    shp_files <- grep("\\.shp$", files, value = TRUE)
    
    if (length(shp_files) == 0) {
      stop("❌ No shapefile found in archive.")
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
  
  stop("❌ Unsupported study area format (must be .shp or .zip containing .shp).")
}