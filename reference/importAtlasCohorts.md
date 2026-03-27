# Import CIRCE Cohort Definitions from ATLAS

this function looks for a CSV file called cohortsLoad.csv containing
cohort metadata. Must be located in or accessible from the
inputs/cohorts folder. The CSV must have the following columns:

- `atlasId`: ATLAS cohort definition ID (integer)

- `label`: Cohort name/label (character)

- `category`: Broad category for the cohort (character)

- `subCategory`: Sub-category for the cohort (character) The function
  will read this CSV, fetch the cohort definitions from ATLAS using the
  provided atlasConnection, extract the CIRCE JSON expressions, and save
  them to the specified output folder with filenames based on the label.
  Finally it updates the cohort load CSV with the relative file paths to
  the saved JSON files.

## Usage

``` r
importAtlasCohorts(cohortsFolderPath, atlasConnection)
```

## Arguments

- cohortsFolderPath:

  Character. Path to cohorts folder in Ulysses repo.

- atlasConnection:

  An ATLAS connection object (typically from ROhdsiWebApi package) with
  a method `getCohortDefinition(cohortId)` that returns a list
  containing an `expression` element with the CIRCE JSON string.

- outputFolder:

  Character. Path to the output folder where cohort JSON files will be
  saved. Defaults to "inputs/cohorts/json". Files are saved as
  `{label}.json`.

## Value

Invisibly returns NULL. Saves CIRCE JSON files to outputFolder and
prints status messages via cli alerts.

## Details

Imports CIRCE JSON cohort definitions from an ATLAS WebAPI instance and
saves them to the inputs/cohorts/json folder. This function reads a CSV
file containing cohort metadata and fetches the actual cohort
definitions from ATLAS.

**Workflow:**

1.  Reads the cohort load CSV file

2.  Validates that all required columns are present

3.  For each row with a valid atlasId:

    - Fetches the cohort definition from ATLAS WebAPI

    - Extracts the CIRCE JSON expression

    - Saves to `outputFolder/{label}.json`

4.  Skips rows with missing atlasId with a warning

5.  Catches and reports errors per cohort without stopping the entire
    import

**Post-Import:** After running this function, use
[`loadCohortManifest()`](https://ohdsi.github.io/picard/reference/loadCohortManifest.md)
to load the saved cohort JSON files and build the manifest with
metadata.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Assuming ATLAS connection is set up
  importAtlasCohorts(
    cohortFolderPath = here::here("inputs/cohorts"),
    atlasConnection = setAtlasConnection()
  )

  # Then load the manifest (no settings required for metadata review)
  manifest <- loadCohortManifest()
} # }
```
