get_color_mapping_per_product <- function(
    weighted_mean_results,
    water_classes_list = NULL
) {
  
  # ------------------------------------------------------------
  # 1. Compute GLOBAL GVA min and max across ALL products
  # ------------------------------------------------------------
  all_vals <- unlist(
    lapply(weighted_mean_results, function(df) df$wtd_mean)
  )
  
  global_min <- min(all_vals, na.rm = TRUE)
  global_max <- max(all_vals, na.rm = TRUE)
  
  if (!is.finite(global_min) | !is.finite(global_max)) {
    stop("GVA values are not valid for global color scaling.")
  }
  
  palette_fun <- colorRampPalette(c("darkblue", "white", "darkred"))
  color_mapping_list <- list()
  
  # ------------------------------------------------------------
  # 2. Build color mapping per product
  # ------------------------------------------------------------
  for (i in seq_along(weighted_mean_results)) {
    
    df <- weighted_mean_results[[i]]
    df$land_cover_class <- as.character(df$land_cover_class)
    
    # Identify water class
    water_classes <- as.character(unlist(water_classes_list))
    water_class <- intersect(water_classes, df$land_cover_class)
    if (length(water_class) > 1) water_class <- water_class[1]
    
    # Numeric GVA classes
    numeric_df <- df |>
      dplyr::filter(!is.na(wtd_mean) &
                      !land_cover_class %in% "*Other" &
                      !land_cover_class %in% water_class)
    
    numeric_classes <- numeric_df$land_cover_class
    numeric_vals <- numeric_df$wtd_mean
    
    color_values <- palette_fun(100)
    
    map_value_to_color <- function(x) {
      pos <- (x - global_min) / (global_max - global_min)
      pos <- max(min(pos, 1), 0)
      color_values[round(pos * 99) + 1]
    }
    
    numeric_colors <- sapply(numeric_vals, map_value_to_color)
    names(numeric_colors) <- numeric_classes
    
    # Default color vector
    all_classes <- unique(df$land_cover_class)
    color_vector <- setNames(rep("grey90", length(all_classes)), all_classes)
    
    color_vector[numeric_classes] <- numeric_colors
    if (length(water_class) == 1) color_vector[water_class] <- "#ADD8E6"
    if ("*Other" %in% names(color_vector)) color_vector["*Other"] <- "lightyellow"
    
    color_mapping_list[[i]] <- color_vector
  }
  
  names(color_mapping_list) <- names(weighted_mean_results)
  return(color_mapping_list)
}



classProportionChart <- function(
    weighted_mean_results,
    class_proportions_list,
    list_of_land_cover_names,
    water_classes_list,
    color_mapping_list,
    threshold,
    output_dir
) {
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # ------------------------------------------------------------
  # Helper: group classes EXACTLY like original code
  # ------------------------------------------------------------
  group_small_classes <- function(biomass_data, pixel_data, threshold, water_classes_list) {
    
    biomass_data$land_cover_class <- as.character(biomass_data$land_cover_class)
    pixel_data$land_cover_class   <- as.character(pixel_data$land_cover_class)
    
    water_classes <- as.character(unlist(water_classes_list))
    
    merged_data <- dplyr::full_join(
      pixel_data %>% dplyr::select(land_cover_class, class_proportion_pct),
      biomass_data %>% dplyr::select(land_cover_class, wtd_mean),
      by = "land_cover_class"
    ) %>%
      dplyr::filter(!is.na(class_proportion_pct))
    
    water_class <- intersect(water_classes, merged_data$land_cover_class)
    if (length(water_class) > 1) water_class <- water_class[1]
    
    # 1️⃣ Sampled classes
    sampled_classes <- merged_data %>% dplyr::filter(!is.na(wtd_mean))
    
    large_sampled <- sampled_classes %>%
      dplyr::filter(class_proportion_pct >= threshold |
                      land_cover_class %in% water_class)
    
    small_sampled <- sampled_classes %>%
      dplyr::filter(class_proportion_pct < threshold &
                      !land_cover_class %in% water_class)
    
    other_proportion <- sum(small_sampled$class_proportion_pct)
    
    # 2️⃣ Unsampled classes
    unsampled_classes <- merged_data %>% dplyr::filter(is.na(wtd_mean))
    unsampled_proportion <- sum(unsampled_classes$class_proportion_pct)
    
    # 3️⃣ Build displayed dataset
    displayed_data <- large_sampled
    
    if (other_proportion > 0) {
      displayed_data <- displayed_data %>%
        dplyr::add_row(
          land_cover_class = "*Other",
          class_proportion_pct = round(other_proportion, 2),
          wtd_mean = NA
        )
    }
    
    if (unsampled_proportion > 0) {
      displayed_data <- displayed_data %>%
        dplyr::add_row(
          land_cover_class = "Unsamp.",
          class_proportion_pct = round(unsampled_proportion, 2),
          wtd_mean = NA
        )
    }
    
    # 4️⃣ Ordering (UNCHANGED)
    displayed_data <- displayed_data %>%
      dplyr::mutate(
        is_water     = land_cover_class == water_class,
        is_other     = land_cover_class == "*Other",
        is_unsampled = land_cover_class == "Unsamp.",
        has_biomass  = !is.na(wtd_mean)
      ) %>%
      dplyr::arrange(
        is_water,
        dplyr::desc(has_biomass),
        dplyr::desc(wtd_mean),
        is_unsampled,
        is_other,
        land_cover_class
      ) %>%
      dplyr::select(-is_water, -is_other, -is_unsampled, -has_biomass)
    
    displayed_data
  }
  
  # ------------------------------------------------------------
  # Helper: create pie chart (UNCHANGED geometry & logic)
  # ------------------------------------------------------------
  create_pie_chart <- function(data, title, color_mapping_product, water_classes_list) {
    
    data <- data %>%
      dplyr::mutate(
        label = dplyr::if_else(
          class_proportion_pct >= 6,
          paste0(round(class_proportion_pct), "%"),
          ""
        ),
        label_outside = land_cover_class
      )
    
    data2 <- data %>%
      dplyr::mutate(
        csum = rev(cumsum(rev(class_proportion_pct))),
        pos_inside  = class_proportion_pct / 2 + dplyr::lead(csum, 1),
        pos_inside  = dplyr::if_else(is.na(pos_inside),
                                     class_proportion_pct / 2,
                                     pos_inside),
        pos_outside = csum - class_proportion_pct / 2,
        tick_start  = 1.475,
        tick_end    = 1.525
      )
    
    other_color     <- "lightyellow"
    unsampled_color <- "grey70"
    water_color     <- "#ADD8E6"
    
    color_vector <- sapply(data$land_cover_class, function(cl) {
      if (cl == "*Other") {
        other_color
      } else if (cl == "Unsamp.") {
        unsampled_color
      } else if (cl %in% unlist(water_classes_list)) {
        water_color
      } else {
        color_mapping_product[cl]
      }
    })
    
    names(color_vector) <- data$land_cover_class
    
    data$land_cover_class  <- factor(data$land_cover_class,
                                     levels = data$land_cover_class)
    data2$land_cover_class <- factor(data2$land_cover_class,
                                     levels = data$land_cover_class)
    
    p <- ggplot(data, aes(x = "", y = class_proportion_pct, fill = land_cover_class)) +
      geom_bar(stat = "identity", width = 1, color = "black", linewidth = 0.5) +
      coord_polar(theta = "y") +
      geom_text(aes(label = label),
                position = position_stack(vjust = 0.5),
                size = 11) +
      geom_text(data = data2,
                aes(x = 1.70, y = pos_outside, label = label_outside),
                size = 11) +
      geom_segment(data = data2,
                   aes(x = tick_start, xend = tick_end,
                       y = pos_outside, yend = pos_outside),
                   linewidth = 0.5) +
      scale_fill_manual(values = color_vector) +
      theme_minimal() +
      theme(
        axis.title = element_blank(),
        axis.text = element_blank(),
        axis.ticks = element_blank(),
        panel.grid = element_blank(),
        legend.position = "none"
      )
    
    title_text <- cowplot::ggdraw() +
      cowplot::draw_label(title, fontface = "bold", size = 28, hjust = 0.5)
    
    cowplot::plot_grid(title_text, p, ncol = 1, rel_heights = c(0.1, 1))
  }
  
  # ------------------------------------------------------------
  # Main loop
  # ------------------------------------------------------------
  pies_out <- list()
  
  for (i in seq_along(weighted_mean_results)) {
    
    grouped_data <- group_small_classes(
      weighted_mean_results[[i]],
      class_proportions_list[[i]],
      threshold,
      water_classes_list[[i]]
    )
    
    title_text <- paste(
      "Proportion of",
      list_of_land_cover_names[[i]],
      "\nland cover classes in the study area"
    )
    
    pie_plot <- create_pie_chart(
      grouped_data,
      title_text,
      color_mapping_list[[i]],
      water_classes_list[[i]]
    )
    
    file_name <- paste0(
      "class_proportion_chart_land_cover",
      i, "_",
      list_of_land_cover_names[[i]],
      ".png"
    )
    
    ggsave(
      filename = file.path(output_dir, file_name),
      plot = pie_plot,
      width = 10,
      height = 10,
      dpi = 300
    )
    
    pies_out[[list_of_land_cover_names[[i]]]] <- pie_plot
  }
  
  message("✅ Class proportion charts created in: ", output_dir)
  pies_out
}
