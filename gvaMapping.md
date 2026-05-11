# gvaMapping Module

<!-- the following are text references used in captions for LaTeX compatibility -->

(ref:gvaMapping) *gvaMapping*

[![made-with-Markdown](figures/markdownBadge.png)](https://commonmark.org)

<!-- if knitting to pdf remember to add the pandoc_args: ["--extract-media", "."] option to yml in order to get the badge images -->

#### Authors:

Andres Caseiro Guilhem <andres.caseiro-guilhem.1@ulaval.ca> \[aut, cre\]
<!-- ideally separate authors with new lines, '\n' not working -->

## Module Overview

### Module summary

Provide a brief summary of what the module does / how to use the module.

Module documentation should be written so that others can use your
module. This is a template for module documentation, and should be
changed to reflect your module.

### Module inputs and parameters

Describe input data required by the module and how to obtain it (e.g.,
directly from online sources or supplied by other modules) If
`sourceURL` is specified,
`downloadData("gvaMapping", "C:/Users/ANCAG6/OneDrive - Université Laval/LICHEN_project/paper1/SpaDES_version")`
may be sufficient. Table @ref(tab:moduleInputs-gvaMapping) shows the
full list of module inputs.

<table class="table" style="color: black; margin-left: auto; margin-right: auto;">
<caption>
List of (ref:gvaMapping) input objects and their description.
</caption>
<thead>
<tr>
<th style="text-align:left;">
objectName
</th>
<th style="text-align:left;">
objectClass
</th>
<th style="text-align:left;">
desc
</th>
<th style="text-align:left;">
sourceURL
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left;">
dataset\_list
</td>
<td style="text-align:left;">
list
</td>
<td style="text-align:left;">
Formatted list of plot datasets (cover and/or biomass)
</td>
<td style="text-align:left;">
NA
</td>
</tr>
<tr>
<td style="text-align:left;">
study\_area\_path
</td>
<td style="text-align:left;">
character
</td>
<td style="text-align:left;">
Path to study area shapefile used to filter plots
</td>
<td style="text-align:left;">
NA
</td>
</tr>
<tr>
<td style="text-align:left;">
land\_cover1\_path
</td>
<td style="text-align:left;">
character
</td>
<td style="text-align:left;">
Path to land cover product 1
</td>
<td style="text-align:left;">
NA
</td>
</tr>
<tr>
<td style="text-align:left;">
land\_cover2\_path
</td>
<td style="text-align:left;">
character
</td>
<td style="text-align:left;">
Path to land cover product 2
</td>
<td style="text-align:left;">
NA
</td>
</tr>
<tr>
<td style="text-align:left;">
land\_cover3\_path
</td>
<td style="text-align:left;">
character
</td>
<td style="text-align:left;">
Path to land cover product 3
</td>
<td style="text-align:left;">
NA
</td>
</tr>
<tr>
<td style="text-align:left;">
land\_cover4\_path
</td>
<td style="text-align:left;">
character
</td>
<td style="text-align:left;">
Path to land cover product 4
</td>
<td style="text-align:left;">
NA
</td>
</tr>
<tr>
<td style="text-align:left;">
disturbances\_path
</td>
<td style="text-align:left;">
character
</td>
<td style="text-align:left;">
Path to disturbance shapefile
</td>
<td style="text-align:left;">
NA
</td>
</tr>
</tbody>
</table>

Provide a summary of user-visible parameters (Table
@ref(tab:moduleParams-gvaMapping))

<table class="table" style="color: black; margin-left: auto; margin-right: auto;">
<caption>
List of (ref:gvaMapping) parameters and their description.
</caption>
<thead>
<tr>
<th style="text-align:left;">
paramName
</th>
<th style="text-align:left;">
paramClass
</th>
<th style="text-align:left;">
default
</th>
<th style="text-align:left;">
min
</th>
<th style="text-align:left;">
max
</th>
<th style="text-align:left;">
paramDesc
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left;">
measure\_class
</td>
<td style="text-align:left;">
character
</td>
<td style="text-align:left;">
intensive
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
Type of measurement at the plot level. ‘extensive’ = total quantity
dependent on sampled area (e.g., total biomass, total counts); values
will be converted to density by dividing by sampling area. ‘intensive’ =
already standardized per unit area or proportion (e.g., biomass density,
individuals per hectare, percent cover); values are used directly
without area correction.
</td>
</tr>
<tr>
<td style="text-align:left;">
measure\_name
</td>
<td style="text-align:left;">
character
</td>
<td style="text-align:left;">
Biomass
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
Name of the ecological variable being mapped. Used for labeling outputs
and plots (e.g., Biomass, Abundance, Cover, Density).
</td>
</tr>
<tr>
<td style="text-align:left;">
unit
</td>
<td style="text-align:left;">
character
</td>
<td style="text-align:left;">
kg ha⁻¹
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
Unit of the measurement. Should reflect the final standardized output
(e.g., kg ha⁻¹, individuals ha⁻¹, %, g m⁻²). Supports Unicode formatting
for exponents (e.g., ha⁻¹).
</td>
</tr>
<tr>
<td style="text-align:left;">
sampling\_size\_m2\_dataset1
</td>
<td style="text-align:left;">
numeric
</td>
<td style="text-align:left;">
1
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
sampling unit size for dataset 1 (in m²)
</td>
</tr>
<tr>
<td style="text-align:left;">
sampling\_size\_m2\_dataset2
</td>
<td style="text-align:left;">
numeric
</td>
<td style="text-align:left;">
1
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
sampling unit size for dataset 2 (in m²)
</td>
</tr>
<tr>
<td style="text-align:left;">
sampling\_size\_m2\_dataset3
</td>
<td style="text-align:left;">
numeric
</td>
<td style="text-align:left;">
100
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
sampling unit size for dataset 3 (in m²)
</td>
</tr>
<tr>
<td style="text-align:left;">
sampling\_size\_m2\_dataset4
</td>
<td style="text-align:left;">
numeric
</td>
<td style="text-align:left;">
2
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
sampling unit size for dataset 4 (in m²)
</td>
</tr>
<tr>
<td style="text-align:left;">
sampling\_size\_m2\_dataset5
</td>
<td style="text-align:left;">
numeric
</td>
<td style="text-align:left;">
0.25
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
sampling unit size for dataset 5 (in m²)
</td>
</tr>
<tr>
<td style="text-align:left;">
target\_gva
</td>
<td style="text-align:left;">
character
</td>
<td style="text-align:left;">
mitis, C….
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
target GVA attribute(S) to be filtered and pooled
</td>
</tr>
<tr>
<td style="text-align:left;">
name\_land\_cover1
</td>
<td style="text-align:left;">
character
</td>
<td style="text-align:left;">
MVI
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
name of land cover product 1 (must match the name in the file name of
the land cover product)
</td>
</tr>
<tr>
<td style="text-align:left;">
name\_land\_cover2
</td>
<td style="text-align:left;">
character
</td>
<td style="text-align:left;">
LCC10
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
name of land cover product 2 (must match the name in the file name of
the land cover product)
</td>
</tr>
<tr>
<td style="text-align:left;">
name\_land\_cover3
</td>
<td style="text-align:left;">
character
</td>
<td style="text-align:left;">
ABoVE
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
name of land cover product 3 (must match the name in the file name of
the land cover product)
</td>
</tr>
<tr>
<td style="text-align:left;">
name\_land\_cover4
</td>
<td style="text-align:left;">
character
</td>
<td style="text-align:left;">
NTEMS
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
name of land cover product 4 (must match the name in the file name of
the land cover product)
</td>
</tr>
<tr>
<td style="text-align:left;">
land\_cover\_year
</td>
<td style="text-align:left;">
numeric
</td>
<td style="text-align:left;">
2010
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
reference year for land cover products used to filter plots based on
disturbance history
</td>
</tr>
<tr>
<td style="text-align:left;">
inapplicable\_classes\_land\_cover1
</td>
<td style="text-align:left;">
numeric
</td>
<td style="text-align:left;">
11, 12, ….
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
vector of inapplicable land cover class(es) for land cover product 1
(e.g., water and urban classes)
</td>
</tr>
<tr>
<td style="text-align:left;">
inapplicable\_classes\_land\_cover2
</td>
<td style="text-align:left;">
numeric
</td>
<td style="text-align:left;">
17, 18
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
vector of inapplicable land cover class(es) for land cover product 2
(e.g., water and urban classes)
</td>
</tr>
<tr>
<td style="text-align:left;">
inapplicable\_classes\_land\_cover3
</td>
<td style="text-align:left;">
numeric
</td>
<td style="text-align:left;">
13, 15
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
vector of inapplicable land cover class(es) for land cover product 3
(e.g., water and urban classes)
</td>
</tr>
<tr>
<td style="text-align:left;">
inapplicable\_classes\_land\_cover4
</td>
<td style="text-align:left;">
numeric
</td>
<td style="text-align:left;">
20, 31
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
vector of inapplicable land cover class(es) for land cover product 4
(e.g., water and urban classes)
</td>
</tr>
<tr>
<td style="text-align:left;">
water\_class\_land\_cover1
</td>
<td style="text-align:left;">
numeric
</td>
<td style="text-align:left;">
20
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
water classe land cover 1
</td>
</tr>
<tr>
<td style="text-align:left;">
water\_class\_land\_cover2
</td>
<td style="text-align:left;">
numeric
</td>
<td style="text-align:left;">
18
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
water classe land cover 2
</td>
</tr>
<tr>
<td style="text-align:left;">
water\_class\_land\_cover3
</td>
<td style="text-align:left;">
numeric
</td>
<td style="text-align:left;">
15
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
water classe land cover 3
</td>
</tr>
<tr>
<td style="text-align:left;">
water\_class\_land\_cover4
</td>
<td style="text-align:left;">
numeric
</td>
<td style="text-align:left;">
20
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
water classe land cover 4
</td>
</tr>
<tr>
<td style="text-align:left;">
abbr\_land\_cover1
</td>
<td style="text-align:left;">
list
</td>
<td style="text-align:left;">
Shadow, ….
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
Named vector mapping land-cover classes to abbreviations for land-cover
product 1 (EOSD).
</td>
</tr>
<tr>
<td style="text-align:left;">
abbr\_land\_cover2
</td>
<td style="text-align:left;">
list
</td>
<td style="text-align:left;">
1-Needle….
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
Named vector mapping land-cover classes to abbreviations for land-cover
product 2 (LCC10).
</td>
</tr>
<tr>
<td style="text-align:left;">
abbr\_land\_cover3
</td>
<td style="text-align:left;">
list
</td>
<td style="text-align:left;">
1-Ever. f….
</td>
<td style="text-align:left;">
|NA
</td>
<td style="text-align:left;">
|NA
</td>
<td style="text-align:left;">
|Named vector mapping land-cover classes to abbreviations for land-cover
product 3 (ABoVE).
</td>
</tr>
<tr>
<td style="text-align:left;">
abbr\_land\_cover4
</td>
<td style="text-align:left;">
list
</td>
<td style="text-align:left;">
20-Water….
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
Named vector mapping land-cover classes to abbreviations for land-cover
product 4 (NTEMS).
</td>
</tr>
<tr>
<td style="text-align:left;">
seed
</td>
<td style="text-align:left;">
numeric
</td>
<td style="text-align:left;">
81
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
seed for reproducibility of results (e.g., in cross-validation)
</td>
</tr>
</tbody>
</table>

### Events

Describe what happens for each event type.

### Plotting

Write what is plotted.

### Saving

Write what is saved.

### Module outputs

Description of the module outputs (Table
@ref(tab:moduleOutputs-gvaMapping)).

<table class="table" style="color: black; margin-left: auto; margin-right: auto;">
<caption>
List of (ref:gvaMapping) outputs and their description.
</caption>
<thead>
<tr>
<th style="text-align:left;">
objectName
</th>
<th style="text-align:left;">
objectClass
</th>
<th style="text-align:left;">
desc
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left;">
dataset\_list
</td>
<td style="text-align:left;">
list
</td>
<td style="text-align:left;">
NA
</td>
</tr>
</tbody>
</table>

### Links to other modules

Describe any anticipated linkages to other modules, such as modules that
supply input data or do post-hoc analysis.

### Getting help

- provide a way for people to obtain help (e.g., module repository
  issues page)
