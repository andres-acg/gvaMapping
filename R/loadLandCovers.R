loadLandCovers <- function(land_cover_paths) {
  
  input_dir <- getOption("spades.inputPath")
  lc_root <- file.path(input_dir, "land_cover_products")
  
  dir.create(lc_root, recursive = TRUE, showWarnings = FALSE)
  
  result <- lapply(names(land_cover_paths), function(name) {
    
    path_or_url <- land_cover_paths[[name]]
    
    # ----------------------------------------------------------
    # Step 0 — Handle NA
    # ----------------------------------------------------------
    if (is.null(path_or_url) || is.na(path_or_url)) {
      return(NA)
    }
    
    # ----------------------------------------------------------
    # Step 1 — Create dedicated folder
    # ----------------------------------------------------------
    lc_dir <- file.path(lc_root, name)
    dir.create(lc_dir, recursive = TRUE, showWarnings = FALSE)
    
    # ----------------------------------------------------------
    # Step 2 — Check if URL
    # ----------------------------------------------------------
    is_url <- grepl("^https?://", path_or_url)
    
    # ----------------------------------------------------------
    # Step 3 — Local file
    # ----------------------------------------------------------
    if (!is_url) {
      
      if (!file.exists(path_or_url)) {
        stop("❌ Land cover file does not exist: ", path_or_url)
      }
      
      if (tolower(tools::file_ext(path_or_url)) == "tif") {
        return(normalizePath(path_or_url))
      }
      
      stop("❌ Local land cover must be a .tif file")
    }
    
    # ----------------------------------------------------------
    # Step 4 — Clean filename
    # ----------------------------------------------------------
    clean_name <- basename(sub("\\?.*$", "", path_or_url))
    
    if (!grepl("\\.", clean_name)) {
      clean_name <- paste0(clean_name, ".zip")
    }
    
    local_file <- file.path(lc_dir, clean_name)
    
    # ----------------------------------------------------------
    # Step 5 — Download only if needed
    # ----------------------------------------------------------
    if (!file.exists(local_file)) {
      
      message("Downloading: ", clean_name)
      
      downloaded_path <- reproducible::prepInputs(
        url = path_or_url,
        destinationPath = lc_dir,  # ✅ per-dataset folder
        targetFile = clean_name,
        fun = NA,
        overwrite = FALSE
      )
      
    } else {
      
      message("Using existing file: ", local_file)
      downloaded_path <- local_file
    }
    
    # ----------------------------------------------------------
    # Step 6 — Find rasters ONLY inside this folder
    # ----------------------------------------------------------
    if (tolower(tools::file_ext(downloaded_path)) == "zip") {
      
      tif_files <- list.files(
        path = lc_dir,
        pattern = "\\.tif$",
        recursive = TRUE,
        full.names = TRUE
      )
      
      if (length(tif_files) == 0) {
        stop("❌ No .tif found in ", lc_dir)
      }
      
      return(tif_files)  # ✅ return ALL tif
    }
    
    # ----------------------------------------------------------
    # Step 7 — Direct tif
    # ----------------------------------------------------------
    if (tolower(tools::file_ext(downloaded_path)) == "tif") {
      return(downloaded_path)
    }
    
    stop("❌ Unsupported land cover format.")
  })

  # lapply(names(land_cover_paths), ...) does NOT carry those names onto its
  # result -- lapply only names its output from the names of its INPUT
  # object, and here the input is a plain (unnamed) character vector of
  # names, not land_cover_paths itself. Without this, sim$land_cover_paths$
  # land_cover1 silently becomes unreachable by name after this function runs.
  names(result) <- names(land_cover_paths)

  # output
  return(result)
}