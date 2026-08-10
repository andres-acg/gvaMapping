# ==============================================================================
# preprocessing.R
#
# Turns each raw plot dataset -- whatever form it originally comes in -- into
# gvaMapping's common preformatted schema:
#     plotID, quadID, gva, measure_quad, latitude, longitude, sample_date
# One CSV per dataset, written once to inputs/datasets/<datasetN>/, then
# reused on every later run. The build-once driver loop lives in
# globalscript_backcasting.R, not here -- this file only defines functions.
#
# Two kinds of raw dataset:
#   - COVER data (percent cover recorded in the field): needs converting to
#     biomass before it matches gvaMapping's schema. That conversion --
#     the Greuel & Degre-Timmons et al. (2021) pooled Cladonia spp.
#     allometric equation -- is convertCoverToLichenBiomass() below. It is
#     written to be reusable on its own, independently of gvaMapping, e.g.
#     for preparing training data to refit Greuel et al.'s (2021) hurdle
#     model.
#   - BIOMASS data (already kg/ha or directly convertible to it): just needs
#     renaming/reshaping to the common schema. No Greuel equation involved.
#
# Per-dataset loader functions below only do the format-specific reading and
# reshaping (every raw file is a different shape -- that part cannot be
# generalised). They deliberately do NOT do unit conversion or renaming to
# the gva/measure_quad schema -- that happens centrally, in
# convertCoverToLichenBiomass() / formatBiomassForGvaMapping(), so there is
# only one place to check or fix the actual science.
# ==============================================================================

packages <- c("sf", "dplyr", "readxl", "tidyr", "lubridate")
missing_packages <- packages[!(packages %in% installed.packages()[, "Package"])]
if (length(missing_packages) > 0) install.packages(missing_packages)
lapply(packages, library, character.only = TRUE)


###############################################################################
## SHARED: cover (%) -> lichen biomass conversion
###############################################################################

## Patterns identifying Cladonia spp. records in the pooled sense Greuel et
## al. (2021) fit their model to: C. mitis/arbuscula, C. rangiferina/stygia,
## C. stellaris, C. uncialis/amaurocrea. Covers every species-abbreviation
## scheme seen across our raw datasets (Deninu's and Cook's own data are
## already pooled to "Cladonia spp." directly and don't go through this).
##
## Deliberately does NOT match bare "Cladonia"/"Cladina" (genus-level, no
## species given). Baltzer et al.'s field protocol records lichen ground
## cover under five categories, one of which is literally "Cladonia sp." --
## but per ANCAG6 (pers. comm.), that category is cup lichen, a different
## growth form from the fruticose "reindeer lichens" (Cladina mitis/
## arbuscula, C. rangiferina/stygia, C. stellaris, C. uncialis/amaurocrea)
## that are both the actual caribou forage species AND what Greuel et al.
## (2021) fit their pooled allometric equation to. Pooling cup lichen cover
## into that equation would apply a biomass-per-cover coefficient calibrated
## on a different growth form to it, so bare "Cladonia"/"Cladina" records
## are excluded here on purpose, not by omission. "spp\\." is still matched
## because it identifies rows already pooled to the literal label
## "Cladonia spp." elsewhere in this file (loadNFICoverData()'s zero-cover
## placeholder rows), not raw field taxon names.
DEFAULT_CLADONIA_PATTERN <- paste(
  c("mitis", "Cladmit", "\\bMIT\\b", "CLMI",
    "arbuscula", "Cladarb", "\\bARB\\b",
    "rangiferina", "Cladran", "\\bRAN\\b", "CLRA",
    "stygia", "Cladsty", "\\bSTY\\b",
    "stellaris", "Cladste", "\\bSTE\\b", "CLST",
    "uncialis", "Cladunc", "\\bunc\\b", "CLADUNC",
    "amaurocrea", "Cladama", "\\bAMA\\b",
    "spp\\."),
  collapse = "|"
)

#' Convert a long-format cover (percent cover) table into lichen biomass
#'
#' Standalone and gvaMapping-agnostic on purpose: this is also the function
#' to use for preparing training data to refit Greuel et al.'s (2021) hurdle
#' model on additional/other plot data.
#'
#' @param df data.frame, one row per plotID x quadID x recorded category,
#'   with columns plotID, quadID, species, percent, latitude, longitude,
#'   sample_date. Not pre-filtered to Cladonia -- this function does that
#'   itself, so the same raw long table can be handed in unfiltered.
#' @param sampling_size_m2 single numeric: the quadrat/plot area (m2) `df`'s
#'   percent-cover values were recorded over.
#' @param target_pattern regex (OR-joined) identifying which `species`
#'   values count as Cladonia spp. for Greuel et al.'s pooled model.
#'   Defaults to DEFAULT_CLADONIA_PATTERN above.
#'
#' @return one row per plotID x quadID: plotID, quadID, species
#'   ("Cladonia spp."), biomass_dens_quad (kg/ha), biomass_quad (kg per
#'   quadrat), sampling_size_m2, latitude, longitude, sample_date.
convertCoverToLichenBiomass <- function(df, sampling_size_m2,
                                        target_pattern = DEFAULT_CLADONIA_PATTERN) {

  stopifnot(all(c("plotID", "quadID", "species", "percent",
                  "latitude", "longitude", "sample_date") %in% names(df)))

  df$percent <- as.numeric(df$percent)
  df$isCladonia <- grepl(target_pattern, df$species, ignore.case = TRUE)

  message(sprintf(
    "convertCoverToLichenBiomass(): %d / %d rows matched as Cladonia spp. (pattern-matched species: %s)",
    sum(df$isCladonia), nrow(df),
    paste(sort(unique(df$species[df$isCladonia])), collapse = ", ")))

  out <- df %>%
    dplyr::group_by(plotID, quadID) %>%
    dplyr::summarise(
      percent_cladonia = sum(percent[isCladonia], na.rm = TRUE),
      latitude    = dplyr::first(latitude),
      longitude   = dplyr::first(longitude),
      sample_date = dplyr::first(sample_date),
      .groups = "drop"
    )

  ## Greuel & Degre-Timmons et al. (2021) pooled allometric equation for
  ## Cladonia spp.: cover fraction -> m2 of cover per ha -> kg/ha via the
  ## fitted coefficient 0.06213 (kg per m2 of cover), then x10 for the
  ## per-m2 -> per-ha unit conversion. biomass_quad additionally scales that
  ## density down to the actual quadrat/plot area sampled.
  out <- out %>%
    dplyr::mutate(
      species           = "Cladonia spp.",
      areaperaream2     = (percent_cladonia / 100) * 10000,
      biomass_dens_quad = areaperaream2 * 0.06213 * 10,   # kg/ha
      sampling_size_m2  = sampling_size_m2,
      biomass_quad      = biomass_dens_quad * (sampling_size_m2 / 10000)
    ) %>%
    dplyr::select(plotID, quadID, species, biomass_dens_quad, biomass_quad,
                  sampling_size_m2, latitude, longitude, sample_date)

  out
}

#' Rename convertCoverToLichenBiomass()'s output (or any biomass_dens_quad-
#' bearing table) to gvaMapping's expected preformatted schema: plotID,
#' quadID, gva, measure_quad, latitude, longitude, sample_date.
#' measure_quad = biomass_dens_quad (kg/ha), matching measure_class =
#' "intensive" in globalscript_backcasting.R (values already per unit area).
formatBiomassForGvaMapping <- function(df, valueCol = "biomass_dens_quad",
                                       gvaLabel = "Cladonia spp.") {
  stopifnot(valueCol %in% names(df))
  df$gva <- gvaLabel
  df$measure_quad <- df[[valueCol]]
  df[, c("plotID", "quadID", "gva", "measure_quad",
        "latitude", "longitude", "sample_date")]
}


###############################################################################
## Dataset-specific loaders. Reading + reshaping ONLY -- no unit conversion,
## no gva/measure_quad renaming. loadBaltzerCoverData(), loadErringtonCoverData()
## and loadNFICoverData() return a long cover table (plotID, quadID, species,
## percent, latitude, longitude, sample_date) meant for
## convertCoverToLichenBiomass(). loadCookBiomassData() and
## loadDeninuBiomassData() are already biomass (kg/ha) and return the final
## gva/measure_quad schema directly.
###############################################################################

# ------------------------------------------------------------------
# Baltzer et al. -- cover data, two semicolon-delimited CSVs
# (cover: plot;quadrat;plot.quadrat;attribute;percent;depth.live;depth.total;notes
#  site:  plot;...;date;...;Lat_start;Long_start;...)
# ------------------------------------------------------------------
loadBaltzerCoverData <- function(raw_cover_path, raw_site_path) {

  df_cover <- read.csv2(raw_cover_path, header = TRUE, sep = ";")
  df_site  <- read.csv2(raw_site_path, header = TRUE, sep = ";")

  df_clean <- df_cover %>%
    dplyr::left_join(df_site %>% dplyr::select(plot, Lat_start, Long_start, date),
                     by = "plot") %>%
    dplyr::rename(
      plotID      = plot,
      quadID      = plot.quadrat,
      species     = attribute,
      latitude    = Lat_start,
      longitude   = Long_start,
      sample_date = date
    ) %>%
    dplyr::select(plotID, quadID, species, percent, latitude, longitude, sample_date)

  df_clean$sample_date <- lubridate::ymd(df_clean$sample_date)

  message("Baltzer et al.: ", length(unique(df_clean$plotID)), " plots, ",
         nrow(df_clean), " plotID x quadID x attribute rows loaded.")
  df_clean
}

# ------------------------------------------------------------------
# Errington et al. -- cover data, two sheets of the same Excel workbook
# ("lichen cover" sheet: Time, Plot, Quadrat, Q ID, <89 species columns>;
#  "Plot info" sheet: header on row 2, T1 and T2 measurement dates as
#  duplicate Month/Day/Year columns, readxl-suffixed "...12"/"...13"/"...14"
#  for the T2 block used here)
# ------------------------------------------------------------------
loadErringtonCoverData <- function(raw_path,
                                   cover_sheet = "lichen cover",
                                   site_sheet  = "Plot info",
                                   time_filter = "T2") {

  ## i. cover sheet: keep only Greuel's target Cladonia columns + IDs, then
  ##    reshape wide (one column per species) -> long (one row per species)
  lichen_species <- c("Cladama", "Cladarb", "Cladmit", "Cladran",
                      "Cladste", "Cladsty", "Cladunc")

  df_cover <- readxl::read_excel(raw_path, sheet = cover_sheet)
  df_cover <- df_cover[df_cover$Time == time_filter, c("Plot", "Q ID", lichen_species)]
  df_cover <- tidyr::pivot_longer(df_cover, cols = dplyr::all_of(lichen_species),
                                  names_to = "species", values_to = "percent")

  ## ii. site sheet: header is on row 2 (row 1 is a merged T1/T2 label row);
  ##     "Plot" and "pname" both identify a plot in this sheet -- "pname" is
  ##     the one whose values actually match the cover sheet's "Plot" column
  ##     (e.g. "FS 2 CS", not "FS 02 CS"), so it replaces "Plot" here.
  df_site <- readxl::read_excel(raw_path, sheet = site_sheet, skip = 1)
  df_site <- df_site[, -which(colnames(df_site) == "Plot")]
  if ("pname" %in% names(df_site)) {
    names(df_site)[names(df_site) == "pname"] <- "Plot"
  }

  df_site$Day...13   <- as.numeric(trimws(gsub(" .*", "", df_site$Day...13)))
  df_site$Month...12 <- tools::toTitleCase(tolower(df_site$Month...12))
  Sys.setlocale("LC_TIME", "C")
  df_site$sample_date <- as.Date(
    with(df_site, paste(Day...13, Month...12, Year...14)),
    format = "%d %B %Y"
  )
  df_site <- df_site[, c("Plot", "DDlat", "DDlong", "sample_date")]

  ## iii. merge and rename
  df_clean <- merge(df_cover, df_site, by = "Plot") %>%
    dplyr::rename(plotID = Plot, quadID = `Q ID`,
                  latitude = DDlat, longitude = DDlong) %>%
    dplyr::select(plotID, quadID, species, percent, latitude, longitude, sample_date)

  message("Errington et al.: ", length(unique(df_clean$plotID)), " plots, ",
         nrow(df_clean), " plotID x quadID x species rows loaded (", time_filter, " only).")
  df_clean
}

# ------------------------------------------------------------------
# NFI ground plots -- cover data, two CSVs, UTM coordinates
# (species/cover file: nfi_plot, meas_date, plot_type, ec_genus, ec_species,
#  ec_species_pct; site file: nfi_plot, meas_date, province, utm_n, utm_e,
#  utm_zone)
# ------------------------------------------------------------------
loadNFICoverData <- function(raw_species_path, raw_site_path, province_filter = "NT") {

  ground_cover     <- read.csv(raw_species_path)
  ground_cover_loc <- read.csv(raw_site_path)

  convert_utm_to_latlon <- function(df_zone) {
    zone_number <- unique(df_zone$utm_zone)
    if (length(zone_number) != 1) stop("Multiple UTM zones in one subset")
    epsg_code <- 32600 + as.integer(zone_number)   # northern hemisphere UTM
    df_sf     <- sf::st_as_sf(df_zone, coords = c("utm_e", "utm_n"), crs = epsg_code)
    df_latlon <- sf::st_transform(df_sf, crs = 4326)
    coords    <- sf::st_coordinates(df_latlon)
    df_zone$longitude <- coords[, 1]
    df_zone$latitude  <- coords[, 2]
    df_zone
  }

  NFI_loc <- ground_cover_loc %>%
    dplyr::group_split(utm_zone) %>%
    lapply(convert_utm_to_latlon) %>%
    dplyr::bind_rows()

  ## meas_date exists in both files -> becomes meas_date.x (cover) /
  ## meas_date.y (site) after the join; meas_date.y (the site file's date) is
  ## what gets used below, matching the original intent.
  NFI_data <- dplyr::inner_join(ground_cover, NFI_loc, by = "nfi_plot")
  NFI_data <- NFI_data[NFI_data$province %in% province_filter, ]

  NFI_data <- NFI_data[, c("nfi_plot", "plot_type", "meas_date.y",
                           "ec_genus", "ec_species", "ec_species_pct",
                           "longitude", "latitude")]
  Sys.setlocale("LC_TIME", "C")
  NFI_data$sample_date <- as.Date(NFI_data$meas_date.y, format = "%Y-%b-%d")

  lichen_species <- c("MIT", "ARB", "RAN", "STY", "STE", "unc", "AMA")
  NFI_data_clad <- NFI_data %>%
    dplyr::filter(ec_genus %in% c("Clad", "CLAD") | ec_species %in% lichen_species)

  ## Plots with no Cladonia record at all get an explicit 0% row, so they
  ## contribute a real zero observation instead of silently disappearing
  ## from the dataset.
  missing_clad <- NFI_data %>%
    dplyr::filter(!(nfi_plot %in% NFI_data_clad$nfi_plot)) %>%
    dplyr::distinct(nfi_plot, .keep_all = TRUE) %>%
    dplyr::select(nfi_plot, latitude, longitude, sample_date) %>%
    dplyr::mutate(ec_species_pct = 0, plot_type = NA_character_,
                 ec_genus = NA_character_, ec_species = "Cladonia spp.")

  df_clean <- dplyr::bind_rows(NFI_data_clad, missing_clad) %>%
    dplyr::mutate(ec_species_pct = ifelse(ec_species_pct < 0, 0, ec_species_pct)) %>%
    dplyr::select(plotID = nfi_plot, quadID = plot_type, species = ec_species,
                 percent = ec_species_pct, latitude, longitude, sample_date)

  message("NFI (", paste(province_filter, collapse = "/"), "): ",
         length(unique(df_clean$plotID)), " plots, ", nrow(df_clean), " rows loaded.")
  df_clean
}

# ------------------------------------------------------------------
# Cook et al. -- biomass data (already kg/ha), two Excel workbooks
# (biomass workbook, "byplot_kgha " sheet: header row 1, rows 2-3 are
#  functional-group/origin code rows (not data), YEAR/DY/M/ID/PLOT + 365
#  species columns; site workbook, "Macroplot data" sheet: row 1 is a
#  merged-cell label row, row 2 is the real header: ID, GPSLAT, GPSLONG)
# ------------------------------------------------------------------
loadCookBiomassData <- function(raw_biomass_path, raw_site_path) {

  df_biomass <- readxl::read_excel(raw_biomass_path, sheet = "byplot_kgha ",
                                   .name_repair = "minimal")
  df_site    <- readxl::read_excel(raw_site_path, sheet = "Macroplot data",
                                   .name_repair = "minimal")

  ## columns 8+ are species; rows 2-3 (functional-group/origin codes, not
  ## numeric data) get coerced to NA here, which is what strips them out
  ## downstream once fiveColumns drops them explicitly.
  df_biomass[, 8:ncol(df_biomass)] <- sapply(df_biomass[, 8:ncol(df_biomass)], as.numeric)

  ## Per Cook (pers. comm.): these specific plots' raw lichen values need
  ## /4 to correct a known measurement-protocol difference.
  specificPlots  <- c(11:24, "M1", "M2", "M3", "M4", "M5", "M6")
  lichen_species <- c("CLMI", "CLRA", "CLST", "CLADUNC")
  df_biomass[df_biomass$ID %in% specificPlots, lichen_species] <-
    df_biomass[df_biomass$ID %in% specificPlots, lichen_species] / 4

  fiveColumns <- data.frame(df_biomass[, c("YEAR", "DY", "M", "ID", "PLOT")])
  fiveColumns <- fiveColumns[-c(1, 2), ]   # drop the two code rows

  new_fiveColumns <- fiveColumns[rep(seq_len(nrow(fiveColumns)),
                                     each = length(lichen_species)), ]
  rownames(new_fiveColumns) <- NULL

  ## NOTE: deliberately kept as tidyr::gather(), not pivot_longer() --
  ## gather() melts column-major (all species for plot 1, then all species
  ## for plot 2, ...), which is what the rep(rownames(...), ncol(...)) line
  ## right above assumes. pivot_longer() melts row-major instead and would
  ## silently mismatch the species labels against the wrong plots if swapped
  ## in here without also reworking that alignment.
  lichenColumns_transp  <- as.data.frame(t(df_biomass[, lichen_species]))
  df_biomass_transposed <- as.data.frame(lichenColumns_transp[-c(1, 2)])
  df_biomass_long <- tidyr::gather(df_biomass_transposed, key = "temp", value = "Biomass_Kg_ha")
  df_biomass_long$Species <- rep(rownames(df_biomass_transposed), ncol(df_biomass_transposed))
  df_biomass_long <- df_biomass_long[, c("Species", "Biomass_Kg_ha")]

  df_biomass_structured <- cbind(new_fiveColumns, df_biomass_long)
  rownames(df_biomass_structured) <- NULL

  new_header <- as.character(unlist(df_site[1, ]))
  df_site <- df_site[-1, ]
  colnames(df_site) <- new_header
  site_coords <- data.frame(df_site[, c("ID", "GPSLAT", "GPSLONG")])
  site_coords$GPSLAT  <- as.numeric(site_coords$GPSLAT)
  site_coords$GPSLONG <- as.numeric(site_coords$GPSLONG)

  df_biomass_with_coords <- merge(df_biomass_structured, site_coords, by = "ID", all.x = TRUE)
  df_biomass_with_coords$Biomass_Kg_ha <- as.numeric(df_biomass_with_coords$Biomass_Kg_ha)
  ## x1.56: corrects to 64% living biomass, scaling to be comparable with
  ## Baltzer et al.'s data.
  df_biomass_with_coords$Biomass_Kg_ha <- df_biomass_with_coords$Biomass_Kg_ha * 1.56
  df_biomass_with_coords <- df_biomass_with_coords[!is.na(df_biomass_with_coords$Biomass_Kg_ha), ]

  cladsSpecies <- c("CLMI", "CLRA", "CLADUNC", "CLST")
  df_biomass_with_coords <- subset(df_biomass_with_coords, Species %in% cladsSpecies)
  rownames(df_biomass_with_coords) <- NULL

  df_biomass_aggregated <- df_biomass_with_coords %>%
    dplyr::group_by(ID, PLOT) %>%
    dplyr::summarise(
      YEAR = dplyr::first(YEAR), DY = dplyr::first(DY), M = dplyr::first(M),
      GPSLAT = dplyr::first(GPSLAT), GPSLONG = dplyr::first(GPSLONG),
      Biomass_Kg_ha = sum(Biomass_Kg_ha, na.rm = TRUE), .groups = "drop"
    )

  df_biomass_aggregated$sample_date <- lubridate::ymd(sprintf(
    "%04d-%02d-%02d", df_biomass_aggregated$YEAR,
    df_biomass_aggregated$M, df_biomass_aggregated$DY))

  df_clean <- df_biomass_aggregated %>%
    dplyr::rename(plotID = ID, quadID = PLOT,
                  latitude = GPSLAT, longitude = GPSLONG) %>%
    dplyr::mutate(gva = "Cladonia spp.", measure_quad = Biomass_Kg_ha) %>%
    dplyr::select(plotID, quadID, gva, measure_quad, latitude, longitude, sample_date)

  message("Cook et al.: ", length(unique(df_clean$plotID)), " plots, ",
         nrow(df_clean), " rows loaded (already kg/ha, no cover conversion needed).")
  df_clean
}

# ------------------------------------------------------------------
# Deninu Kue First Nation et al. (2026) -- biomass data (already kg/ha),
# one Excel workbook from Zenodo. Unchanged logic from the original working
# version -- renamed only, for consistency with the other four loaders.
# ------------------------------------------------------------------
loadDeninuBiomassData <- function(raw_datasetA, epsg_code = 32611) {

  df <- readxl::read_excel(raw_datasetA)

  df_sf <- df %>%
    sf::st_as_sf(coords = c("Easting", "Northing"), crs = epsg_code) %>%
    sf::st_transform(crs = 4326)
  coords <- sf::st_coordinates(df_sf)
  df$longitude <- coords[, 1]
  df$latitude  <- coords[, 2]

  df_clean <- df[, c("Plot Number", "cover - biomass  kg / ha", "latitude", "longitude", "Date")]
  df_clean$Date <- as.Date(df_clean$Date)

  colnames(df_clean)[colnames(df_clean) == "Plot Number"] <- "plotID"
  colnames(df_clean)[colnames(df_clean) == "cover - biomass  kg / ha"] <- "measure_quad"
  colnames(df_clean)[colnames(df_clean) == "Date"] <- "sample_date"

  df_clean$plotID <- make.unique(as.character(df_clean$plotID), sep = "_")
  df_clean$quadID <- NA
  df_clean$gva    <- "Cladonia spp."   # LGL's field protocol pools all preferred
                                       # caribou forage lichens together and
                                       # can't be split back out by species

  df_clean <- df_clean[, c("plotID", "quadID", "gva", "measure_quad",
                           "latitude", "longitude", "sample_date")]

  message("Deninu Kue First Nation et al. (2026): ",
         length(unique(df_clean$plotID)), " plots loaded.")
  df_clean
}
