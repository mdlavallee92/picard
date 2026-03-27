# Import CIRCE Concept Sets from ATLAS

This function looks for a CSV file called conceptSetsLoad.csv containing
concept set metadata. Must be located in or accessible from the
inputs/conceptSets folder. The CSV must have the following columns:

- `atlasId`: ATLAS concept set definition ID (integer)

- `label`: Concept set name/label (character)

- `domain`: OMOP domain (drug_exposure, condition_occurrence,
  measurement, procedure)

- `sourceCode`: Whether the concept set represents source codes
  (logical)

The function will read this CSV, fetch the concept set definitions from
ATLAS using the provided atlasConnection, extract the CIRCE JSON
expressions, and save them to the specified output folder with filenames
based on the label. Finally it updates the concept set load CSV with the
relative file paths to the saved JSON files.

## Usage

``` r
importAtlasConceptSets(conceptSetsFolderPath, atlasConnection)
```

## Arguments

- conceptSetsFolderPath:

  Character. Path to conceptSets folder in the project.

- atlasConnection:

  An ATLAS connection object (typically from ROhdsiWebApi package) with
  a method `getConceptSetDefinition(conceptSetId)` that returns a list
  containing an `expression` element with the CIRCE JSON string.

- outputFolder:

  Character. Path to the output folder where concept set JSON files will
  be saved. Defaults to inputs/conceptSets/json. Files are saved as
  `{label}.json`.

## Value

Invisibly returns the updated concept set load dataframe. Saves CIRCE
JSON files to outputFolder and prints status messages via cli alerts.

## Details

Imports CIRCE JSON concept set definitions from an ATLAS WebAPI instance
and saves them to the inputs/conceptSets/json folder. This function
reads a CSV file containing concept set metadata and fetches the actual
concept set definitions from ATLAS.

**Workflow:**

1.  Reads the concept set load CSV file

2.  Validates that all required columns are present

3.  For each row with a valid atlasId:

    - Fetches the concept set definition from ATLAS WebAPI

    - Extracts the CIRCE JSON expression

    - Saves to `outputFolder/{label}.json`

4.  Skips rows with missing atlasId with a warning

5.  Catches and reports errors per concept set without stopping the
    entire import

**Post-Import:** After running this function, use
[`loadConceptSetManifest()`](https://ohdsi.github.io/picard/reference/loadConceptSetManifest.md)
to load the saved concept set JSON files and build the manifest with
metadata.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Assuming ATLAS connection is set up
  importAtlasConceptSets(
    conceptSetsFolderPath = here::here("inputs/conceptSets"),
    atlasConnection = setAtlasConnection()
  )

  # Then load the manifest
  manifest <- loadConceptSetManifest(
    conceptSetsFolderPath = here::here("inputs/conceptSets")
  )
} # }
```
