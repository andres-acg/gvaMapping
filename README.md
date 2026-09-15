# gvaMapping

<<<<<<< HEAD
A [SpaDES](https://spades.predictiveecology.org/) module that estimates mean **ground vegetation attribute (GVA)** values — in this project, reindeer lichen (*Cladonia* spp.) biomass — per land cover class, from field plot data and a land cover product. The resulting class-mean table is the direct input to the [`WB_LichenBiomass`](https://github.com/andres-acg/WB_LichenBiomass) module, which applies it across a full landscape raster.

Part of a backcasting/forecasting workflow for lichen biomass and caribou habitat in the Wek'èezhìi region, Northwest Territories, developed for Andres Caseiro Guilhem's PhD thesis (Université Laval).
=======
A [SpaDES](https://spades.predictiveecology.org/) module that maps mean **ground vegetation attribute (GVA)** values per land cover class, from field plot data and one or more land cover products. gvaMapping is a generic tool: it isn't tied to any particular vegetation attribute, species, or region. It's meant to be straightforward to use — supply your plot data (raw or already formatted), land cover product(s), study area, and a handful of parameters, and the module does the rest (see "Inputs" and "Key parameters" below).

## Example application: lichen biomass in the Wek'èezhìi region

This copy of the module was developed for a specific application: estimating mean reindeer lichen (*Cladonia* spp.) biomass per land cover class, as part of a backcasting/forecasting workflow for lichen biomass and caribou habitat in the Wek'èezhìi region, Northwest Territories, developed for Andres Caseiro Guilhem's PhD thesis (Université Laval). The resulting class-mean table is the direct input to the [`WB_LichenBiomass`](https://github.com/andres-acg/WB_LichenBiomass) module, which applies it across a full landscape raster. The defaults documented below (datasets, parameters) reflect this application — supply your own plot data, land cover product(s), study area, and parameters to apply gvaMapping to a different GVA, region, or dataset.
>>>>>>> 0f4b334 (Reframe README as a generic tool with lichen example separated out; add manuscript citation)

## What it does

1. Loads one or more field plot datasets (percent cover or biomass measurements of the target GVA).
2. Filters plots to the study area and, optionally, to areas undisturbed by fire.
3. Extracts the land cover class under each plot from a supplied land cover product.
4. Computes the weighted mean GVA value per land cover class (`sim$weighted_mean_results`), optionally cross-validated (k-fold).
5. If more than one land cover product is supplied, builds an ensemble map weighted by cross-validation performance.

Everything expensive is cached against `gva_output_dir` — once computed for a given set of inputs, later runs (e.g. successive years of a backcasting run pointed at the same `gva_output_dir`) just reload the result.

## Quick start

This module is normally driven by a project-level script (see [`globalscript_backcasting.R`](../globalscript_backcasting.R) in this workflow), which supplies `dataset_list`, `study_area_path`, and `land_cover_paths` via `setupProject()`. Standalone:

```r
library(SpaDES.core)

simInitAndSpades(
  times = list(start = 2020, end = 2020),
  modules = "gvaMapping",
  paths = list(modulePath = ".."),
  params = list(gvaMapping = list(gva_output_dir = "outputs/gvaMapping"))
)
```

With no other inputs supplied, the run above works out of the box — see **Running with no inputs** below.

## Running with no inputs (public-data-only defaults)

As of 2026-08-11, `gvaMapping` no longer requires any private data to run. If `study_area_path`, `land_cover_paths`, or `dataset_list` are left unsupplied, `Init()` auto-fetches a public default for each:

| Input | Default if unsupplied | Source |
|---|---|---|
| `study_area_path` | Wek'èezhìi boreal caribou range planning boundary | Zenodo, [doi:10.5281/zenodo.20492584](https://doi.org/10.5281/zenodo.20492584) |
| `land_cover_paths` | SCANFI land cover, `land_cover_year` (default 2020) | [SCANFI](https://opendata.nfis.org/mapserver/nfis-change_eng.html) (Open Government Licence – Canada), fetched via `LandR::prepInputs_SCANFI_LCC_FAO()` |
| `dataset_list` | Dataset1 (Deninu Kué First Nation et al. 2026) only | Zenodo, [doi:10.5281/zenodo.20054559](https://doi.org/10.5281/zenodo.20054559) |

**What this deliberately does *not* do**: datasets 2–5 (Baltzer et al., Errington et al., NFI ground plots, Cook et al.) are private field data with no public archive to fetch from, and are never fabricated or substituted with placeholder values. If they're not supplied, the class-mean table is computed from dataset1 alone — a real result from real (if more limited) public data, not a synthetic stand-in. Supply your own `dataset_list` (see `globalscript_backcasting.R`'s `useDataset`/`rawDataPaths`) to include them.

This means: **no private data from this project is ever committed to this repository.** The 8 raw plot files and datasets 2–5 referenced in code comments throughout this module live only on the original researcher's machine.

## Inputs

| Object | Class | Description | Required? |
|---|---|---|---|
| `dataset_list` | `list` | Named list (`dataset1`, `dataset2`, ...) of formatted plot datasets, as data frames or paths/URLs to them | No — auto-fetches dataset1 only if unsupplied |
| `study_area_path` | `character` | Path or URL to the study area shapefile used to filter plots | No — auto-fetches the Wek'èezhìi boundary if unsupplied |
| `land_cover_paths` | `list` | Named list of paths/URLs to the land cover product(s) | No — auto-fetches SCANFI if unsupplied |
| `disturbances_path` | `character` | Path or URL to a disturbance (fire) polygon layer, used to screen out disturbed plots | Optional — omitted entirely if not supplied |

## Key parameters

Defaults below (set 2026-08-11) match the SCANFI + Deninu Kué public-data-only configuration, so the module has sensible values even with zero parameters supplied.

| Parameter | Default | Description |
|---|---|---|
| `measure_class` | `"intensive"` | Whether plot values are already per-unit-area (`"intensive"`) or need area correction (`"extensive"`) |
| `measure_name` / `unit` | `"Biomass"` / `"kg ha⁻¹"` | Labels for outputs and plots |
| `sampling_size_m2` | `list(dataset1 = 0.25)` | Plot sampling area per dataset, in m² |
| `target_gva` | Cladonia spp. synonym/code list | Which GVA values to filter and pool from the raw plot data |
| `list_of_land_cover_names` | `list(land_cover1 = "SCANFI")` | Name(s) of the land cover product(s) supplied |
| `land_cover_year` | `2020` | Reference year for the land cover product |
| `inapplicable_classes_list` | `list(land_cover1 = c(20))` | Land cover classes excluded from mapping (e.g. water) |
| `water_classes_list` | `list(land_cover1 = 20)` | Water class(es), for visualization/area accounting |
| `abbrev_list` | SCANFI Canada-LCC/FAO legend | Class code → label lookup for plots |
| `run_cross_validation` | `TRUE` | Set `FALSE` to skip k-fold CV when only the class-mean table is needed |
| `gva_output_dir` | `<outputPath>/gvaMapping` | Where outputs are written/cached; point several runs at the same folder to compute once and reuse |
| `seed` | `81` | Reproducibility seed for cross-validation/sampling |

## Outputs

| Object | Class | Description |
|---|---|---|
| `weighted_mean_results` | `data.frame` | The class-mean GVA table per land cover product — the key output consumed by `WB_LichenBiomass` |
| `dataset_list` | `list` | Plot datasets after study-area (and disturbance) filtering |
| `gva_map` | `SpatRaster` | GVA map per land cover product (written to `gva_output_dir`, not kept as an in-memory object) |
| `bar_plot` / `pie_chart` | `ggplot` | Class-mean bar plot and class-proportion pie chart per land cover product |
| `ensemble_gva_map` / `cv_map` | `SpatRaster` | Ensemble map and cross-validation map, when more than one land cover product is supplied |

Raster and plot outputs are written to `gva_output_dir` rather than kept as `simList` objects — see that folder after a run.

## Related modules

- [`WB_LichenBiomass`](https://github.com/andres-acg/WB_LichenBiomass) — consumes `weighted_mean_results` and applies it across the full landscape raster.
- [`WB_VegBasedDrainage`](https://github.com/andres-acg/WB_VegBasedDrainage), [`WB_NonForestedVegClasses`](https://github.com/andres-acg/WB_NonForestedVegClasses) — other modules in the same backcasting workflow.

## Data sources & citation

<<<<<<< HEAD
=======
If you use `gvaMapping`, please cite:

> Guilhem, A.C., Barros, C., Degré-Timmons, G.É., Greuel, R.J., Errington, R.C., Baltzer, J.L., McIntire, E.J.B., Johnstone, J.F., & Cumming, S.G. gvaMapping: a SpaDES module for mapping ground vegetation attributes from plot data and land cover products. *Ecological Solutions and Evidence* (in review).

See also [`citation.bib`](citation.bib).

Data sources for the example application above:

>>>>>>> 0f4b334 (Reframe README as a generic tool with lichen example separated out; add manuscript citation)
- Deninu Kué First Nation et al. (2026). *Lichen plot data*. Zenodo. [doi:10.5281/zenodo.20054559](https://doi.org/10.5281/zenodo.20054559)
- Wek'èezhìi boreal caribou range planning regions boundary. Zenodo. [doi:10.5281/zenodo.20492584](https://doi.org/10.5281/zenodo.20492584)
- Matasci, G. et al. SCANFI (Spatialized CAnadian National Forest Inventory). Government of Canada Open Data, Open Government Licence – Canada.

<<<<<<< HEAD
Module citation: see [`citation.bib`](citation.bib).

=======
>>>>>>> 0f4b334 (Reframe README as a generic tool with lichen example separated out; add manuscript citation)
## Author

Andres Caseiro Guilhem (andres.caseiro-guilhem.1@ulaval.ca), Université Laval.
