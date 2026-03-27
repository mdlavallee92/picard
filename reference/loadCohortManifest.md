# Load Cohort Manifest from Database or Cohort Files

Loads a CohortManifest R6 object by either reading from an existing
cohortManifest.sqlite database or by scanning the inputs/cohorts
directories. ExecutionSettings are optional and only required if you
plan to generate cohorts or retrieve cohort counts. You can load the
manifest without them to review metadata.

## Usage

``` r
loadCohortManifest(
  cohortsFolderPath = here::here("inputs/cohorts"),
  executionSettings = NULL,
  verbose = TRUE
)
```

## Arguments

- cohortsFolderPath:

  Character. Path to the cohorts folder containing the manifest database
  and cohort definition files. Defaults to "inputs/cohorts". The
  function will look for:

  - `cohortManifest.sqlite` in this folder for existing manifest data

  - `json/` subfolder for CIRCE JSON cohort definitions

  - `sql/` subfolder for SQL cohort definitions

- executionSettings:

  An ExecutionSettings object containing database configuration for
  cohort generation. Optional; only required if you plan to generate
  cohorts or retrieve cohort counts. Defaults to NULL. You can add
  settings later using `setExecutionSettings()` on the returned
  CohortManifest object.

## Value

A CohortManifest R6 object initialized with all cohorts found.

## Details

**If database exists:** Loads cohort paths and metadata from the
cohortManifest.sqlite database, verifies files still exist, and checks
if any files have changed by comparing the stored hash with the current
file hash.

**If database doesn't exist:** Scans `cohortsFolderPath/json` and
`cohortsFolderPath/sql` directories to find cohort definition files and
creates a new CohortDef for each file with:

- label: The basename of the file without extension

- tags: Empty list

- filePath: The full path to the cohort file

**Metadata Enrichment (optional):** If a `cohortsLoad.csv` file exists
in `cohortsFolderPath`, the function will automatically enrich CohortDef
objects with tags by matching the `file_name` column from the load file
with the `filePath` of each entry. For matching entries, tags are added
from the following columns:

- `atlasId`: Added as an "atlasId" tag

- `category`: Added as a "category" tag

- `subCategory`: Added as a "subCategory" tag

Hash comparison alerts:

- **✓ Unchanged**: Hash matches stored value

- **⚠ Changed**: Hash differs from stored value (file was modified)

## Examples

``` r
if (FALSE) { # \dontrun{
  # Load manifest for metadata review (no settings required)
  manifest <- loadCohortManifest()
  
  # Or load from custom path
  manifest <- loadCohortManifest(cohortsFolderPath = "path/to/cohorts")
  
  # Add execution settings later if needed for cohort generation
  settings <- ExecutionSettings$new(
    databaseName = "mydb",
    dbms = "postgresql",
    connectionDetails = list(...)
  )
  manifest$setExecutionSettings(settings)
} # }
```
