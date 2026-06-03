loadDatasets <- function(dataset_list) {
  
  input_dir <- getOption("spades.inputPath")
  datasets_root <- file.path(input_dir, "datasets")
  
  dir.create(datasets_root, recursive = TRUE, showWarnings = FALSE)
  
  result <- lapply(names(dataset_list), function(name) {
    
    x <- dataset_list[[name]]
    
    # ----------------------------------------------------------
    # Step 0 — Create dataset-specific folder
    # ----------------------------------------------------------
    ds_dir <- file.path(datasets_root, name)
    dir.create(ds_dir, recursive = TRUE, showWarnings = FALSE)
    
    # ----------------------------------------------------------
    # Step 1 — Check if URL
    # ----------------------------------------------------------
    is_url <- grepl("^https?://", x)
    
    # ----------------------------------------------------------
    # Step 2 — Local file
    # ----------------------------------------------------------
    if (!is_url) {
      
      if (!file.exists(x)) {
        stop("❌ Dataset does not exist: ", x)
      }
      
      file_to_read <- x
      
    } else {
      
      # ----------------------------------------------------------
      # Step 3 — Clean filename
      # ----------------------------------------------------------
      clean_name <- basename(sub("\\?.*$", "", x))
      
      if (!grepl("\\.", clean_name)) {
        clean_name <- paste0(clean_name, ".csv")
      }
      
      local_file <- file.path(ds_dir, clean_name)
      
      # ----------------------------------------------------------
      # Step 4 — Download only if needed (caching)
      # ----------------------------------------------------------
      if (!file.exists(local_file)) {
        
        message("Downloading dataset: ", clean_name)
        
        file_to_read <- reproducible::prepInputs(
          url = x,
          destinationPath = ds_dir,
          targetFile = clean_name,
          fun = NA,
          overwrite = FALSE
        )
        
      } else {
        
        message("Using cached dataset: ", local_file)
        file_to_read <- local_file
      }
    }
    
    # ----------------------------------------------------------
    # Step 5 — Load dataset
    # ----------------------------------------------------------
    ext <- tolower(tools::file_ext(file_to_read))
    
    if (ext == "csv") {
      return(read.csv(file_to_read))
    }
    
    if (ext %in% c("xlsx", "xls")) {
      return(readxl::read_excel(file_to_read))
    }
    
    # ----------------------------------------------------------
    # Step 6 — ZIP handling
    # ----------------------------------------------------------
    if (ext == "zip") {
      
      files <- list.files(
        path = ds_dir,   # ✅ restricted to dataset folder
        recursive = TRUE,
        full.names = TRUE
      )
      
      csv_files <- grep("\\.csv$", files, value = TRUE)
      if (length(csv_files) > 0) {
        return(read.csv(csv_files[1]))
      }
      
      xls_files <- grep("\\.xlsx?$", files, value = TRUE)
      if (length(xls_files) > 0) {
        return(readxl::read_excel(xls_files[1]))
      }
      
      stop("❌ ZIP contains no supported dataset.")
    }
    
    stop("❌ Unsupported file type: ", ext)
  })
  
  return(result)
}
