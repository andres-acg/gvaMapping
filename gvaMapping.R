## Everything in this file and any files in the R directory are sourced during `simInit()`;
## all functions and objects are put into the `simList`.
## To use objects, use `sim$xxx` (they are globally available to all modules).
## Functions can be used inside any function that was sourced in this module;
## they are namespaced to the module, just like functions in R packages.
## If exact location is required, functions will be: `sim$.mods$<moduleName>$FunctionName`.
defineModule(sim, list(
  name = "gvaMapping",
  description = "Ground vegetation attributes (GVA) mapping module for SpaDES",
  keywords = "ground vegetation",
  authors = structure(list(list(given = c("Andres"), family = "Caseiro Guilhem", role = c("aut", "cre"), email = "andres.caseiro-guilhem.1@ulaval.ca", comment = NULL)), class = "person"),
  childModules = character(0),
  version = list(gvaMapping = "0.0.0.9001"),
  timeframe = as.POSIXlt(c(NA, NA)),
  timeunit = "year",
  citation = list("citation.bib"),
  documentation = list("NEWS.md", "README.md", "gvaMapping.Rmd"),
  reqdPkgs = list("SpaDES.core (>= 2.1.5.9000)",
                  "dplyr",
                  "readxl",
                  "lubridate",
                  "data.table",
                  "tidyr",
                  "units",
                  "gtools",
                  "modi",
                  #GIS
                  "sf",
                  "terra",
                  "ggspatial",
                  # NEW 2026-08-11: public-data-only defaults in Init() use
                  # reproducible::prepInputs()
                  "reproducible",
                  #cross-validation
                  "metrica",
                  "sampling", 
                  "BalancedSampling",
                  #parellization
                  "parallel",
                  "doParallel", 
                  "foreach", 
                  #visualization
                  "ggplot2",
                  "cowplot"),
  
  parameters = bindrows(
    #defineParameter("paramName", "paramClass", value, min, max, "parameter description"),
    
    #PLOT DATASETS parameters
    # type of measurement
    defineParameter("measure_class", "character", "intensive", NA, NA,
                    "Type of measurement at the plot level. 
                    
                      'extensive' = total quantity dependent on sampled area 
                       (e.g., total biomass, total counts); 
                    values will be converted to density by dividing by sampling area. 
                    
                      'intensive' = already standardized per unit area or proportion
                       (e.g., biomass density, individuals per hectare, percent cover); 
                    values are used directly without area correction."),
    
    defineParameter("measure_name", "character", "Biomass", NA, NA,
                    "Name of the ecological variable being mapped. Used for labeling outputs and plots 
                       (e.g., Biomass, Abundance, Cover, Density)."),
    
    defineParameter("unit", "character", "kg ha⁻¹", NA, NA,
                    "Unit of the measurement. Should reflect the final standardized output 
                       (e.g., kg ha⁻¹, individuals ha⁻¹, %, g m⁻²). Supports Unicode formatting for exponents (e.g., ha⁻¹)."),
    
    
    ##list with sampling size for each dataset to weight mean calculation - in m²
    ## DEFAULT (2026-08-11): dataset1's own sampling size (0.25 m2, Deninu Kųę́
    ## First Nation et al.), matching the auto-fetched public-data-only
    ## default Init() falls back to when dataset_list isn't supplied (see
    ## Init()). Supply your own list (named by your own dataset_list entries)
    ## when using additional/other datasets.
    defineParameter("sampling_size_m2", "list", list(dataset1 = 0.25), NA, NA,
                    "sampling unit size per plot dataset (in m²). Must have names according to datasets (e.g., sampling_size_m2_dataset1, sampling_size_m2_dataset2, etc)"),

    # target gva(s)
    ## DEFAULT (2026-08-11): the Cladonia spp. (caribou lichen) target list
    ## used in this module's own example application (see
    ## SpaDES-gvaMapping/globalscript.R), so the module has a real target to
    ## filter/pool even with zero params supplied.
    defineParameter("target_gva", "character",
                    c("mitis", "Cladmit", "MIT", "CLMI",
                      "arbuscula", "Cladarb", "ARB",
                      "rangiferina", "Cladran", "RAN", "CLRA",
                      "stygia", "Cladsty", "STY",
                      "stellaris", "Cladste", "STE", "CLST",
                      "uncialis", "Cladunc", "unc", "CLADUNC",
                      "amaurocrea", "Cladama", "AMA",
                      "spp."),
                    NA, NA,
                    "vector with target GVA attribute(S) to be filtered and pooled"),


    #LAND COVER PRODUCTS parameters
    ## name of land cover product(s) to be used in the analysis (must match the name in the file name of the land cover product)
    ## DEFAULT (2026-08-11): LCC10 (2010 Land Cover of Canada) and NTEMS
    ## (VLCE2), the two public land cover products this module's own example
    ## application uses (see SpaDES-gvaMapping/globalscript.R) and the same
    ## default Init() falls back to when land_cover_paths isn't supplied.
    defineParameter("list_of_land_cover_names", "list",
                    list(land_cover1 = "LCC10", land_cover2 = "NTEMS"), NA, NA,
                    "list with name of land cover product(s) (must match the name in the file name of the land cover product)"),

    ##land cover product(s) reference year
    ## DEFAULT (2026-08-11): 2010, matching both LCC10's and NTEMS's coverage
    ## for this project's example application (see globalscript.R).
    defineParameter("land_cover_year", "numeric", 2010, NA, NA,
                    "reference year for land cover products used to filter plots based on disturbance history"),

    #inapplicable land cover class(es) for mapping per land cover product
    ## DEFAULT (2026-08-11): matches the LCC10/NTEMS legends already used in
    ## SpaDES-gvaMapping/globalscript.R (LCC10: 17 = urban, 18 = water;
    ## NTEMS: 20 = water, 31 = snow/ice).
    defineParameter("inapplicable_classes_list", "list",
                    list(land_cover1 = c(17, 18), land_cover2 = c(20, 31)), NA, NA,
                    "vector of inapplicable land cover class(es) per land cover product  (e.g., water and urban classes)"),

    #PLOTTING parameters
    #water classes for visualization and identification of their proportion in the study area
     #compared to terrestrial classes
    ## DEFAULT (2026-08-11): matches globalscript.R (LCC10: 18 = water;
    ## NTEMS: 20 = water).
    defineParameter("water_classes_list", "list",
                    list(land_cover1 = 18, land_cover2 = 20), NA, NA,
                    "water classes for visualization and identification of their proportion in the study area"),

    ## DEFAULT (2026-08-11): matches globalscript.R's LCC10 and NTEMS
    ## abbreviation tables.
    defineParameter(
      "abbrev_list", "list",
      list(land_cover1 = c("1"  = "1-Needle.\nforest",
                           "2"  = "2-Taiga \nneedle.\nforest*",
                           "5"  = "5-Broad.\ndecid.\nforest*",
                           "6"  = "6-Mixed\nforest*",
                           "8"  = "8-Shrub.",
                           "10" = "10-Grass.*",
                           "11" = "Shrubland-\nlichen-moss",
                           "12" = "Sub-polar/polar\ngrassland-\nlichen-moss",
                           "13" = "Sub-polar/polar\nbarren-\nlichen-moss",
                           "14" = "14-Wet.",
                           "15" = "Cropland",
                           "16" = "16-Barren\nlands*",
                           "17" = "17-Urban*",
                           "18" = "18-Water",
                           "19" = "Snow and\nice"),
           land_cover2 = c("20"  = "20-Water",
                           "31"  = "31-Snow/Ice*",
                           "32"  = "Rock/\nRubble",
                           "33"  = "33-Exp.\nbarren\nland*",
                           "40"  = "40-Bryoids*",
                           "50"  = "50-Shrubs",
                           "80"  = "80-Wet.",
                           "81"  = "81-Wet.-\ntreed*",
                           "100" = "Herbs",
                           "210" = "210-Conif.",
                           "220" = "220-Broad.*",
                           "230" = "230-Mixed.*")),
      NA, NA,
      "List wwith vector(s) with land cover classes abbreviations per land cover product for barplot(s)"
    ),
    
    #SEED
    #seed parameter for reproducibility of results (e.g., in cross-validation)
    defineParameter("seed", "numeric", 81, NA, NA,
                    "seed for reproducibility of results (e.g., in cross-validation)"),

    #OUTPUT DIRECTORY
    defineParameter("gva_output_dir", "character", NA, NA, NA,
                    "Directory where all gvaMapping outputs are written, and where the
                     module looks for already-computed intermediate products before
                     recomputing them. Defaults to
                     file.path(getOption('spades.outputPath'), 'gvaMapping').
                     Set this to a location SHARED between several SpaDES projects (for
                     example the several years of a backcasting run) when the class means
                     are year-independent: the module then computes everything on the
                     first run and, on every later run, finds its own files and skips the
                     expensive steps."),

    #CROSS-VALIDATION
    defineParameter("run_cross_validation", "logical", TRUE, NA, NA,
                    "If FALSE, skip the k-fold cross-validation of the gva rasters
                     (STEP 4). Only honoured when a single land cover product is supplied
                     -- with more than one product the SMAPE values are needed to weight
                     the ensemble map, so the cross-validation is always run. Use FALSE
                     when only the class-mean table is needed."),
    defineParameter("n_folds", "numeric", 10, 1, NA,
                    "Number of folds for k-fold cross-validation -- used both for the
                     per-land-cover-product GVA raster cross-validation (STEP 4) and,
                     when more than one land cover product is supplied, the ensemble map
                     cross-validation.")


),
  
  inputObjects = bindrows(
    # VEGETATION PLOT DATASET(S)
    expectsInput(
      objectName = "dataset_list",
      objectClass = "list",
      desc = "Named list with formatted plot dataset(s) as data frames. Must have numbered dataset names: dataset1, dataset2, etc)",
      sourceURL = NA
    ),
    
    # STUDY AREA
    expectsInput(
      objectName = "study_area_path",
      objectClass = "character",
      desc = "Path to study area shapefile used to filter plots",
      sourceURL = NA
    ),
    
    # LAND COVER PRODUCT(S)
    expectsInput(
      objectName = "land_cover_paths",
      objectClass = "list",
      desc = "Path to land cover product(s)",
      sourceURL = NA
    ),
  
    # DISTURBANCE DATA (optional)
     expectsInput(
      objectName = "disturbances_path",
      objectClass = "character",
      desc = "Path to disturbance shapefile",
      sourceURL = NA
    )
  ),
  outputObjects = bindrows(
    #createsOutput("objectName", "objectClass", "output object description", ...),
    createsOutput(objectName = "dataset_list", objectClass = "list", desc = "list of plot datasets containing plots after study area (and, if it is the case, disturbance-based) filtering (see outputs folder)"),
    createsOutput(objectName = "gva_map", objectClass = "SpatRast", desc = "gva map per land cover product (not in module see outputs folder)"),
    createsOutput(objectName = "bar_plot", objectClass = "ggplot", desc = "class-mean bar plot per land cover product (see outputs folder)"),
    createsOutput(objectName = "pie_chart", objectClass = "ggplot", desc = "class proportion pie chart per land cover product (see outputs folder)"),
    createsOutput(objectName = "ensemble_gva_map", objectClass = "SpatRast", desc = "ensemble gva map, if > 1 land cover provided (see outputs folder)"),
    createsOutput(objectName = "cv_map", objectClass = "SpatRast", desc = "cv map, if > 1 land cover provided (see outputs folder)")
    
    # N.B.: IMPORTANT OUTPUTS LIKE MAPS WILL BE SAVED AS RASTER FILES IN THE 
    #       OUTPUT FOLDER, NOT AS R OBJECTS.
    
  )
))

doEvent.gvaMapping = function(sim, eventTime, eventType) {
  switch(
    eventType,
    init = {
      
      sim <- Init(sim)

     
    },
    
    warning(noEventWarning(sim))
  )
  return(invisible(sim))
}


Init <- function(sim) {

  # Module output directory.
  # By default it is SpaDES-managed (inside this project's outputPath). It can be
  # redirected with the `gva_output_dir` parameter so that several projects -- e.g.
  # the successive years of a backcasting run -- share one set of outputs. Because
  # every expensive step below is guarded by a file-existence check against this
  # directory, pointing several runs at the same folder means the work is done once
  # and reused afterwards.
  module_output_dir <- P(sim)$gva_output_dir
  if (is.null(module_output_dir) || length(module_output_dir) != 1L ||
      is.na(module_output_dir) || !nzchar(module_output_dir)) {
    module_output_dir <- file.path(getOption("spades.outputPath"), "gvaMapping")
  }
  dir.create(module_output_dir, recursive = TRUE, showWarnings = FALSE)
  message("📂 gvaMapping output directory: ", module_output_dir)

  ##############################################################################
  # NEW (2026-08-11): public-data-only defaults, so this module can run
  # without ANY of the user's own private plot/study-area/land-cover data
  # supplied. Each of the three inputs below auto-fetches a PUBLIC source if
  # not already supplied -- Zenodo (the Wek'eezhii study area boundary and
  # the Deninu Kųę́ First Nation et al. lichen plot dataset) and LCC10 + NTEMS
  # (Government of Canada open data; the SAME two land cover products this
  # module's own example application uses, not a lower-quality substitute --
  # see SpaDES-gvaMapping/globalscript.R).
  #
  # What is deliberately NOT auto-generated: datasets 2-5 (Baltzer,
  # Errington, NFI, Cook et al.) stay local-only/opt-in via useDataset in
  # SpaDES-gvaMapping/globalscript.R -- they are private field data with no
  # public source to fetch, and there is no fabricated/synthetic placeholder
  # for them here. The default this module falls back to is REAL statistics
  # computed from REAL (if limited, single-source) public data, never made-up
  # numbers.
  ##############################################################################

  # 1. Study area -----------------------------------------------------------
  # NOTE: deliberately does NOT check file.exists() here -- a user-supplied
  # URL (loadStudyArea() accepts either) would fail that check and get
  # wrongly treated as "missing" and overwritten. Only NULL/NA/empty counts
  # as unsupplied.
  studyAreaMissing <- is.null(sim$study_area_path) || length(sim$study_area_path) != 1L ||
    is.na(sim$study_area_path) || !nzchar(sim$study_area_path)
  if (studyAreaMissing) {
    message("🌐 study_area_path not supplied (or file not found) -- auto-fetching the public ",
            "Wek'eezhii boreal caribou range boundary from Zenodo (doi:10.5281/zenodo.20492584)...")
    saDir <- file.path(getOption("spades.inputPath"), "study_area")
    dir.create(saDir, recursive = TRUE, showWarnings = FALSE)
    reproducible::prepInputs(
      url = paste0("https://zenodo.org/records/20492584/files/",
                   "Wekeezhii_SouthernNWT_boreal_caribou_planning_range_regions.zip",
                   "?download=1"),
      destinationPath = saDir,
      targetFile = "Boreal Caribou Range Planning Regions.shp",
      archive = "Wekeezhii_SouthernNWT_boreal_caribou_planning_range_regions.zip",
      fun = terra::vect, overwrite = FALSE)
    sim$study_area_path <- file.path(saDir, "Boreal Caribou Range Planning Regions.shp")
  }

  # 2. Land cover -------------------------------------------------------------
  # Same reasoning as study area: only NULL/empty counts as "not supplied" --
  # a user-supplied path/URL is left alone. LCC10 and NTEMS are the same two
  # public land cover products this module's own example application uses
  # (see SpaDES-gvaMapping/globalscript.R); their URLs are simply handed to
  # the existing generic pipeline (loadLandCovers() below, then
  # cropLandCoverProduct()), exactly as globalscript.R's own explicit
  # configuration already does -- no separate fetch/reclassify logic needed.
  landCoverMissing <- is.null(sim$land_cover_paths) || length(sim$land_cover_paths) == 0L
  if (landCoverMissing) {
    message("🌐 land_cover_paths not supplied -- auto-fetching the public LCC10 (2010 Land ",
            "Cover of Canada) and NTEMS (VLCE2) land cover products...")
    sim$land_cover_paths <- list(
      land_cover1 = paste0("https://datacube-prod-data-public.s3.ca-central-1.amazonaws.com/",
                            "store/land/landcover/landcover-2010-classification.tif"),
      land_cover2 = "https://opendata.nfis.org/downloads/forest_change/CA_forest_VLCE2_2010.zip"
    )
  }

  # 3. Plot data (dataset1 ONLY -- see header comment) -----------------------
  datasetListMissing <- is.null(sim$dataset_list) || length(sim$dataset_list) == 0L
  if (datasetListMissing) {
    message("🌐 dataset_list not supplied -- auto-building the public default (dataset1, ",
            "Deninu Kųę́ First Nation et al.) only. Datasets 2-5 (Baltzer, Errington, NFI, ",
            "Cook et al.) are private field data with no public source and are NOT ",
            "substituted with placeholder data -- supply your own dataset_list to include them.")
    ds1Dir <- file.path(getOption("spades.inputPath"), "datasets", "dataset1")
    dir.create(ds1Dir, recursive = TRUE, showWarnings = FALSE)
    ds1Csv <- file.path(ds1Dir, "dataset1_formatted.csv")
    if (!file.exists(ds1Csv)) {
      # loadAndPrepRawDataset1() (R/preprocessing.R, auto-sourced by SpaDES as
      # part of this module) defaults to dataset1's own public Zenodo link
      # when called with no arguments.
      write.csv(loadAndPrepRawDataset1(), ds1Csv, row.names = FALSE)
    }
    sim$dataset_list <- list(dataset1 = ds1Csv)
  }

  #Loading inputs
  #datasets:
  sim$dataset_list <- loadDatasets(sim$dataset_list)
  
  #study area:
  sim$study_area_path <- loadStudyArea(sim$study_area_path)
  
  #land cover products:
  sim$land_cover_paths <- loadLandCovers(sim$land_cover_paths)
  
  #disturbances:
  sim$disturbances_path <- loadDisturbances(sim$disturbances_path)
 
 

  
  
################################################################################  
#####                       STEP1 : Data preparation                      ######
################################################################################  
 
  # SELECT TARGET GVA AND POOL IT AT THE PLOT LEVEL
  # num_datasets <- length(grep("^dataset\\d+$", ls(sim)))
  # dataset_names <- paste0("dataset", seq_len(num_datasets))
  # sim$dataset_list <- lapply(dataset_names, function(nm) sim[[nm]])
  # names(sim$dataset_list) <- dataset_names
  # 
  # sampling_size_m2 <- P(sim)[
  #   grep("^sampling_size_m2_dataset", names(P(sim)))
  # ] |> unlist()
  
  sim$dataset_list <- datasetPreparation(
    dataset_list      = sim$dataset_list,
    target_gva        = P(sim)$target_gva,
    sampling_size_m2  = P(sim)$sampling_size_m2
  )
 

 # FILTER PLOTS WITHIN STUDY AREA

 # 2026-08-14: wrapped in Cache(), matching every other expensive step in
 # this module (see "every expensive step below is guarded" comment above
 # module_output_dir). This one and keepUndisturbedPlots() just below were
 # the two steps that comment didn't actually describe correctly -- they
 # recomputed every backcast year even though study_area_path, dataset_list
 # and disturbances_path/land_cover_year never change across years for this
 # project, wasting a full spatial intersection each time. Cache() (rather
 # than a hand-rolled file.exists() guard like the neighbouring steps use)
 # so it also self-invalidates if the field data, study area, or fire
 # database are ever revised later -- see PROJECT_NOTES.md, 2026-08-14.
 #study_area_path <- sim$study_area_path
 sim$dataset_list <- Cache(filterPlotsStudyArea, sim$dataset_list,
                                          sim$study_area_path,
                                          output_dir = file.path(module_output_dir, "filtered_plots_study_area")
                                          )


 # FILTER PLOTS BASED ON DISTURBANCE (OPTIONAL)

 if (!is.na(sim$disturbances_path) && file.exists(sim$disturbances_path)) {

   sim$dataset_list <- Cache(keepUndisturbedPlots,
     dataset_list      = sim$dataset_list,
     disturbances_path = sim$disturbances_path,
     land_cover_year   = P(sim)$land_cover_year,
     output_dir = file.path(module_output_dir, "filtered_plots_undisturbed")
     )

 } else {
   cat("⚠️ skipping disturbance analysis\n")
 }


 # GIS OPERATIONS

 # # Land cover path list
 # # --- Determine the number of land cover paths dynamically
 # num_land_cover <- length(grep("^land_cover\\d+_path$", ls(sim)))
 # cat("Detected", num_land_cover, "land cover path variable(s).\n")
 # 
 # # --- Generate a vector of land cover path names
 # land_cover_path_names <- paste0("land_cover", 1:num_land_cover, "_path")
 # cat("Land cover path variable names:", paste(land_cover_path_names, collapse = ", "), "\n")
 # 
 # # --- Retrieve land cover paths by their names and store them in a list
 # land_cover_paths <- mget(land_cover_path_names, envir = as.environment(sim))
 # cat("Land cover paths:", paste(unlist(land_cover_paths), collapse = ", "), "\n")



 # #Land cover name list
 # # --- Determine the number of datasets dynamically
 # 
 # # SEARCH FOR LAND COVER NAME VARIABLES IN THE SIM ENVIRONMENT

 # num_name_land_cover <- length(grep("^name_land_cover\\d+$", ls(P(sim))))
 # cat("Detected", num_name_land_cover, "land cover name variable(s).\n")
 # 
 # # --- Generate a vector of dataset names
 # land_cover_names <- paste0("name_land_cover", 1:num_name_land_cover)
 # cat("Land cover name variable names:", paste(land_cover_names, collapse = ", "), "\n")
 # 
 # # --- Retrieve datasets by their names and store them in a list
 # list_of_land_cover_names <- lapply(land_cover_names, function(nm) P(sim)[[nm]])
 # cat("Land cover names:", paste(unlist(list_of_land_cover_names), collapse = ", "), "\n")


 ## CROP LAND COVER PRODUCTS TO STUDY AREA

 #  directory for cropped land cover products
 cropped_lc_dir <- file.path(module_output_dir, "cropped_land_cover_products")
 missing_names <- vector()
 for (lc_name in P(sim)$list_of_land_cover_names) {
   # pattern for this land cover (any X)
   pattern <- paste0("cropped_land_cover\\d+_", lc_name, "\\.tif$")

   # see if any file exists
   if (length(list.files(cropped_lc_dir, pattern = pattern, full.names = TRUE)) == 0) {
     missing_names <- c(missing_names, lc_name)
   }
 }

 if (length(missing_names) > 0) {
   message("🪓 Missing cropped rasters for: ", paste(missing_names, collapse = ", "),
           " — cropping them...")

   cropLandCoverProduct(
     study_area_path = sim$study_area_path,
     land_cover_paths = sim$land_cover_paths,
     list_of_land_cover_names = missing_names,
     output_dir = cropped_lc_dir

   )
 } else {
   message("✅ All cropped land cover rasters already exist — skipping cropping step.")
 }

 
 ## CLASS PROPORTIONS PER LAND COVER PRODUCT
 # function that determines class size (i.e, number of pixels as proxy) and proportion per land cover product
 #class_proportions_path <- file.path(base_folder, "outputs", "class_proportions.rds") ## CHANGE FOLDER!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!<<<


 class_prop_file <- file.path(module_output_dir, "class_proportions", "class_proportions.rds")

 if (file.exists(class_prop_file)) {
   message("✅ 'class_proportions.rds' found — loading existing object...")
   sim$class_proportions_list <- readRDS(class_prop_file)
 } else {
   message("⚙️  'class_proportions.rds' not found — computing class proportions...")
   sim$class_proportions_list <- computeClassProportions(
     output_dir_in  = cropped_lc_dir,
     output_dir_out = file.path(module_output_dir, "class_proportions")
   )
 }


 # CLASSES EXTRACTION FROM LAND COVER PRODUCT(S) AT PLOT LOCATIONS
 sim$dataset_list <- extractPlotLCC_from_folder(
   output_dir_in  = file.path(module_output_dir, "cropped_land_cover_products"),
   dataset_list   = sim$dataset_list,
   output_dir_out = file.path(module_output_dir, "datasets_with_lc_classes")
 )

################################################################################
#####    STEP2 : Computation of class-means and statistical summaries     ######
################################################################################

 # weighted mean and RSE per land cover class per land cover product
 sim$weighted_mean_results <- weightedMeanPerLandCover(
   dataset_list             = sim$dataset_list,
   list_of_land_cover_names = P(sim)$list_of_land_cover_names,
   class_proportions_list   = sim$class_proportions_list,
   output_dir               = file.path(module_output_dir, "weighted_mean_per_lcc_results"),
   measure_class            = P(sim)$measure_class,
   measure_name             = P(sim)$measure_name,
   unit                     = P(sim)$unit
 )


 #CLASS PROPORTION PIE CHARTS
 # #  INNAPLICABLE CLASSES LIST
 #  # Determine the number of water class objects
 #  num_inapplicable_classes <- length(grep("^inapplicable_classes_land_cover\\d+$", names(P(sim))))
 #  cat("Detected", num_inapplicable_classes, "LC products with inapplicable class(es).\n")
 # 
 #  # Generate a vector of water class objects
 #  inapplicable_classes_values <- paste0("inapplicable_classes_land_cover", seq_len(num_inapplicable_classes))
 #  cat(paste(inapplicable_classes_values, collapse = ", "), "\n")
 # 
 #  # Retrieve water classes by their names and store them in a list
 #  inapplicable_classes_list <- lapply(inapplicable_classes_values, function(nm) P(sim)[[nm]])
 #  names(inapplicable_classes_list) <- inapplicable_classes_values
 #  inapplicable_classes_list
 # 
 #  # create water_classes_list
 # # Determine the number of water class objects
 # num_water_classes <- length(grep("^water_class_land_cover\\d+$", names(P(sim))))
 # cat("Detected", num_water_classes, "LC products with water class(es).\n")
 # 
 # # Generate a vector of water class objects
 # water_classes_values <- paste0("water_class_land_cover", seq_len(num_water_classes))
 # cat(paste(water_classes_values, collapse = ", "), "\n")
 # 
 # # Retrieve water classes by their names and store them in a list
 # water_classes_list <- lapply(water_classes_values, function(nm) P(sim)[[nm]])
 # names(water_classes_list) <- water_classes_values
 # water_classes_list

 sim$color_mapping_list <- get_color_mapping_per_product(
   weighted_mean_results = sim$weighted_mean_results,
   water_classes_list = P(sim)$water_classes_list
 )

classProportionChart(
  weighted_mean_results = sim$weighted_mean_results,
  class_proportions_list = sim$class_proportions_list,
  list_of_land_cover_names = P(sim)$list_of_land_cover_names,
  water_classes_list = P(sim)$water_classes_list,
  color_mapping_list = sim$color_mapping_list,
  threshold = 5.5,
  output_dir = file.path(
    module_output_dir,
    "figures",
    "pie_charts"
  )
)


 #CLASS-MEAN BAR PLOTS

 # abbr_param_names <- grep(
 #   "^abbr_land_cover\\d+$",
 #   names(P(sim)),
 #   value = TRUE
 # )
 # 
 # cat("Detected", length(abbr_param_names), "abbreviation tables:\n")
 # cat(paste(abbr_param_names, collapse = ", "), "\n")
 # 
 # abbrev_list <- lapply(
 #   abbr_param_names,
 #   function(nm) P(sim)[[nm]]
 # )
 # 
 # names(abbrev_list) <- abbr_param_names

 # ------------------------------------------------------------
 # Sanity checks
 # ------------------------------------------------------------
 stopifnot(
   length(P(sim)$abbrev_list) == length(P(sim)$list_of_land_cover_names),
   length(P(sim)$abbrev_list) == length(sim$weighted_mean_results),
   length(P(sim)$abbrev_list) == length(P(sim)$water_classes_list),
   length(P(sim)$abbrev_list) == length(P(sim)$inapplicable_classes_list)
 )

 # ------------------------------------------------------------
 # Create biomass bar plots
 # ------------------------------------------------------------
 createBarplots(
   weighted_mean_results     = sim$weighted_mean_results,
   list_of_land_cover_names  = P(sim)$list_of_land_cover_names,
   water_classes_list        = P(sim)$water_classes_list,
   inapplicable_classes_list = P(sim)$inapplicable_classes_list,
   color_mapping_list        = sim$color_mapping_list,
   abbrev_list               = P(sim)$abbrev_list,
   measure_name              = P(sim)$measure_name,
   unit                      = P(sim)$unit,
   output_dir = file.path(module_output_dir, "figures", "barplots")
 )




################################################################################
#####                     STEP3 : Map(s) generation                       ######
################################################################################


 # Directory where gva rasters are stored
 gva_raster_dir <- file.path(module_output_dir, "gva_rasters")
 # Defined here, unconditionally, rather than only inside the "needs alignment"
 # branch below: STEP5 reads it whenever >1 land cover product is CONFIGURED,
 # while that branch is entered based on how many .tif files are actually on
 # disk. Those two conditions can disagree (e.g. a partially written output
 # folder), which would leave aligned_raster_dir undefined at its point of use.
 aligned_raster_dir <- file.path(module_output_dir, "aligned_gva_rasters")
 # Check which land cover gva rasters are missing
 missing_gva_raster <- vector()
 for (lc_name in P(sim)$list_of_land_cover_names) {
   # pattern for this land cover (any X)
   pattern <- paste0("land_cover\\d+_", lc_name, "\\.tif$")
   # see if any file exists
   if (length(list.files(gva_raster_dir, pattern = pattern, full.names = TRUE)) == 0) {
     missing_gva_raster <- c(missing_gva_raster, lc_name)
   }
 }
 # Run conversion only for missing gva rasters
 if (length(missing_gva_raster) > 0) {
   message("🪓 Missing gva rasters for: ", paste(missing_gva_raster, collapse = ", "),
           " — converting land cover to gva...")

   convertCroppedLandCoverToGVAMap(
     output_dir_in  = file.path(module_output_dir, "cropped_land_cover_products"),
     output_dir_out = gva_raster_dir,
     weighted_mean_results = sim$weighted_mean_results,
     inapplicable_classes_list = P(sim)$inapplicable_classes_list,
     list_of_land_cover_names = P(sim)$list_of_land_cover_names
   )

 } else {
   message("✅ All GVA rasters already exist — skipping conversion step.")
 }


 # GVA MAPS ALIGNMENT (if multiple land cover products are used)

 gva_paths <- list.files(
   gva_raster_dir,
   pattern = "\\.tif$",
   full.names = TRUE
 )

 num_gva_rasters <- length(gva_paths)

 cat("Detected", num_gva_rasters, "GVA raster(s).\n")

 if (num_gva_rasters <= 1) {

   message(
     "✅ Only ",
     num_gva_rasters,
     " GVA raster detected — alignment not required."
   )

 } else {


 # (aligned_raster_dir is now defined unconditionally further up, next to
 # gva_raster_dir -- see the note there.)
 # Check which aligned rasters are missing
 missing_aligned_raster <- vector()
 for (lc_name in P(sim)$list_of_land_cover_names) {
   # pattern for this land cover (any X)
   pattern <- paste0("aligned_gva_raster_land_cover\\d+_", lc_name, "\\.tif$")
   # see if any file exists
   if (length(list.files(aligned_raster_dir, pattern = pattern, full.names = TRUE)) == 0) {
     missing_aligned_raster <- c(missing_aligned_raster, lc_name)
   }
 }
 # Run alignment only for missing rasters
 if (length(missing_aligned_raster) > 0) {
   message("🪓 Missing aligned gva rasters for: ", paste(missing_aligned_raster, collapse = ", "),
           " — aligning gva rasters...")

   alignGVARasters(
     output_dir_in  = file.path(module_output_dir, "gva_rasters"),
     output_dir_out = aligned_raster_dir,
     study_area_path = sim$study_area_path,
     list_of_land_cover_names = P(sim)$list_of_land_cover_names
   )

 } else {
   message("✅ All aligned GVA rasters already exist — skipping alignment step.")
 }

}

################################################################################
#####           STEP4 : 10-FOLD CROSS-VALIDATION - GVA RASTERS            ######
################################################################################

 # The ensemble map (STEP5) weights the land cover products by their SMAPE, so the
 # cross-validation can only be skipped when there is a single product.
 run_cv <- isTRUE(P(sim)$run_cross_validation) ||
           length(P(sim)$list_of_land_cover_names) > 1

 if (!run_cv) {

   message("⏭️  run_cross_validation = FALSE and a single land cover product — ",
           "skipping the k-fold cross-validation.")
   sim$smape_results <- NULL

 } else {

 sim$smape_results <- runGVARastersKFoldCrossValidation(
   dataset_list = sim$dataset_list,
   class_proportions_list = sim$class_proportions_list,
   list_of_land_cover_names = P(sim)$list_of_land_cover_names,
   inapplicable_classes_list = P(sim)$inapplicable_classes_list,
   seed = P(sim)$seed,
   n_folds = P(sim)$n_folds,
   min_plots_per_class = 1,
   sample_fraction = 0.7,
   output_dir_fold = file.path(module_output_dir, "cross_validation_results", "folds"),
   output_dir_cropped = file.path(module_output_dir, "cropped_land_cover_products"),
   output_dir_out = file.path(module_output_dir, "cross_validation_results"),
   measure_class = P(sim)$measure_class,
   measure_name = P(sim)$measure_name,
   unit = P(sim)$unit
)

 }


 ################################################################################
 ##### STEP4b : RESAMPLE GVA RASTERS TO 250 m (FOR VISUALIZATION)          ######
 ################################################################################
 ## Moved OUT of the STEP5 "> 1 land cover product" branch below. It has to run
 ## for any number of products, because `visual_gva_dir` is assigned to
 ## sim$gva_rasters_250m_dir AFTER that branch closes -- leaving it undefined in
 ## the single-product case is what produced "object 'visual_gva_dir' not found".
 ##
 ## Source directory depends on how many products there are: with several, STEP3
 ## has written an aligned stack to aligned_gva_rasters/; with a single product
 ## there is nothing to align, so the raster STEP2 wrote to gva_rasters/ is used
 ## directly. That way a single-product run still gets its 250 m map.

 message("\n\U0001F5FA Resampling GVA rasters to 250 m for visualization...")

 # Input: full-resolution GVA rasters (the aligned ones when there are several)
 if (length(P(sim)$list_of_land_cover_names) > 1) {
   aligned_gva_dir <- file.path(module_output_dir, "aligned_gva_rasters")
 } else {
   aligned_gva_dir <- file.path(module_output_dir, "gva_rasters")
 }

 # Output: 250 m visualization rasters
 visual_gva_dir <- file.path(module_output_dir, "aligned_gva_rasters_250m")
 dir.create(visual_gva_dir, recursive = TRUE, showWarnings = FALSE)

 # List the GVA rasters to aggregate
 gva_files <- list.files(
   aligned_gva_dir,
   pattern = "\\.tif$",
   full.names = TRUE
 )

 # Expected 250 m filenames
 gva_files_250m <- file.path(
   visual_gva_dir,
   paste0("250m_", basename(gva_files))
 )

 if (length(gva_files) == 0) {

   message("\u2139\uFE0F No GVA rasters found in:\n  ", aligned_gva_dir,
           "\n   Skipping the 250 m resampling step.")

 } else if (!all(file.exists(gva_files_250m))) {

   message("\U0001F504 Creating 250 m GVA rasters (mean aggregation)...")

   for (i in seq_along(gva_files)) {

     gva_r <- terra::rast(gva_files[i])

     # Compute aggregation factor
     # Assumes original raster is in meters and resolution divides 250 exactly
     fact <- round(250 / terra::res(gva_r)[1])

     if (fact < 1) {
       stop("Original raster resolution is already coarser than 250 m.")
     }

     # Aggregate (mean for continuous variables)
     gva_250 <- terra::aggregate(
       gva_r,
       fact = fact,
       fun = mean,
       na.rm = TRUE
     )

     terra::writeRaster(
       gva_250,
       gva_files_250m[i],
       overwrite = TRUE,
       wopt = list(gdal = c("COMPRESS=DEFLATE", "TILED=YES"))
     )
   }

   message("\u2705 250 m visualization rasters created.")

 } else {

   message("\u2705 250 m visualization rasters already exist \u2014 skipping.")
 }

 gva_250m_files <- gva_files_250m


 ################################################################################
 #####     STEP5 : ENSEMBLE AND UNCERTAINTY MAPS (if > 1 lc product)       ######
 ################################################################################

 if (length(P(sim)$list_of_land_cover_names) > 1) {

 smape_results <- sim$smape_results
 cat("\n Ensemble raster inputs preparation:\n")
 raster_dir = aligned_raster_dir
 output_dir_out = file.path(module_output_dir, "gva_rasters")

 # --- Detect environment and set cores ---
 if (nzchar(Sys.getenv("SLURM_JOB_ID"))) {
   ncores <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", unset = 1))
   cat(sprintf("  Detected SLURM environment: using %d cores\n", ncores))
 } else {
   ncores <- max(1, parallel::detectCores() - 1)
   cat(sprintf("  Detected local environment: using %d cores\n", ncores))
 }
 flush.console()

 # --- Ensure ensemble map output folder exists ---
 if (!dir.exists(output_dir_out)) {
   dir.create(output_dir_out, recursive = TRUE)
   cat("Created ensemble map folder:", output_dir_out, "\n")
 } else {
   cat("ℹ️ Ensemble map folder already exists:", output_dir_out, "\n")
 }

 # --- Load all rasters ---
 raster_files <- list.files(raster_dir, pattern = "\\.tif$", full.names = TRUE)
 if (length(raster_files) == 0) stop("No raster files found in: ", raster_dir)

 message("✅ Loading ", length(raster_files), " rasters from ", raster_dir)
 aligned_gva_rasters <- lapply(raster_files, terra::rast)
 raster_names <- tools::file_path_sans_ext(basename(raster_files))
 names(aligned_gva_rasters) <- raster_names

 # --- Stack rasters ---
 rasters_stack <- terra::rast(aligned_gva_rasters)

 # ### NEW: Use SMAPE for weights
 smape_values <- smape_results$SMAPE
 names(smape_values) <- raster_names

 # # Remove NA or zero SMAPE to avoid division by zero
 valid_idx <- which(!is.na(smape_values) & smape_values > 0) # <-- NEW


 if (length(valid_idx) == 0) {
   stop("No rasters with valid SMAPE found for ensemble weighting.")
 }

 ### Compute inverse-squared SMAPE weights <== SMAPE
 inv_sq_smape <- 1 / (smape_values[valid_idx]^2)
 weights <- inv_sq_smape / sum(inv_sq_smape)

 # ------------------------------------------------------------
 # filter rasters with more than 10% weight
 # ------------------------------------------------------------
 keep_idx <- which(weights > 0.10)

 if (length(keep_idx) == 0) {
   stop("No rasters have weights > 10%.")
 }

 # Keep only rasters above 10% weight
 rasters_stack_valid <- rasters_stack[[valid_idx]][[keep_idx]]
 weights <- weights[keep_idx]
 weights <- weights / sum(weights)   # <---- IMPORTANT

 smape_values <- smape_values[valid_idx][keep_idx]

 # Rename after filtering
 names(weights) <- names(rasters_stack_valid)
 # ------------------------------------------------------------

 # Print summary table
 cat("\n📊 Using the following rasters for ensemble:\n")
 print(data.frame(Raster = names(weights),
                  SMAPE = round(smape_values, 4),
                  Weight = round(weights, 4)))
 cat("\n")


 # Combine all plots into one data.frame
 df_plots <- do.call(rbind, sim$dataset_list)
 df_plots <- df_plots[!duplicated(df_plots$plotID), ]

 # Convert plots to SpatVector and project to raster CRS
 plot_pts <- terra::vect(df_plots, geom = c("longitude", "latitude"), crs = "EPSG:4326")
 plot_pts <- terra::project(plot_pts, crs(rasters_stack_valid))

 # Extract values from all rasters involved in the ensemble
 pred_matrix <- terra::extract(rasters_stack_valid, plot_pts)[, -1]  # drop ID column

 # Compute weighted ensemble prediction for each plot point
 ensemble_pred <- apply(pred_matrix, 1, function(x) {
   ok <- !is.na(x)
   if (!any(ok)) return(NA)
   sum(x[ok] * weights[ok]) / sum(weights[ok])
 })

 # --- Create template raster filled with NA ---
 template <- rasters_stack_valid[[1]]
 template[] <- NA

 # Get cell numbers for each plot location
 plot_cells <- terra::cellFromXY(template, terra::geom(plot_pts)[, c("x", "y")])

 # Fill only those cells with ensemble predictions
 template[plot_cells] <- ensemble_pred

 # create folder for sparse raster if it doesn't exist
 sparse_raster_dir <- file.path(module_output_dir, "cross_validation_results", "folds", "ensemble_raster_sparse")
 if (!dir.exists(sparse_raster_dir)) {
   dir.create(sparse_raster_dir, recursive = TRUE)
   cat("Created folder for sparse ensemble raster:", sparse_raster_dir, "\n")
 } else {
   cat("ℹ️ Folder for sparse ensemble raster already exists:", sparse_raster_dir, "\n")
 }

 # Save sparse raster
 terra::writeRaster(
   template,
   filename = file.path(sparse_raster_dir, "ensemble_raster_sparse.tif"),
   overwrite = TRUE
 )

 message("\n🎯 Ensemble raster created (only plot pixels have values for validation)\n")



 # ------------------------------------------------------------
 # 10-FOLD CROSS-VALIDATION - ENSEMBLE MAP
 # ------------------------------------------------------------
 sim$ensemble_mean_SMAPE <- runEnsembleKFoldCrossValidation(
   dataset_list = sim$dataset_list,
   output_dir_in = sparse_raster_dir,
   output_dir_out = file.path(module_output_dir, "cross_validation_results"),
   seed = P(sim)$seed,
   n_folds = P(sim)$n_folds,
   holdout_ratio = 0.3
 )


 ################################################################################
 ##### WALL-TO-WALL ENSEMBLE RASTER (250 m, for visualization)
 ################################################################################

 ensemble_full_dir <- file.path(module_output_dir, "ensemble")
 dir.create(ensemble_full_dir, recursive = TRUE, showWarnings = FALSE)

 ensemble_full_path <- file.path(
   ensemble_full_dir,
   "full_ensemble_gva_250m.tif"
 )

 if (length(gva_250m_files) == 0) {

   message("ℹ️ No 250 m GVA rasters were produced — skipping the 250 m ensemble.")

 } else if (!file.exists(ensemble_full_path)) {

   message("🧮 Computing 250 m visualization ensemble from aggregated products")

   # gva_250m_files are the paths STEP4b constructed; non-empty by the check above
   rasters_stack_250m <- terra::rast(gva_250m_files)

   #stopifnot(all(names(rasters_stack_250m) %in% names(weights)))

   weights_250 <- weights
   #weights_250 <- weights[names(rasters_stack_250m)]
   #weights_250 <- weights_250 / sum(weights_250)

   ensemble_raster_250m <- terra::app(
     rasters_stack_250m,
     fun = function(x) {
       ok <- !is.na(x)
       if (!any(ok)) return(NA_real_)
       sum(x[ok] * weights_250[ok]) / sum(weights_250[ok])
     }
   )

   names(ensemble_raster_250m) <- "ensemble_gva"

   terra::writeRaster(
     ensemble_raster_250m,
     ensemble_full_path,
     overwrite = TRUE,
     wopt = list(gdal = c("COMPRESS=DEFLATE", "TILED=YES"))
   )

   message("✅ 250 m ensemble raster created")

 } else {
   message("✅ 250 m ensemble raster already exists — skipping")
 }

 ################################################################################
 #####          CV RASTER
 ################################################################################

 message("\n📉 Creating CV raster...")


   #--------------------------------------------------
   # Input: aligned rasters (same extent / resolution)
   #--------------------------------------------------
 input_raster_dir <- visual_gva_dir #aligned_raster_dir #for 250m CV raster

 # List aligned raster files
 raster_files <- list.files(
   input_raster_dir,
   pattern = "\\.tif$",
   full.names = TRUE
 )

 # Build list of SpatRaster objects
 weighted_mean_raster <- lapply(raster_files, terra::rast)

 #--------------------------------------------------
 # Output directory
 #--------------------------------------------------
 cv_raster_dir <- file.path(
   module_output_dir,
   "cv_raster"
 )
 dir.create(cv_raster_dir, recursive = TRUE, showWarnings = FALSE)

 #--------------------------------------------------
 # Convert list → SpatRaster stack (INTENTIONAL)
 # Required because terra::stdev() and mean()
 # do not operate on lists
 #--------------------------------------------------
 gva_stack <- terra::rast(weighted_mean_raster)

 #--------------------------------------------------
 # Compute CV = sd / mean (block-wise, disk-backed)
 #--------------------------------------------------
 cv_raster <- terra::stdev(gva_stack, na.rm = TRUE) /
   terra::mean (gva_stack,  na.rm = TRUE)

 names(cv_raster) <- "cv"

 #--------------------------------------------------
 # Save CV raster to disk
 #--------------------------------------------------
 cv_raster_path <- file.path(
   cv_raster_dir,
   "cv_raster.tif"
 )

 terra::writeRaster(
   cv_raster,
   cv_raster_path,
   overwrite = TRUE,
   wopt = list(
     gdal = c("COMPRESS=DEFLATE", "TILED=YES")
   )
 )

 message("✅ CV raster saved:\n  ", cv_raster_path)

 #--------------------------------------------------
 # Store only the path (no raster kept in memory)
 #--------------------------------------------------
 sim$cv_raster_path <- cv_raster_path



 } else {
   message("Ensemble and CV map skipped: only one land-cover product available")
 }





 # Store path (optional, useful downstream)
 sim$gva_rasters_250m_dir <- visual_gva_dir

  ################################################################################
 ##### STEP X : VISUALIZATION — 250 m GVA MAPS
 ################################################################################

 message("\n🗺 Creating water raster to be coupled with GVA rasters...")
 
 # ------------------------------------------------------------
 # WATER RASTER (250 m)
 # ------------------------------------------------------------
 water_raster_dir <- file.path(module_output_dir, "water_raster")
 
 if (!dir.exists(water_raster_dir)) {
   dir.create(water_raster_dir, recursive = TRUE)
 }
 
 water_raster_file <- file.path(water_raster_dir, "water_mask_250m.tif")
 
 # ------------------------------------------------------------
 # Use CROPPED land-cover rasters (critical fix ✅)
 # ------------------------------------------------------------
 cropped_lc_dir <- file.path(module_output_dir, "cropped_land_cover_products")
 
 land_cover_paths_cropped <- list.files(
   path = cropped_lc_dir,
   pattern = "\\.tif$",
   recursive = TRUE,
   full.names = TRUE
 )
 
 # Ensure it is a list (required by function)
 land_cover_paths_cropped <- as.list(land_cover_paths_cropped)
 
 # ------------------------------------------------------------
 # Create water raster only if needed
 # ------------------------------------------------------------
 if (!file.exists(water_raster_file)) {
   
   message("🌊 Water raster not found — creating water raster (250 m)...")
   
   sim$water_raster_path <- createWaterRaster250m(
     land_cover_paths   = land_cover_paths_cropped,
     water_classes_list = P(sim)$water_classes_list,
     output_dir         = water_raster_dir,
     target_res         = 250
   )
   
 } else {
   
   message("✅ Water raster already exists — reusing existing file.")
   
   sim$water_raster_path <- water_raster_file
 }
 
 message("\n🗺 Plotting 250 m GVA rasters...")
 

 # ------------------------------------------------------------------
 # Directories
 # ------------------------------------------------------------------
 visual_gva_dir <- file.path(module_output_dir, "aligned_gva_rasters_250m")

 ensemble_full_dir <- file.path(module_output_dir, "ensemble")
 ensemble_full_path <- file.path(
   ensemble_full_dir,
   "full_ensemble_gva_250m.tif"
 )

 fig_dir <- file.path(module_output_dir, "figures")
 dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

 # ------------------------------------------------------------------
 # List aligned 250 m individual GVA rasters
 # ------------------------------------------------------------------
 gva_250m_files <- list.files(
   visual_gva_dir,
   pattern = "\\.tif$",
   full.names = TRUE
 )

 # STEP4b now produces these for any number of land cover products (single
 # product included), so normally this folder is populated. An empty folder is
 # still tolerated rather than fatal -- e.g. if STEP2 wrote no GVA raster at all.
 if (length(gva_250m_files) == 0) {

   message("ℹ️ No 250 m GVA rasters found in:\n  ", visual_gva_dir,
           "\n   Nothing to plot — skipping the 250 m map figures.")

 } else {

 # ------------------------------------------------------------------
 # Build colour-scale rasters (include ensemble ONLY if it exists)
 # ------------------------------------------------------------------
 if (file.exists(ensemble_full_path)) {
   scale_rasters <- c(gva_250m_files, ensemble_full_path)
   message("ℹ️ Ensemble raster found — including it with individual GVA rasters.")
 } else {
   scale_rasters <- gva_250m_files
   message("ℹ️ Ensemble raster not found — using only individual GVA rasters")
 }

 # ------------------------------------------------------------------
 # Plot each individual GVA raster
 # ------------------------------------------------------------------
 for (r_path in gva_250m_files) {

   raster_name <- tools::file_path_sans_ext(basename(r_path))

   output_png <- file.path(
     fig_dir,
     paste0("map_", raster_name, ".png")
   )

   plotGVA250m(
     raster_to_plot        = r_path,
     raster_list_for_scale = scale_rasters,
     study_area_path       = sim$study_area_path,
     water_raster_path     = sim$water_raster_path,
     output_path           = output_png,
     title                 = raster_name,
     measure_name          = P(sim)$measure_name,
     unit                  = P(sim)$unit
   )
 }

 # ------------------------------------------------------------------
 # Plot ensemble raster ONLY if it exists
 # ------------------------------------------------------------------
 if (file.exists(ensemble_full_path)) {


   plotGVA250m(
     raster_to_plot        = ensemble_full_path,
     raster_list_for_scale = scale_rasters,
     study_area_path       = sim$study_area_path,
     water_raster_path     = sim$water_raster_path,
     output_path           = file.path(fig_dir, "map_ensemble_gva_250m.png"),
     title                 = "Ensemble GVA",
     measure_name          = P(sim)$measure_name,
     unit                  = P(sim)$unit
   )

 }

 message("✅ All available GVA maps plotted successfully.\n")

 }   # end of "there are 250 m aligned rasters to plot"

 #plot CV RASTER
 # The CV raster only exists when > 1 land cover product was supplied.
 if (!is.null(sim$cv_raster_path) && file.exists(sim$cv_raster_path)) {

   message("Plotting CV map....\n")
   plotCV250m(
     cv_raster_path     = sim$cv_raster_path,
     study_area_path    = sim$study_area_path,
     water_raster_path  = sim$water_raster_path,
     output_path        = file.path(fig_dir, "map_cv_gva_250m.png"),
     split_cv           = 0.2,
     title              = "Coefficient of Variation (250 m)"
   )

 } else {
   message("ℹ️ No CV raster (a single land cover product) — skipping the CV map.")
 }


  return(invisible(sim))
}
  




