#weighted mean
# weightedMeanPerLandCover <- function(dataset_list,
#                                      list_of_land_cover_names, 
#                                      class_proportions_list,
#                                      output_dir) {
#   
#   # --- Prepare output directory ---
#   if (!is.null(output_dir)) {
#     # Handle relative vs absolute paths
#     if (!grepl("^(/|[A-Za-z]:)", output_dir)) {
#       output_dir <- file.path(getwd(), output_dir)
#     }
#     if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
#   }
#   
#   
#   combined_df <- do.call(rbind, dataset_list)
#   rownames(combined_df) <- NULL
#   land_cover_raster_names <- grep("^land_cover", names(combined_df), value = TRUE)
#   weighted_mean_list <- list()
#   land_cover_name_values <- unlist(list_of_land_cover_names)
#   
#   for (i in seq_along(land_cover_raster_names)) {
#     raster_name <- land_cover_raster_names[i]
#     land_cover_name <- land_cover_name_values[i]
#     
#     land_cover_values <- combined_df[[raster_name]]
#     
#     df <- data.frame(land_cover_class = land_cover_values,
#                      plotID = combined_df$plotID,
#                      biomass_plot = combined_df$biomass_plot, #CHANGE biomass_plot!!!!!!!!!!!!!!!!!!!
#                      biomass_dens_plot = combined_df$biomass_dens_plot, #CHANGE biomass_dens_plot!!!!!!!!!!!!!!!!!!!
#                      sampling_size_ha = combined_df$sampling_size_ha)
#     
#     #plot-level computation
#     df_first_occurrence <- df %>%
#       group_by(plotID) %>%
#       slice(1) %>%
#       ungroup()
#     
#     #total number of unique plots
#     total_samples <- nrow(df_first_occurrence)
#     
#     #weighted mean and summary
#     weighted_mean_df <- df_first_occurrence %>%
#       group_by(land_cover_class) %>%
#       summarise(
#         N = n(),
#         N_pct = round((N / total_samples) * 100, 2),
#         wtd_mean = round(sum(biomass_plot) / sum(sampling_size_ha), 2), #CHANGE biomass_plot!!!!!!!!!!!!!!!!!!!
#         wtd_sd = sqrt(weighted.var(biomass_dens_plot, w = sampling_size_ha, na.rm = TRUE)), #CHANGE biomass_dens_plot!!!!!!!!!!!!!!!!!!!
#         wtd_se = wtd_sd / sqrt(N),
#         wtd_RSE_pct = round((wtd_se / wtd_mean) * 100, 2),
#         CI_lower = round(wtd_mean - 1.96 * wtd_se, 2),
#         CI_upper = round(wtd_mean + 1.96 * wtd_se, 2)
#       ) %>%
#       mutate(land_cover_class = as.numeric(land_cover_class))
#     
#     # Merge with precomputed class proportions for the current raster
#     pixel_count_df <- class_proportions_list[[i]]  # assumed same order/index as cropped_land_covers and land_cover_raster_names
#     
#     weighted_mean_df <- left_join(
#       weighted_mean_df,
#       pixel_count_df %>% select(land_cover_class, class_proportion_pct),
#       by = "land_cover_class"
#     )
#     
#     # --- Reorganize rows by descending wtd_mean ---
#     weighted_mean_df <- weighted_mean_df %>%
#       arrange(desc(wtd_mean))
#     
#     # Save each dataset as CSV with land cover index
#     csv_file <- file.path(output_dir, 
#                           paste0("weighted_mean_land_cover", i, "_", land_cover_name, ".csv"))
#     write.csv(weighted_mean_df, csv_file, row.names = FALSE)
#     
#     
#     weighted_mean_list[[land_cover_name]] <- weighted_mean_df
#   }
#   
#   # --- Assign names to weighted_mean_list based on raster names ---
#   names(weighted_mean_list) <- paste0("cropped_land_cover", seq_along(land_cover_name_values),"_", 
#                                       land_cover_name_values
#                                       )
#   
#   
#   # Save the full list as RDS
#   rds_file <- file.path(output_dir, "weighted_mean_list.rds")
#   saveRDS(weighted_mean_list, rds_file)
#   
#   message("\n✅ Weighted mean per land cover class per land cover product computed")
#   return(weighted_mean_list)
# }


weightedMeanPerLandCover <- function(dataset_list,
                                     list_of_land_cover_names, 
                                     class_proportions_list,
                                     output_dir,
                                     measure_class = c("extensive", "intensive"),
                                     measure_name = "Variable",
                                     unit = "unit") {
  
  measure_class <- match.arg(measure_class)
  
  # --- Stable weighted variance function (DEFINED ONCE, OUTSIDE PIPELINE LOGIC) ---
  weighted_var <- function(x, w) {
    ok <- is.finite(x) & is.finite(w)
    x <- x[ok]
    w <- w[ok]
    
    if (length(x) < 2) return(NA_real_)
    
    w <- w / sum(w)
    mx <- sum(w * x)
    sum(w * (x - mx)^2)
  }
  
  # --- Prepare output directory ---
  if (!is.null(output_dir)) {
    if (!grepl("^(/|[A-Za-z]:)", output_dir)) {
      output_dir <- file.path(getwd(), output_dir)
    }
    if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  }
  
  combined_df <- do.call(rbind, dataset_list)
  rownames(combined_df) <- NULL
  
  land_cover_raster_names <- grep("^land_cover", names(combined_df), value = TRUE)
  weighted_mean_list <- list()
  land_cover_name_values <- unlist(list_of_land_cover_names)
  
  for (i in seq_along(land_cover_raster_names)) {
    
    raster_name <- land_cover_raster_names[i]
    land_cover_name <- land_cover_name_values[i]
    
    df <- data.frame(
      land_cover_class = combined_df[[raster_name]],
      plotID = combined_df$plotID,
      measure_plot = as.numeric(combined_df$measure_plot),
      sampling_size_ha = as.numeric(combined_df$sampling_size_ha)
    )
    
    # --- Keep one row per plot ---
    df_first_occurrence <- df %>%
      dplyr::group_by(plotID) %>%
      dplyr::slice(1) %>%
      dplyr::ungroup()
    
    # remove invalid rows early (IMPORTANT for stability)
    df_first_occurrence <- df_first_occurrence %>%
      dplyr::filter(is.finite(measure_plot),
                    is.finite(sampling_size_ha),
                    sampling_size_ha > 0)
    
    total_samples <- nrow(df_first_occurrence)
    
    # --- Standardize measurement ---
    df_first_occurrence <- df_first_occurrence %>%
      dplyr::mutate(
        value_std = dplyr::case_when(
          measure_class == "extensive" ~ measure_plot / sampling_size_ha,
          TRUE ~ measure_plot
        )
      )
    
    # --- Weighted summary ---
    weighted_mean_df <- df_first_occurrence %>%
      dplyr::group_by(land_cover_class) %>%
      dplyr::summarise(
        N = dplyr::n(),
        N_pct = round((N / total_samples) * 100, 2),
        
        wtd_mean = round(
          sum(value_std * sampling_size_ha, na.rm = TRUE) /
            sum(sampling_size_ha, na.rm = TRUE),
          2
        ),
        
        # STABLE weighted variance (NO Hmisc)
        wtd_sd = if (N > 1) {
          sqrt(weighted_var(value_std, sampling_size_ha))
        } else {
          NA_real_
        },
        
        wtd_se = if (!is.na(wtd_sd)) wtd_sd / sqrt(N) else NA_real_,
        
        wtd_RSE_pct = if (!is.na(wtd_se) && wtd_mean != 0) {
          round((wtd_se / wtd_mean) * 100, 2)
        } else {
          NA_real_
        },
        
        CI_lower = if (!is.na(wtd_se)) round(wtd_mean - 1.96 * wtd_se, 2) else NA_real_,
        CI_upper = if (!is.na(wtd_se)) round(wtd_mean + 1.96 * wtd_se, 2) else NA_real_,
        
        .groups = "drop"
      ) %>%
      dplyr::mutate(
        land_cover_class = as.numeric(land_cover_class),
        measure_name = measure_name,
        unit = unit,
        label = paste0(measure_name, " (", unit, ")")
      )
    
    # --- Merge class proportions ---
    pixel_count_df <- class_proportions_list[[i]]
    
    weighted_mean_df <- dplyr::left_join(
      weighted_mean_df,
      pixel_count_df %>% dplyr::select(land_cover_class, class_proportion_pct),
      by = "land_cover_class"
    )
    
    # --- Sort ---
    weighted_mean_df <- weighted_mean_df %>%
      dplyr::arrange(dplyr::desc(wtd_mean))
    
    # --- Save CSV ---
    csv_file <- file.path(
      output_dir,
      paste0("weighted_mean_land_cover", i, "_", land_cover_name, ".csv")
    )
    
    utils::write.csv(weighted_mean_df, csv_file, row.names = FALSE)
    
    weighted_mean_list[[land_cover_name]] <- weighted_mean_df
  }
  
  # --- Name outputs ---
  names(weighted_mean_list) <- paste0(
    "cropped_land_cover",
    seq_along(land_cover_name_values),
    "_",
    land_cover_name_values
  )
  
  # --- Save RDS ---
  rds_file <- file.path(output_dir, "weighted_mean_list.rds")
  saveRDS(weighted_mean_list, rds_file)
  
  message("\n✅ Weighted mean per land cover class computed ")
  
  return(weighted_mean_list)
}

