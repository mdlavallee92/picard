# Create Blank Concept Sets Load File

Creates a blank conceptSetsLoad.csv template file in the specified
folder with proper column structure. Users can fill this file manually
in Excel, Google Sheets, or any text editor, then place it in the
inputs/conceptSets folder.

## Usage

``` r
createBlankConceptSetsLoadFile(
  conceptSetsFolderPath = here::here("inputs/conceptSets")
)
```

## Arguments

- conceptSetsFolderPath:

  Character. Path where the blank file will be created. Defaults to
  "inputs/conceptSets". Creates the folder if it doesn't exist.

## Value

Invisibly returns the file path. Prints informative messages with tips.

## Details

**Column Guide:**

- `atlasId` (numeric): The ATLAS concept set ID. Get this from ATLAS \>
  Concept Sets

- `label` (character): Display name for your concept set (e.g.,
  "Hypertension diagnoses")

- `category` (character): Broad grouping category (e.g.,
  "Cardiovascular", "Medications")

- `subCategory` (character): Optional sub-grouping within category

- `sourceCode` (TRUE/FALSE): Whether this represents source codes
  (rarely TRUE for concept sets)

- `domain` (character): OMOP domain - must be one of:

  - `drug_exposure` - medication concept sets

  - `condition_occurrence` - diagnosis concept sets

  - `measurement` - lab/measurement concept sets

  - `procedure` - procedure concept sets

  - `observation` - observation concept sets

  - `visit_occurrence` - visit type concept sets

- `file_name` (character): Path to JSON file (e.g.,
  "json/hypertension.json"). Note this is a placeholder will be replaced
  when you import from ATLAS.

**Tips for Filling Out:**

1.  Each row represents one concept set

2.  Use forward slashes (/) in file paths

3.  Ensure file_name matches the JSON files you'll import from ATLAS

4.  domain field is critical for vocabulary suggestions in
    extractSourceCodes()

5.  Save as UTF-8 CSV when exporting from Excel to avoid encoding issues

**Workflow:**

1.  Call this function to create blank template

2.  Open conceptSetsLoad.csv in your preferred spreadsheet application

3.  Fill in your concept set metadata

4.  Save the file

5.  Use
    [`importAtlasConceptSets()`](https://ohdsi.github.io/picard/reference/importAtlasConceptSets.md)
    to import the actual JSON definitions from ATLAS

6.  Use
    [`loadConceptSetManifest()`](https://ohdsi.github.io/picard/reference/loadConceptSetManifest.md)
    to load into your study

## Examples

``` r
if (FALSE) { # \dontrun{
  # Create blank template in default location
  createBlankConceptSetsLoadFile()
  # File created at: inputs/conceptSets/conceptSetsLoad.csv
} # }
```
