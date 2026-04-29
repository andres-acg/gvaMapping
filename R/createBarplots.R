createBarplots <- function(
    weighted_mean_results,
    list_of_land_cover_names,
    water_classes_list,
    inapplicable_classes_list,
    color_mapping_list,
    abbrev_list,
    measure_name,
    unit,
    output_dir
) {
  
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  
  # ------------------------------------------------------------
  # Global range for y‑axis
  # ------------------------------------------------------------
  all_vals <- unlist(lapply(weighted_mean_results, function(df) df$wtd_mean))
  global_min <- min(all_vals, na.rm = TRUE)
  global_max <- max(all_vals, na.rm = TRUE)
  
  if (!is.finite(global_min) || !is.finite(global_max)) {
    global_min <- 0
    global_max <- 1
  }
  
  ymax <- max(pretty(c(global_min, global_max)))
  
  plots_out <- list()
  
  # ------------------------------------------------------------
  # Loop over land‑cover products
  # ------------------------------------------------------------
  for (i in seq_along(weighted_mean_results)) {
    
    data_orig <- weighted_mean_results[[i]]
    
    # ------------------------------------------------------------
    # Water & inapplicable classes
    # ------------------------------------------------------------
    water_class <- as.character(unlist(water_classes_list[[i]]))
    water_class <- water_class[!is.na(water_class)]
    
    inapplicable_classes <- as.character(unlist(inapplicable_classes_list[[i]]))
    inapplicable_classes <- inapplicable_classes[!is.na(inapplicable_classes)]
    
    non_water_inapplicable_classes <- setdiff(
      inapplicable_classes,
      water_class
    )
    
    # ------------------------------------------------------------
    # Abbreviations
    # ------------------------------------------------------------
    abbr_map <- abbrev_list[[i]]
    data_orig$abbr <- abbr_map[as.character(data_orig$land_cover_class)]
    
    ordered_levels <- data_orig |>
      dplyr::arrange(desc(wtd_mean)) |>
      dplyr::pull(abbr) |>
      unique()
    
    data_orig$abbr <- factor(data_orig$abbr, levels = ordered_levels)
    
    # ------------------------------------------------------------
    # Labels (EXACT logic from original code)
    # ------------------------------------------------------------
    data_orig <- data_orig |>
      dplyr::mutate(
        RSE_label = ifelse(
          is.na(wtd_RSE_pct) | is.nan(wtd_RSE_pct),
          "--",
          paste0(round(wtd_RSE_pct), "%")
        ),
        N_label = ifelse(
          is.na(N),
          "",
          paste0("n=", N)
        ),
        top_label = paste0(
          N_label,
          ifelse(N_label == "", "", "\n"),
          "RSE=", RSE_label
        )
      )
    
    # ------------------------------------------------------------
    # Split data
    # ------------------------------------------------------------
    df_numeric <- data_orig |>
      dplyr::filter(!is.na(wtd_mean),
                    !land_cover_class %in% water_class)
    
    df_water <- data_orig |>
      dplyr::filter(land_cover_class %in% water_class)
    
    df_na <- data_orig |>
      dplyr::filter(is.na(wtd_mean),
                    !land_cover_class %in% water_class)
    
    # ------------------------------------------------------------
    # Colors
    # ------------------------------------------------------------
    color_mapping <- color_mapping_list[[i]]
    
    df_numeric$fill_color <- sapply(
      as.character(df_numeric$land_cover_class),
      function(cl) {
        if (cl %in% non_water_inapplicable_classes) {
          NA
        } else if (cl %in% names(color_mapping)) {
          color_mapping[[cl]]
        } else {
          "grey50"
        }
      }
    )
    
    # ------------------------------------------------------------
    # Plot
    # ------------------------------------------------------------
    p <- ggplot() +
      
      geom_col(
        data = df_numeric,
        aes(x = abbr, y = wtd_mean, fill = fill_color),
        color = "black",
        width = 0.9,
        show.legend = FALSE
      ) +
      
      { if (nrow(df_water) > 0)
        geom_col(
          data = df_water,
          aes(x = abbr, y = ifelse(is.na(wtd_mean), 0, wtd_mean)),
          fill = "#ADD8E6",
          color = "black",
          width = 0.9,
          show.legend = FALSE
        ) } +
      
      { if (nrow(df_na) > 0)
        geom_col(
          data = df_na,
          aes(x = abbr, y = 0),
          fill = "grey90",
          color = "black",
          width = 0.9,
          show.legend = FALSE
        ) } +
      
      geom_text(
        data = data_orig,
        aes(
          x = abbr,
          y = pmax(wtd_mean, 0) + 10,
          label = top_label
        ),
        vjust = 0,
        hjust = 0,
        angle = 60,
        color = "black",
        size = 5
      ) +
      
      scale_fill_identity() +
      scale_y_continuous(
        limits = c(0, ymax),
        breaks = scales::pretty_breaks(n = 7)
      ) +
      
      labs(
        title = paste(
          measure_name,
          "per",
          list_of_land_cover_names[[i]],
          "land‑cover class"
        ),
        x = "Land‑cover class",
        y = paste0(measure_name, " (", unit, ")")
      ) +
      
      theme_minimal() +
      theme(
        panel.background = element_rect(fill = "grey90", color = NA),
        plot.background  = element_rect(fill = "white", color = NA),
        plot.title = element_text(size = 16, face = "bold"),
        axis.text.x = element_text(angle = 60, hjust = 1, size = 12),
        axis.text.y = element_text(size = 12),
        axis.title.x = element_text(size = 13),
        axis.title.y = element_text(size = 13)
      )
    
    # ------------------------------------------------------------
    # Save
    # ------------------------------------------------------------
    filename <- paste0(
      "barplot_",
      gsub("\\s+", "_", list_of_land_cover_names[[i]]),
      ".png"
    )
    
    ggsave(
      filename = file.path(output_dir, filename),
      plot = p,
      width = 14,
      height = 10,
      dpi = 300
    )
    
    plots_out[[list_of_land_cover_names[[i]]]] <- p
  }
  
  message("✅ Class‑mean bar plots saved to: ", normalizePath(output_dir))
  return(plots_out)
}