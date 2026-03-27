# Load Concept Set Manifest

Loads or creates a concept set manifest from CIRCE JSON files located in
the inputs/conceptSets/json folder. The manifest is stored in an SQLite
database for efficient querying and metadata persistence.
ExecutionSettings are optional and only required if you plan to extract
source codes or access vocabularies.

## Usage

``` r
loadConceptSetManifest(
  conceptSetsFolderPath = here::here("inputs/conceptSets"),
  executionSettings = NULL
)
```

## Arguments

- conceptSetsFolderPath:

  Character. Path to the conceptSets folder containing the manifest
  database. Defaults to "inputs/conceptSets".

- executionSettings:

  ExecutionSettings object. Optional. Defaults to NULL. Only required
  for operations like extractSourceCodes(). You can add settings later
  using setExecutionSettings() on the returned ConceptSetManifest
  object.

## Value

ConceptSetManifest object containing all loaded concept sets with
metadata.

## Details

**Workflow:**

1.  Checks if conceptSetManifest.sqlite database exists

2.  If it exists, loads concept set entries from the json/ directory
    using cached metadata

3.  If not, scans the json/ directory for CIRCE JSON files

4.  Creates ConceptSetDef objects for each JSON file

5.  Enriches metadata from conceptSetsLoad.csv if available

6.  Returns a ConceptSetManifest object

**Metadata CSV Format:** The conceptSetsLoad.csv file (optional) should
contain:

- `file_name`: Relative path to JSON file (e.g., "conceptSet1.json")

- `label`: Display name for the concept set

- `atlasId`: ATLAS concept set ID

- `domain`: OMOP domain classification

- `sourceCode`: Whether the concept set represents source codes

**Post-Load:** After loading, use manifest methods to query concept
sets:

- `getConceptSetById(id)` - Get by database ID

- `getConceptSetsByTag(key, value)` - Get by metadata tag

- `grabConceptSetById(id)` - Get ConceptSetDef object

## Examples

``` r
if (FALSE) { # \dontrun{
  # Load concept set manifest (no settings required for metadata review)
  manifest <- loadConceptSetManifest()
  
  # Or load from custom path
  manifest <- loadConceptSetManifest(conceptSetsFolderPath = "path/to/conceptsets")
  
  # Add execution settings later if needed for source code extraction
  settings <- createExecutionSettings(
    connectionString = "Server=localhost;Database=mydb"
  )
  manifest$setExecutionSettings(settings)
  manifest$extractSourceCodes(sourceVocabs = c("ICD10CM"))
} # }
```
