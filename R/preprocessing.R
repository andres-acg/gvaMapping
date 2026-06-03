# ------------------------------------------------------------
# Function to prepare Baltzer et al. plot data
# ------------------------------------------------------------
# rawDataset1LoadORPrep <- function(formatted_dataset = NULL,
#                                   raw_datasetA  = NULL,
#                                   raw_datasetB  = NULL) {
# 
#   # -------------------------
#   # 1. If cover_dataset is a file path that exists, load it
#   # -------------------------
#   if (is.character(formatted_dataset) && file.exists(formatted_dataset)) {
#     if (grepl("\\.csv$", formatted_dataset, ignore.case = TRUE)) {
#       # Try read.csv first, fallback to read.csv2
#       df <- tryCatch(
#         read.csv(formatted_dataset),
#         error = function(e) {
#           message("read.csv() failed — retrying with read.csv2()...")
#           read.csv2(formatted_dataset)
#         }
#       )
#       message("cover_dataset1 successfully loaded from CSV file — available in dataset_list")
#       return(df)
# 
#     } else if (grepl("\\.xlsx?$", formatted_dataset, ignore.case = TRUE)) {
#       df <- readxl::read_excel(formatted_dataset)
#       message("cover_dataset1 successfully loaded from Excel file — available in dataset_list")
#       return(df)
# 
#     } else {
#       stop("Unsupported file type for cover_dataset1: ", formatted_dataset)
#     }
#   }
# 
#   # -------------------------
#   # 2. Otherwise, create from raw cover & site files
#   # -------------------------
#   if (is.null(formatted_dataset) && (is.null(raw_datasetA) || is.null(raw_datasetB))) {
#     stop("❌ Formatted dataset or raw file not provided or invalid for cover_dataset1 — cannot create it (nor any subsequent dataset(s) if expected).
#     Please provide either formatted dataset path or valid raw dataset(s) path (raw dataset A only or, if it is the case, A and B).")
#   }
# 
#   df_cover <- read.csv2(raw_datasetA, header = TRUE, sep = ";")
#   df_site  <- read.csv2(raw_datasetB, header = TRUE, sep = ";")
# 
#   df_clean <- df_cover %>%
#     left_join(df_site %>% dplyr::select(plot, Lat_start, Long_start, date), by = "plot") %>%
#     rename(
#       plotID   = plot,
#       quadID   = plot.quadrat,
#       species  = attribute,
#       latitude = Lat_start,
#       longitude = Long_start,
#       sample_date = date
#     ) %>%
#     dplyr::select(plotID, quadID, species, percent, latitude, longitude, sample_date)
# 
#   #standardize data
#   df_clean$sample_date <- lubridate::ymd(df_clean$sample_date)
# 
#   message("✅ cover_dataset1 successfully created from raw dataset(s) — available in dataset_list")
#   return(df_clean)
# }




# # ------------------------------------------------------------
# # Function to prepare Errington et al. plot data
# # ------------------------------------------------------------
# rawDataset2LoadORPrep <- function(formatted_dataset = NULL, 
#                                   raw_datasetA  = NULL, 
#                                   raw_datasetB  = NULL,
#                                   cover_sheet = "lichen cover",
#                                   site_sheet  = "Plot info",
#                                   time_filter = "T2") {
#   
#   
#   # -------------------------
#   # 1. If cover_dataset is a file path that exists, load it
#   # -------------------------
#   if (is.character(formatted_dataset) && file.exists(formatted_dataset)) {
#     if (grepl("\\.csv$", formatted_dataset, ignore.case = TRUE)) {
#       # Try read.csv first, fallback to read.csv2
#       df <- tryCatch(
#         read.csv(formatted_dataset),
#         error = function(e) {
#           message("read.csv() failed — retrying with read.csv2()...")
#           read.csv2(formatted_dataset)
#         }
#       )
#       message("cover_dataset2 successfully loaded from CSV file — available in dataset_list")
#       return(df)
#       
#     } else if (grepl("\\.xlsx?$", formatted_dataset, ignore.case = TRUE)) {
#       df <- readxl::read_excel(formatted_dataset)
#       message("cover_dataset2 successfully loaded from Excel file — available in dataset_list")
#       return(df)
#       
#     } else {
#       stop("Unsupported file type for cover_dataset2: ", formatted_dataset)
#     }
#   }
#   
#   # -------------------------
#   # 2. Otherwise, create from raw cover & site files
#   # -------------------------
#   if (is.null(formatted_dataset) && (is.null(raw_datasetA) || is.null(raw_datasetB))) {
#     stop("❌ Formatted dataset or raw file not provided or invalid for cover_dataset2 — cannot create it (nor any subsequent dataset(s) if expected). 
#     Please provide either formatted dataset path or valid raw dataset(s) path (raw dataset A only or, if it is the case, A and B).")
#   }
#   
#   # i. Read raw cover data
#   
#   df_cover <- read_excel(raw_datasetA, sheet = cover_sheet)
#   
#   # Since lichen species are per column, select lichen species
#   
#   # The targeted species are those for which the pooled allometric equation was developed 
#   # in Greuel et al. (2021):
#   # Cladonia mitis and C. arbuscula
#   # C. rangiferina and C. stygia
#   # C. stellaris
#   # C. uncialis (confused with C. amaurocrea)
#   
#   # according to 'lichen list' sheet in Ruth et al. raw data (df_cover):
#   # C. mitis = Cladmit
#   # C. arbuscula = Cladarb
#   # C. rangiferina = Cladran
#   # C. stygia = Cladsty
#   # C. stellaris = Cladste
#   # C. uncialis = Cladunc
#   # C. amaurocrea = Cladama 
#   
#   lichen_species = c("Cladama", "Cladarb", "Cladmit", "Cladran", "Cladste", "Cladsty", "Cladunc")
#   
#   # Keep only relevant columns
#   df_cover <- df_cover[, c("Time", "Plot", "Q ID", lichen_species)]
#   
#   # Sum selected lichen columns into a total percent column
#   df_cover$percent <- rowSums(df_cover[, lichen_species], na.rm = TRUE)
#   
#   # Remove individual lichen species columns
#   df_cover <- df_cover[, !colnames(df_cover) %in% lichen_species]
#   
#   # Add standard species label
#   df_cover$species <- "Cladonia spp."
#   
#   # Filter by time period (e.g., T2)
#   df_cover <- subset(df_cover, Time == time_filter) # time_filter == "T2" for 2018 and "T1" for 2008
#   df_cover <- df_cover[, -which(names(df_cover) == "Time")]
#   
#   
#   # ii. Read site (lat/lon) data
#   
#   df_site <- read_excel(raw_datasetB, sheet = site_sheet, skip = 1)
#   
#   # Remove the 'Plot' column by its position
#   df_site <- df_site[, -which(colnames(df_site) == "Plot")]
#   
#   # Adjust column names for consistency
#   if ("pname" %in% names(df_site)) {
#     names(df_site)[names(df_site) == "pname"] <- "Plot"
#   }
#   
#   # standardize date
#   df_site$Day...13 <- gsub(" .*", "", df_site$Day...13)  # keep only first number before any space or symbol
#   df_site$Day...13 <- trimws(df_site$Day...13)           # remove whitespace
#   df_site$Day...13 <- as.numeric(df_site$Day...13)       # ensure numeric
#   
#   df_site$Month...12 <- tools::toTitleCase(tolower(df_site$Month...12))
#   
#   Sys.setlocale("LC_TIME", "C")
#   df_site$sample_date <- as.Date(
#     with(df_site, paste(Day...13, Month...12, Year...14)),
#     format = "%d %B %Y"
#   )
#   
#   # Keep relevant coordinate columns
#   df_site <- df_site[, c("Plot", "DDlat", "DDlong", "sample_date")]
#   
#   
#   # iii. Merge and rename
#   
#   df_clean <- merge(df_cover, df_site, by = "Plot")
#   
#   # Rename to standardized column names
#   df_clean <- df_clean %>%
#     rename(
#       plotID   = Plot,
#       quadID   = `Q ID`,
#       latitude = DDlat,
#       longitude = DDlong,
#       sample_date = sample_date
#     ) %>%
#     dplyr::select(plotID, quadID, species, percent, latitude, longitude, sample_date)
#   
#   # iv. Return cleaned dataset
#   message("✅ cover_dataset2 successfully created from raw dataset(s) — available in dataset_list")
#   return(df_clean)
# }





# # ------------------------------------------------------------
# # Function to prepare NFI plot data
# # ------------------------------------------------------------
# 
# rawDataset3LoadORPrep <- function(formatted_dataset = NULL, 
#                                   raw_datasetA  = NULL, 
#                                   raw_datasetB  = NULL,
#                                   province_filter = "NT") {
#   
#   
#   # -------------------------
#   # 1. If cover_dataset is a file path that exists, load it
#   # -------------------------
#   if (is.character(formatted_dataset) && file.exists(formatted_dataset)) {
#     if (grepl("\\.csv$", formatted_dataset, ignore.case = TRUE)) {
#       # Try read.csv first, fallback to read.csv2
#       df <- tryCatch(
#         read.csv(formatted_dataset),
#         error = function(e) {
#           message("read.csv() failed — retrying with read.csv2()...")
#           read.csv2(formatted_dataset)
#         }
#       )
#       message("cover_dataset3 successfully loaded from CSV file — available in dataset_list")
#       return(df)
#       
#     } else if (grepl("\\.xlsx?$", formatted_dataset, ignore.case = TRUE)) {
#       df <- readxl::read_excel(formatted_dataset)
#       message("cover_dataset3 successfully loaded from Excel file — available in dataset_list")
#       return(df)
#       
#     } else {
#       stop("Unsupported file type for cover_dataset3: ", formatted_dataset)
#     }
#   }
#   
#   # -------------------------
#   # 2. Otherwise, create from raw cover & site files
#   # -------------------------
#   if (is.null(formatted_dataset) && (is.null(raw_datasetA) || is.null(raw_datasetB))) {
#     stop("❌ Formatted dataset or raw file not provided or invalid for cover_dataset3 — cannot create it (nor any subsequent dataset(s) if expected). 
#     Please provide either formatted dataset path or valid raw dataset(s) path (raw dataset A only or, if it is the case, A and B).")
#   }
#   
#   # i. Load input files
#   
#   ground_cover <- read.csv(raw_datasetA)
#   ground_cover_loc <- read.csv(raw_datasetB)
#   
#   # ii. Convert UTM to lat/lon by UTM zone
#   
#   convert_utm_to_latlon <- function(df_zone) {
#     zone_number <- unique(df_zone$utm_zone)
#     if (length(zone_number) != 1) stop("Multiple zones in one subset")
#     
#     epsg_code <- 32600 + as.integer(zone_number)  # Northern hemisphere UTM
#     df_sf <- st_as_sf(df_zone, coords = c("utm_e", "utm_n"), crs = epsg_code)
#     df_latlon <- st_transform(df_sf, crs = 4326)
#     coords <- st_coordinates(df_latlon)
#     
#     df_zone$longitude <- coords[, 1]
#     df_zone$latitude <- coords[, 2]
#     return(df_zone)
#   }
#   
#   NFI_data <- ground_cover_loc %>%
#     group_split(utm_zone) %>%
#     lapply(convert_utm_to_latlon) %>%
#     bind_rows()
#   
#   
#   # iii. Join cover and location data (Northwest Territories = "NT")
#   
#   NFI_data <- dplyr::inner_join(ground_cover, NFI_data, by = "nfi_plot")
#   
#   
#   # iv. Filter for desired province(s)
#   
#   NFI_data <- NFI_data[NFI_data$province %in% province_filter, ]
#   
#   
#   # v. Keep and rename relevant columns
#   
#   NFI_data <- NFI_data[, c("nfi_plot", "plot_type", "meas_date.y",
#                            "ec_genus", "ec_species", "ec_species_pct",
#                            "longitude", "latitude")]
#   
#   # vi. standardize data
#   Sys.setlocale("LC_TIME", "C")
#   NFI_data$sample_date <- as.Date(NFI_data$meas_date.y, format = "%Y-%b-%d")
#   
#   
#   # vii. Filter for Cladonia species
#   
#   # The targeted species are those for which the pooled allometric equation was developed in Greuel et al. (2021):
#   # Cladonia mitis and C. arbuscula
#   # C. rangiferina and C. stygia
#   # C. stellaris
#   # C. uncialis (confused with C. amaurocrea)
#   
#   # Based on NFI Data dictionary v.5.3 (https://nfi.nfis.org/resources/groundplot/4a-GPDataDictionary5.3.pdf),
#   # page 102, ec_genus = 4 letter genus code if collected prior to 2021 and ec_species = 3 letter species code (generally the first 3 letters of the scientific species name), 
#   # if collected prior to 2021.
#   
#   # Given that, I assumed:
#   # Cladonia or Cladina =  Clad/CLAD as genus and
#   # C. mitis = MIT  
#   # C. arbuscula = ARB 
#   # C. rangiferina = RAN 
#   # C. stygia = STY
#   # C. stellaris = STE
#   # C. uncialis = unc
#   # C. amaurocrea = AMA
#   
#   lichen_species = c("MIT", "ARB", "RAN",  "STY", "STE", "unc", "AMA")
#   
#   NFI_data_clad <- NFI_data %>%
#     filter(ec_genus %in% c("Clad", "CLAD") |
#              ec_species %in% lichen_species) 
#   
#   
#   # viii. Add missing plots with 0% Cladonia spp. cover
#   
#   missing_clad <- NFI_data %>%
#     filter(!(nfi_plot %in% NFI_data_clad$nfi_plot)) %>%
#     distinct(nfi_plot, .keep_all = TRUE) %>%
#     select(nfi_plot, latitude, longitude, sample_date) %>%
#     mutate(
#       ec_species_pct = 0,
#       plot_type = NA_character_,
#       ec_genus = NA_character_,
#       ec_species = "Cladonia spp."
#     )
#   
#   
#   # vix. Combine and format standardized output
#   
#   df_clean <- bind_rows(NFI_data_clad, missing_clad) %>%
#     select(
#       plotID = nfi_plot,
#       quadID = plot_type,
#       species = ec_species,
#       percent = ec_species_pct,
#       latitude,
#       longitude,
#       sample_date
#     ) %>%
#     mutate(percent = ifelse(percent < 0, 0, percent))
#   
#   
#   # x. Return standardized data
#   message("✅ cover_dataset3 successfully created from raw dataset(s) — available in dataset_list")
#   return(df_clean)
# }





# # ------------------------------------------------------------
# # Function to prepare Cook et al. plot data
# # ------------------------------------------------------------
# 
# raw2Dataset1LoadORPrep <- function(formatted_dataset = NULL, 
#                                    raw_datasetA  = NULL, 
#                                    raw_datasetB  = NULL) {
#   
#   # --- Validation block ---
#   if (is.null(formatted_dataset)) {
#     
#     # Case: one of A or B missing, but not both
#     if (xor(is.null(raw_datasetA), is.null(raw_datasetB))) {
#       stop(paste0(
#         "❌ Formatted dataset or raw file not provided or invalid for biomass_dataset1 — cannot create it (nor any subsequent dataset(s) if expected). ",
#         "\nPlease provide either a formatted dataset path or valid raw dataset(s) path ",
#         "(raw dataset A only or, if it is the case, A and B)."
#       ))
#     }
#     
#     # Optional: if both are missing, keep your central/global stop check for that case
#   }
#   # -------------------------
#   # 1. If cover_dataset is a file path that exists, load it
#   # -------------------------
#   if (is.character(formatted_dataset) && file.exists(formatted_dataset)) {
#     if (grepl("\\.csv$", formatted_dataset, ignore.case = TRUE)) {
#       # Try read.csv first, fallback to read.csv2
#       df <- tryCatch(
#         read.csv(formatted_dataset),
#         error = function(e) {
#           message("read.csv() failed — retrying with read.csv2()...")
#           read.csv2(formatted_dataset)
#         }
#       )
#       message("biomass_dataset1 successfully loaded from CSV file — available in dataset_list")
#       return(df)
#       
#     } else if (grepl("\\.xlsx?$", formatted_dataset, ignore.case = TRUE)) {
#       df <- readxl::read_excel(formatted_dataset)
#       message("biomass_dataset1 successfully loaded from Excel file — available in dataset_list")
#       return(df)
#       
#     } else {
#       stop("Unsupported file type for biomass_dataset1: ", formatted_dataset)
#     }
#   }
#   
#   # -------------------------
#   # 2. Otherwise, create from raw cover & site files
#   # -------------------------
#   if (is.null(formatted_dataset) && (is.null(raw_datasetA) && is.null(raw_datasetB))) {
#     stop("❌ Formatted dataset or raw file not provided or invalid for biomass_dataset1 — cannot create it (nor any subsequent dataset(s) if expected). 
#     Please provide either formatted dataset path or valid raw dataset(s) path (raw dataset A only or, if it is the case, A and B).")
#   }
#   
#   # i. Load data
#   
#   df_biomass <- read_excel(raw_datasetA, sheet = "byplot_kgha ", .name_repair = "minimal")
#   df_site <- read_excel(raw_datasetB, sheet = "Macroplot data", .name_repair = "minimal")
#   
#   
#   # ii. Correct lichen biomass for specific plots
#   
#   # The targeted species are those for which the pooled allometric equation was developed in Greuel et al. (2021):
#   # Cladonia mitis and C. arbuscula
#   # C. rangiferina and C. stygia
#   # C. stellaris
#   # C. uncialis (confused with C. amaurocrea)
#   
#   #From 'sppabbrev' sheet of 'df_biomass' or in Cook et al's report:
#   #https://nwtdiscoveryportal.enr.gov.nt.ca/geoportaldocuments/2022-23%20-%20DELIVERABLE%20-%20CIMP205(Kelly)%20-%20Final%20Vegetation%20Report%20May2023.pdf
#   
#   #Cladina mitis = CLMI
#   #C. arbuscula = absent
#   #C. rangiferina = CLRA
#   #C. stygia = absent
#   #C. stellaris = CLST
#   #C.uncialis = CLADUNC
#   #C. amaurocrea = absent
#   
#   df_biomass[, 8:ncol(df_biomass)] <- sapply(df_biomass[, 8:ncol(df_biomass)], as.numeric)
#   
#   specificPlots <- c(11:24, "M1", "M2", "M3", "M4", "M5", "M6")
#   
#   lichen_species <- c("CLMI", "CLRA", "CLST", "CLADUNC") 
#   
#   df_biomass[df_biomass$ID %in% specificPlots, lichen_species] <-
#     df_biomass[df_biomass$ID %in% specificPlots, lichen_species] / 4 #divide by 4 to correct biomass, according to Cook in a conversation
#   
#   
#   # iii. Keep relevant columns
#   
#   fiveColumns <- df_biomass[, c("YEAR", "DY", "M", "ID", "PLOT")]
#   fiveColumns <- data.frame(fiveColumns)
#   fiveColumns <- fiveColumns[-c(1, 2), ]
#   
#   # Repeat fiveColumns to match species count
#   new_fiveColumns <- fiveColumns[rep(seq_len(nrow(fiveColumns)),
#                                      each = length(lichen_species)), ]
#   rownames(new_fiveColumns) <- NULL
#   
#   
#   # iv. Extract biomass data and reshape
#   
#   lichenColumns <- df_biomass[, lichen_species]
#   lichenColumns_transp <- as.data.frame(t(lichenColumns))
#   df_biomass_transposed <- as.data.frame(lichenColumns_transp[-c(1, 2)])
#   
#   df_biomass_long <- gather(df_biomass_transposed,
#                             key = "temp", value = "Biomass_Kg_ha")
#   df_biomass_long$Species <- rep(rownames(df_biomass_transposed),
#                                  ncol(df_biomass_transposed))
#   df_biomass_long <- df_biomass_long[, c("Species", "Biomass_Kg_ha")]
#   
#   
#   # v. Merge structure and biomass data
#   
#   df_biomass_structured <- cbind(new_fiveColumns, df_biomass_long)
#   rownames(df_biomass_structured) <- NULL
#   
#   
#   # vi. Clean up the site (location) data
#   
#   new_header <- as.character(unlist(df_site[1, ]))
#   df_site <- df_site[-1, ]
#   colnames(df_site) <- new_header
#   
#   cols_location <- df_site[, c("ID", "GPSLAT", "GPSLONG")]
#   site_coords <- data.frame(cols_location)
#   site_coords$GPSLAT <- as.numeric(site_coords$GPSLAT)
#   site_coords$GPSLONG <- as.numeric(site_coords$GPSLONG)
#   
#   # vii. Combine with coordinates and adjust biomass
#   
#   df_biomass_with_coords <- merge(df_biomass_structured,
#                                   site_coords, by = "ID", all.x = TRUE)
#   
#   df_biomass_with_coords$Biomass_Kg_ha <- as.numeric(df_biomass_with_coords$Biomass_Kg_ha)
#   df_biomass_with_coords$Biomass_Kg_ha <- df_biomass_with_coords$Biomass_Kg_ha * 1.56 # 64% of living biomass. Multiply it by 1.56 to be comparable with Balter's data
#   df_biomass_with_coords <- df_biomass_with_coords[!is.na(df_biomass_with_coords$Biomass_Kg_ha), ]
#   
#   
#   # viii. Filter for Cladonia species only
#   
#   cladsSpecies <- c("CLMI", "CLRA", "CLADUNC", "CLST")
#   df_biomass_with_coords <- subset(df_biomass_with_coords, Species %in% cladsSpecies)
#   rownames(df_biomass_with_coords) <- NULL
#   
#   
#   # vix. Aggregate biomass per plot and quadrat
#   
#   df_biomass_aggregated <- df_biomass_with_coords %>%
#     group_by(ID, PLOT) %>%
#     summarise(
#       YEAR = first(YEAR),
#       DY = first(DY),
#       M = first(M),
#       Species = "Cladonia spp.",
#       GPSLAT = first(GPSLAT),
#       GPSLONG = first(GPSLONG),
#       Biomass_Kg_ha = sum(Biomass_Kg_ha),
#       .groups = "drop"
#     )
#   
#   
#   # standardize date
#   df_biomass_aggregated$sample_date <- ymd(sprintf("%04d-%02d-%02d", df_biomass_aggregated$YEAR, 
#                                                    df_biomass_aggregated$M,
#                                                    df_biomass_aggregated$DY))
#   
#   
#   # x. Rename columns and finalize output
#   
#   df_clean <- df_biomass_aggregated %>%
#     rename(
#       plotID = ID,
#       quadID = PLOT,
#       species = Species,
#       biomass_dens_quad = Biomass_Kg_ha,
#       latitude = GPSLAT,
#       longitude = GPSLONG,
#       sample_date = sample_date
#     ) %>%
#     select(plotID, quadID, species, biomass_dens_quad, latitude, longitude, sample_date)
#   
#   
#   # xi. Return standardized dataset
#   message("✅ biomass_dataset1 successfully created from raw dataset(s) — available in dataset_list")
#   return(df_clean)
# }




# ------------------------------------------------------------
# Function to prepare Deninu Kųę́ First Nation et al (2026) plot data
# ------------------------------------------------------------

raw2Dataset1LoadORPrep <- function(formatted_dataset = NULL, 
                                   raw_datasetA  = NULL, 
                                   raw_datasetB  = NULL, epsg_code = 32611) {
  
  
  # -------------------------
  # 1. If cover_dataset is a file path that exists, load it
  # -------------------------
  if (is.character(formatted_dataset) && file.exists(formatted_dataset)) {
    if (grepl("\\.csv$", formatted_dataset, ignore.case = TRUE)) {
      # Try read.csv first, fallback to read.csv2
      df <- tryCatch(
        read.csv(formatted_dataset),
        error = function(e) {
          message("read.csv() failed — retrying with read.csv2()...")
          read.csv2(formatted_dataset)
        }
      )
      message("biomass_dataset2 successfully loaded from CSV file — available in dataset_list")
      return(df)
      
    } else if (grepl("\\.xlsx?$", formatted_dataset, ignore.case = TRUE)) {
      df <- readxl::read_excel(formatted_dataset)
      message("biomass_dataset2 successfully loaded from Excel file — available in dataset_list")
      return(df)
      
    } else {
      stop("Unsupported file type for biomass_dataset2: ", formatted_dataset)
    }
  }
  
  # -------------------------
  # 2. Otherwise, create from raw cover & site files
  # -------------------------
  if (is.null(formatted_dataset) && is.null(raw_datasetA)) {
    stop("❌ Formatted dataset or raw file not provided or invalid for biomass_dataset2 — cannot create it (nor any subsequent dataset(s) if expected). 
    Please provide either formatted dataset path or valid raw dataset(s) path (raw dataset A only or, if it is the case, A and B).")
  }
  
  # i. Load LGL dataset
  df <- read_excel(raw_datasetA)
  
  # ii. Convert Easting/Northing → lat/lon
  df_sf <- df %>%
    st_as_sf(coords = c("Easting", "Northing"), crs = epsg_code) %>%
    st_transform(crs = 4326)
  
  coords <- st_coordinates(df_sf)
  df$longitude <- coords[, 1]
  df$latitude <- coords[, 2]
  
  # iii. Keep only the necessary columns
  df_clean <- df[, c("Plot Number", "cover - biomass  kg / ha", "latitude", "longitude", "Date")]
  
  # iv. standardize date
  df_clean$Date <- as.Date(df_clean$Date)
  
  # v. Rename columns to match standard format
  colnames(df_clean)[colnames(df_clean) == "Plot Number"] <- "plotID"
  colnames(df_clean)[colnames(df_clean) == "cover - biomass  kg / ha"] <- "measure_quad" #"biomass_dens_quad"
  colnames(df_clean)[colnames(df_clean) == "Date"] <- "sample_date"
  
  # vi. Make each plotID unique since there are two different plots with the same name
  df_clean$plotID <- make.unique(as.character(df_clean$plotID), sep = "_")
  
  # vii. Add missing standard columns
  df_clean$quadID <- NA
  df_clean$gva <- "Cladonia spp." #species # represents all species LGL collected in the field based on their report: 
  # https://nwtdiscoveryportal.enr.gov.nt.ca/geoportaldocuments/2021-22%20-%20FINAL%20REPORT%20-%20DKFN%20(d'Entremont)%20CIMP194.pdf
  # preferred caribou forage lichens, including Cladonia mitis, C. rangiferina, 
  # C. stellaris, C. uncialis, Cetraria islandica, and Flavocetraria nivalis.
  
  # Not possible to separate them. This may bias the analysis a bit, since:
  # The targeted species are those for which the pooled allometric equation was developed in Greuel et al. (2021):
  # Cladonia mitis and C. arbuscula
  # C. rangiferina and C. stygia
  # C. stellaris
  # C. uncialis (confused with C. amaurocrea)
  
  
  # viii. Reorder columns to standard order
  df_clean <- df_clean[, c("plotID", "quadID", "gva", "measure_quad", "latitude", "longitude", "sample_date")] #"species", "biomass_dens_quad"
  
  # vix. Return the cleaned dataset
  message("✅ dataset1 successfully created from raw dataset(s) — saved in inputs folder")
  # message("✅ biomass_dataset2 successfully created from raw dataset(s) — available in dataset_list")
  return(df_clean)
}




# --- Helper: auto-detect datasets and validate functions/inputs ---
# autoDetectDatasets <- function(sim, type = c("raw", "raw2"), strict = TRUE) {
#   type <- match.arg(type)
#   objs <- ls(envir = sim$.mods$gvaMapping) #.GlobalEnv)
#   
#   # --- Detect dataset functions ---
#   func_pattern <- paste0("^", type, "Dataset(\\d+)LoadORPrep$")
#   func_Xs <- as.integer(sub(func_pattern, "\\1", grep(func_pattern, objs, value = TRUE)))
#   
#   # --- Detect raw and formatted datasets ---
#   raw_pattern <- paste0(type, "_dataset(\\d+)[A-Z]$")
#   formatted_pattern <- paste0("^", type, "_dataset(\\d+)$")
#   raw_Xs <- as.integer(sub(raw_pattern, "\\1", grep(raw_pattern, objs, value = TRUE)))
#   formatted_Xs <- as.integer(sub(formatted_pattern, "\\1", grep(formatted_pattern, objs, value = TRUE)))
#   
#   # --- Merge all detected dataset numbers ---
#   all_Xs <- sort(unique(c(func_Xs, raw_Xs, formatted_Xs)))
#   
#   # --- Validate functions exist for any dataset with inputs ---
#   for (X in all_Xs) {
#     func_name <- paste0(type, "Dataset", X, "LoadORPrep")
#     has_inputs <- X %in% c(raw_Xs, formatted_Xs)
#     if (has_inputs && !exists(func_name, envir = sim$.mods$gvaMapping, mode = "function")) {
#       stop(paste0("❌ Function '", func_name, "' is missing but an input was detected."))
#     }
#   }
#   
#   # --- Detect numeric gaps in the sequence ---
#   if (length(all_Xs) > 0) {
#     expected_seq <- seq(1, max(all_Xs))  # <-- always start from 1
#     missing_Xs <- setdiff(expected_seq, all_Xs)
#     
#     if (length(missing_Xs) > 0 && strict) {
#       stop(
#         paste0(
#           "⚠️ Missing function and input(s) for dataset_", type, "_",
#           paste(missing_Xs, collapse = ", ")
#         )
#       )
#     }
#   }
#   
#   # --- Handle case: no function or inputs detected at all ---
#   if (length(all_Xs) == 0) {
#     warning(paste0("🚫 No inputs or functions detected for any ", type, " dataset."))
#   }
#   
#   return(all_Xs)
# }




#Datasetset Load or Prep wrapper function
# datasetLoadORPrep <- function(sim, type = c("raw", "raw2"), X, output_dir = "/home/ancag6/projects/def-stevec/ancag6/kfold/") {
#   type <- match.arg(type)
#   
#   # ---------------------------------------------------------------
#   # Define output directory relative to the Rproj working directory
#   # ---------------------------------------------------------------
#   if (!is.null(output_dir)) {
#     # Handle relative vs absolute paths
#     if (!grepl("^(/|[A-Za-z]:)", output_dir)) {
#       output_dir <- file.path(getwd(), output_dir)
#     }
#     if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
#   }
#   
#   # Build object and function names
#   dataset_name <- paste0(type, "_dataset", X)
#   func_name <- paste0(type, "Dataset", X, "LoadORPrep")
#   
#   # Try to get raw datasets safely
#   rawA <- if (exists(paste0(type, "_dataset", X, "A"), envir = sim))
#     get(paste0(type, "_dataset", X, "A"), envir = sim) else NULL
#   rawB <- if (exists(paste0(type, "_dataset", X, "B"), envir = sim))
#     get(paste0(type, "_dataset", X, "B"), envir = sim) else NULL
#   
#   # Try to get formatted dataset if it exists
#   existing_obj <- if (exists(dataset_name, envir = sim))
#     get(dataset_name, envir = sim) else NULL
#   
#   # Validate paths
#   rawA_path <- if (!is.null(rawA) && is.character(rawA) && length(rawA) == 1 && file.exists(rawA)) rawA else NULL
#   rawB_path <- if (!is.null(rawB) && is.character(rawB) && length(rawB) == 1 && file.exists(rawB)) rawB else NULL
#   
#   # === NEW VALIDATION BLOCK ===
#   if (is.null(existing_obj) && is.null(rawA_path) && is.null(rawB_path)) {
#     stop(paste0(
#       "❌ Missing required input(s) for ", type, " dataset ", X, ". ",
#       "Please provide either formatted dataset (", dataset_name,
#       ") path or valid raw dataset(s) path (raw_", type, "_dataset", X, "A only or, if it is the case, A and B)."
#     ))
#   }
#   
#   # Call the LoadORPrep function
#   df <- get(func_name, envir = sim$.mods$gvaMapping)(
#     formatted_dataset = existing_obj,
#     raw_datasetA = rawA_path,
#     raw_datasetB = rawB_path
#   )
#   
#   # --- Harmonize classes ---
#   df <- harmonizeDatasetStr(df, type = type)
#   
#   # --- Add extra columns only for biomass datasets ---
#   if (type == "raw2") {
#     sampling_var <- paste0("sampling_size_m2_raw2_dataset", X)
#     if (exists(sampling_var, envir = sim)) {
#       sampling_size_m2 <- get(sampling_var, envir = sim)
#       df$sampling_size_ha <- sampling_size_m2 / 10000
#       df$biomass_quad <- df$biomass_dens_quad * (sampling_size_m2 / 10000)
#       # df$biomass_dens_plot <- ave(df$biomass_dens_quad, df$plotID, FUN = mean)
#       # df$biomass_plot <- ave(df$biomass_quad, df$plotID, FUN = mean)
#     } else {
#       warning(sprintf("⚠️ Sampling unit size variable '%s' not found.", sampling_var))
#     }
#   }
#   
#   # ---------------------------------------------------------------
#   # Save the processed dataset to outputs/secondary_outputs/
#   # ---------------------------------------------------------------
#   output_file <- file.path(output_dir, paste0(dataset_name, ".csv"))
#   write.csv(df, output_file)
#   #cat(sprintf("💾 and saved at: %s\n", normalizePath(output_file)))
#   
#   return(df)
# }




# # ------------------------------
# # Helper: Harmonize dataset classes
# # ------------------------------
# harmonizeDatasetStr <- function(df, type = c("raw", "raw2")) {
#   type <- match.arg(type)
#   
#   # Define expected columns and classes for each dataset type
#   expected_classes <- switch(
#     type,
#     "raw" = list(
#       plotID = "character",
#       quadID = "character",
#       species = "character",
#       percent = "numeric",
#       latitude = "numeric",
#       longitude = "numeric",
#       sample_date = "Date"
#     ),
#     "raw2" = list(
#       plotID = "character",
#       quadID = "character",
#       species = "character",
#       biomass_dens_quad = "numeric",
#       latitude = "numeric",
#       longitude = "numeric",
#       sample_date = "Date"
#     )
#   )
#   
#   # Ensure all expected columns exist
#   for (col in names(expected_classes)) {
#     if (!col %in% names(df)) {
#       df[[col]] <- NA
#     }
#   }
#   
#   # Apply conversions safely
#   df <- df %>%
#     mutate(
#       plotID = as.character(plotID),
#       quadID = if ("quadID" %in% names(df)) {
#         ifelse(is.na(quadID), NA, as.character(quadID))
#       } else NA_character_,
#       species = as.character(species),
#       latitude = as.numeric(latitude),
#       longitude = as.numeric(longitude),
#       sample_date = as.Date(sample_date)
#     ) 
#   
#   # Type-specific conversions
#   if (type == "raw" && "percent" %in% names(df))
#     df$percent <- as.numeric(df$percent)
#   
#   if (type == "raw2" && "biomass_dens_quad" %in% names(df))
#     df$biomass_dens_quad <- as.numeric(df$biomass_dens_quad)
#   
#   # Keep consistent column order
#   df <- df[, names(expected_classes), drop = FALSE]
#   
#   
#   
#   return(df)
# }





#GET SAMPLING SIZES AND CREATE A LIST OF SAMPLING TYPES PER COVER DATASETS
# Determine the number of sampling_sizes dynamically
# sim$num_types_sampling_raw_dataset <- length(grep("^sampling_size_m2_raw_dataset\\d+$", ls(envir = sim)))
# cat("Detected", sim$num_types_sampling_raw_dataset, "sampling unit size variable(s) for cover datasets.\n")

# Generate a vector of sampling_sizes names
# sim$sampling_type_names_raw_dataset <- paste0("sampling_size_m2_raw_dataset", 1:sim$num_types_sampling_raw_dataset)
# #sampling_type_names_raw_dataset <- sampling_type_names_raw_dataset
# cat("Samplingt size variable names for cover datasets:", paste(sim$sampling_type_names_raw_dataset, collapse = ", "), "\n")

# Retrieve sampling_sizes by their names and store them in a list
# sim$sampling_types_raw_dataset <- mget(sim$sampling_type_names_raw_dataset)
# #sampling_types_raw_dataset <- sampling_types_raw_dataset
# cat("Sampling sizes for cover datasets:", paste(unlist(sim$sampling_types_raw_dataset), collapse = ", "), "\n")


# 
# convertCoverToBiomass <- function(data_list, sampling_sizes, output_dir = "/home/ancag6/projects/def-stevec/ancag6/kfold/") {
#   
#   # Ensure the output directory exists
#   if (!is.null(output_dir)) {
#     # Handle relative vs absolute paths
#     if (!grepl("^(/|[A-Za-z]:)", output_dir)) {
#       output_dir <- file.path(getwd(), output_dir)
#     }
#     if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
#   }
#   
#   # Define target species for pooled Cladonia spp.
#   target_species <- c("mitis", "Cladmit", "MIT", "CLMI",
#                       "arbuscula", "Cladarb", "ARB",
#                       "rangiferina", "Cladran", "RAN", "CLRA",
#                       "stygia", "Cladsty", "STY",
#                       "stellaris", "Cladste", "STE", "CLST",
#                       "uncialis", "Cladunc", "unc", "CLADUNC",
#                       "amaurocrea", "Cladama", "AMA",
#                       "spp.")
#   
#   generate_patterns <- function(species) {
#     paste0(
#       "(?:C\\.|Cladonia|Cladina)?\\s*",
#       "(?i)", species,
#       "(?:\\s+.*)?$"
#     )
#   }
#   
#   species_patterns <- sapply(target_species, generate_patterns, USE.NAMES = FALSE)
#   final_pattern <- paste(species_patterns, collapse = "|")
#   
#   # Process each data frame
#   processed_list <- mapply(function(df, sampling_size_m2, index) {
#     df <- df %>% mutate(percent = as.numeric(percent))
#     
#     matched_species <- df$species[grepl(final_pattern, df$species, ignore.case = TRUE)]
#     lichen_species <- unique(trimws(matched_species))
#     
#     df <- df %>%
#       mutate(
#         species = case_when(
#           species %in% lichen_species ~ "Cladonia spp.",
#           TRUE ~ "other"
#         ),
#         areaperaream2 = (percent / 100) * 10000,
#         biomass_dens_quad = case_when(
#           species == "Cladonia spp." ~ areaperaream2 * 0.06213 * 10, #Greuel & Degre-Timmons et al. 2021, pooled allometric equation for Cladonia spp. (kg/m2) multiplied by 10 to convert to kg/ha
#           species == "other" ~ 0,
#           TRUE ~ NA_real_
#         )
#       ) %>%
#       group_by(plotID, quadID, species) %>%
#       summarise(
#         percent = sum(percent, na.rm = TRUE),
#         areaperaream2 = sum(areaperaream2, na.rm = TRUE),
#         biomass_dens_quad = sum(biomass_dens_quad, na.rm = TRUE),
#         latitude = first(latitude),
#         longitude = first(longitude),
#         sample_date = first(sample_date),
#         .groups = "drop"
#       ) %>%
#       ungroup() %>%
#       group_by(plotID, quadID) %>%
#       summarise(
#         species = "Cladonia spp.",
#         biomass_dens_quad = sum(biomass_dens_quad, na.rm = TRUE),
#         latitude = first(latitude),
#         longitude = first(longitude),
#         sample_date = first(sample_date),
#         sampling_size_ha = sampling_size_m2 / 10000,
#         biomass_quad = biomass_dens_quad * sampling_size_m2 / 10000,
#         .groups = "drop"
#       ) %>%
#       # group_by(plotID) %>%
#       # mutate(
#       #   biomass_dens_plot = mean(biomass_dens_quad, na.rm = TRUE),
#       #   biomass_plot = mean(biomass_quad, na.rm = TRUE)
#       # ) %>%
#       ungroup()
#     
#     # --- Save result ---
#     output_path <- file.path(output_dir, paste0("raw_dataset", index, "_converted_to_biomass.csv"))
#     write.csv(df, output_path)
#     
#     #message(sprintf("✅ Saved converted dataset %d to: %s", index, output_path))
#     
#     return(df)
#   }, data_list, sampling_sizes, seq_along(data_list), SIMPLIFY = FALSE)
#   
#   message("\n✅ Cover dataset(s) successfully converted to biomass - dataset_list updated")
#   return(processed_list)
# }
# 


###############################################################################
###############################################################################
##########        RAW DATASET PREPROCESSING         ############
###############################################################################
###############################################################################
packages <- c("sf", "dplyr", "readxl")

missing_packages <- packages[!(packages %in% installed.packages()[, "Package"])]

if(length(missing_packages) > 0) {
  install.packages(missing_packages)
}

# Load packages
lapply(packages, library, character.only = TRUE)

input_dir <- getOption("spades.inputPath")

# COVER datasets 
## from Baltzer et al. (2021)
# does not work from Dryad

# BIOMASS datasets
## from Deninu Kųę́ First Nation et al. (2026)
raw2_dataset1A_path <- "https://zenodo.org/records/20054559/files/EA3922%20Lichen%20Plot%20Data_ALL%20YEARS_SUMMARY%20BIOMASS%20three%20ways.xlsx?download=1"

raw2_dataset1A <- reproducible::prepInputs(
  url = raw2_dataset1A_path,
  targetFile = "EA3922 Lichen Plot Data_ALL YEARS_SUMMARY BIOMASS three ways.xlsx",
  destinationPath = input_dir,
  fun = NA,
  overwrite = TRUE
)


dataset1 <- raw2Dataset1LoadORPrep(raw_datasetA = raw2_dataset1A)

#save dataset1 in inputObjects

dataset_dir <- file.path(input_dir, "datasets", "dataset1")

# create folder if needed
dir.create(dataset_dir, recursive = TRUE, showWarnings = FALSE)

# write file
write.csv(
  dataset1,
  file = file.path(dataset_dir, "dataset1_formatted.csv"),
  row.names = FALSE
)


rm("dataset1", "raw2_dataset1A", "raw2_dataset1A_path", "input_dir",
   "missing_packages", "packages", "raw2Dataset1LoadORPrep")
