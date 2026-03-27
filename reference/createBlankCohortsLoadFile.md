# Create Blank Cohorts Load File

Creates a blank cohortsLoad.csv template file in the specified folder
with proper column structure. Users can fill this file manually in
Excel, Google Sheets, or any text editor, then place it in the
inputs/cohorts folder.

## Usage

``` r
createBlankCohortsLoadFile(cohortsFolderPath = here::here("inputs/cohorts"))
```

## Arguments

- cohortsFolderPath:

  Character. Path where the blank file will be created. Defaults to
  "inputs/cohorts". Creates the folder if it doesn't exist.

## Value

Invisibly returns the file path. Prints informative messages with tips.

## Details

**Column Guide:**

- `atlasId` (numeric): The ATLAS cohort ID. Get this from ATLAS \>
  Cohort Definitions

- `label` (character): Display name for your cohort (e.g., "Type 2
  Diabetes patients")

- `category` (character): Broad grouping category (e.g., "Disease
  Populations", "Treatment Groups")

- `subCategory` (character): Optional sub-grouping within category

- `file_name` (character): Path to JSON file (e.g.,
  "json/t2dm_patients.json"). Note this is a placeholder will be
  replaced when you import from ATLAS.

**Tips for Filling Out:**

1.  Each row represents one cohort

2.  Use forward slashes (/) in file paths

3.  Ensure file_name matches the JSON files you'll import from ATLAS

4.  Logical sub-grouping in category/subCategory helps with organization

5.  Save as UTF-8 CSV when exporting from Excel to avoid encoding issues

**Workflow:**

1.  Call this function to create blank template

2.  Open cohortsLoad.csv in your preferred spreadsheet application

3.  Fill in your cohort metadata

4.  Save the file

5.  Use
    [`importAtlasCohorts()`](https://ohdsi.github.io/picard/reference/importAtlasCohorts.md)
    to import the actual JSON definitions from ATLAS

6.  Use
    [`loadCohortManifest()`](https://ohdsi.github.io/picard/reference/loadCohortManifest.md)
    to load into your study

## Examples

``` r
if (FALSE) { # \dontrun{
  # Create blank template in default location
  createBlankCohortsLoadFile()
  # File created at: inputs/cohorts/cohortsLoad.csv
} # }
```
