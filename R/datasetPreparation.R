datasetPreparation <- function(dataset_list, target_gva, sampling_size_m2) {
  
  pattern <- paste(target_gva, collapse = "|")
  
  processed_list <- lapply(seq_along(dataset_list), function(X) {
    
    df <- dataset_list[[X]]
    
    # ---------------------------
    # 1. Quadrat-level filtering + aggregation
    # ---------------------------
    
    df$keep <- grepl(pattern, df$gva, ignore.case = TRUE)
    
    df <- df %>%
      dplyr::group_by(plotID, quadID) %>%
      dplyr::summarise(
        gva = "target_gva",
        measure_quad = sum(measure_quad[keep], na.rm = TRUE),
        latitude = dplyr::first(latitude),
        longitude = dplyr::first(longitude),
        sample_date = dplyr::first(sample_date),
        .groups = "drop"
      )
    
    df$measure_quad[is.na(df$measure_quad)] <- 0
    
    # ---------------------------
    # 2. Sampling size (explicit, per dataset)
    # ---------------------------
    
    sampling_size_m2 <- sampling_size_m2[X]
    
    df <- df %>%
      dplyr::mutate(
        sampling_size_ha = sampling_size_m2 / 10000
      )
    
    # ---------------------------
    # 3. Plot-level aggregation
    # ---------------------------
    
    df <- df %>%
      dplyr::group_by(plotID) %>%
      dplyr::mutate(
        measure_plot = mean(measure_quad, na.rm = TRUE)
      ) %>%
      dplyr::ungroup()
    
    return(df)
  })
  
  return(processed_list)
}
