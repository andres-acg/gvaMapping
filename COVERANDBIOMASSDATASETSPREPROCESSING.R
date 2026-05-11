
sim$base_folder <- "C:/Users/ANCAG6/OneDrive - Université Laval/LICHEN_project/paper1/SpaDES_version/gvaMapping"
base_folder <- sim$base_folder

###############################################################################
##########        COVER AND BIOMASS DATASETS PREPROCESSING         ############
###############################################################################

# COVER datasets

sim$raw_dataset1A <- file.path(base_folder, "data", "plot_datasets", "cover_datasets",
                               "cover_dataset1 - Baltzer et al",
                               "Chronosequence quadrat covers_2016_2017_2018_2019-02-11.v2.csv") #GET LINK

sim$raw_dataset1B <- file.path(base_folder, "data", "plot_datasets", "cover_datasets",
                               "cover_dataset1 - Baltzer et al",
                               "All site info 2019-10-16.csv") #GET LINK

sim$raw_dataset2A <- file.path(base_folder, "data", "plot_datasets", "cover_datasets",
                               "cover_dataset2 - Errington et al",
                               "lichen dataset for Andres.xlsx")

sim$raw_dataset2B <- sim$raw_dataset2A

sim$raw_dataset3A <- file.path(base_folder, "data", "plot_datasets", "cover_datasets",
                               "cover_dataset3 - NFI",
                               "all_gp_ecp_species.csv")

sim$raw_dataset3B <- file.path(base_folder, "data", "plot_datasets", "cover_datasets",
                               "cover_dataset3 - NFI",
                               "all_gp_site_info_approx_loc.csv")

# BIOMASS datasets
sim$raw2_dataset1A <- file.path(base_folder, "data", "plot_datasets", "biomass_datasets",
                                "biomass_dataset1 - Cook et al",
                                "ForageBiomass_NWT_20162019.xlsx")

sim$raw2_dataset1B <- file.path(base_folder, "data", "plot_datasets", "biomass_datasets",
                                "biomass_dataset1 - Cook et al",
                                "PenCharacteristics_NWTCaribou_Location fixes added_red__FM_for Genev_Mar 2022.xlsx")

sim$raw2_dataset2A <- file.path(base_folder, "data", "plot_datasets", "biomass_datasets",
                                "biomass_dataset2 - LGL",
                                "EA3922 Lichen Plot Data_ALL YEARS_SUMMARY BIOMASS three ways.xlsx") #GET LINK


# sampling size for each dataset to weight mean calculation - in m2
sim$sampling_size_m2_raw_dataset1 <- P(sim)$sampling_size_m2[1] #1 #cover biomass dataset 1
sim$sampling_size_m2_raw_dataset2 <- P(sim)$sampling_size_m2[2] #1 #cover biomass dataset 2
sim$sampling_size_m2_raw_dataset3 <- P(sim)$sampling_size_m2[3] #100 #cover biomass dataset 3
sim$sampling_size_m2_raw2_dataset1 <- P(sim)$sampling_size_m2[4] #2  #raw biomass dataset 1
sim$sampling_size_m2_raw2_dataset2 <- P(sim)$sampling_size_m2[5] #0.25 #raw biomass dataset 2


sim$sampling_type_names_raw_dataset <- grep("^sampling_size_m2_raw_dataset\\d+$",ls(envir = sim), value = TRUE)

sim$sampling_types_raw_dataset <- mget(sim$sampling_type_names_raw_dataset, envir = as.environment(sim))

cat(
  "Sampling size variables detected:",
  paste(sim$sampling_type_names_raw_dataset, collapse = ", "),
  "\n"
)

# COVER AND BIOMASS PLOT DATASETS CLEANING AND PREPARATION

dataset_list <- setNames(
  lapply(c("raw", "raw2"), function(type) {
    # Automatically detect datasets and validate existence of functions/inputs
    X_vals <- autoDetectDatasets(sim, type)
    
    if (length(X_vals)) {
      setNames(
        lapply(X_vals, function(x) datasetLoadORPrep(sim, type, x)),
        paste0(type, "_dataset", X_vals)
      )
    }
  }),
  c("raw_dataset_list", "raw2_dataset_list")
)


# CONVERT COVER INTO BIOMASS (for cover datasets)

if (!is.null(dataset_list$raw_dataset_list) &&
    length(dataset_list$raw_dataset_list) > 0) {
  
  dataset_list$raw_dataset_list <- convertCoverToBiomass(
    dataset_list$raw_dataset_list,
    sim$sampling_types_raw_dataset
  )
}


dataset_list <- unlist(dataset_list, recursive = FALSE)

sim$dataset_list <- lapply(dataset_list, function(df) {
  df %>%
    rename(
      gva = species,
      measure_quad = biomass_dens_quad,
    )  %>%
    dplyr::select(
      -biomass_quad,
      -sampling_size_ha
    )
})
