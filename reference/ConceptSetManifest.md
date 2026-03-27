# ConceptSetManifest R6 Class

ConceptSetManifest R6 Class

ConceptSetManifest R6 Class

## Details

An R6 class that manages a collection of ConceptSetDef objects and
maintains metadata in a SQLite database.

The ConceptSetManifest class manages multiple concept set definitions
and stores their metadata in a SQLite database located at
inputs/conceptSets/conceptSetManifest.sqlite. Each ConceptSetDef is
assigned a sequential ID based on its position in the manifest.

**Vocabulary Suggestion by Domain:** The function automatically suggests
appropriate vocabularies based on concept set domains:

- `condition_occurrence`: ICD10CM, ICD9CM

- `procedure`: HCPCS, CPT4

- `measurement`: LOINC

- `drug_exposure`: NDC

- `observation`: All vocabularies (ICD9CM, ICD10CM, HCPCS, CPT4, LOINC,
  NDC)

- `device_exposure`: NDC

- `visit_occurrence`: ICD10CM, ICD9CM, HCPCS, CPT4

Note: These suggestions are based on OMOP CDM conventions. You can
override with any valid vocabulary combination.

**Processing Workflow:**

1.  Verifies ExecutionSettings is configured with database connection

2.  Detects domains of all concept sets in the manifest

3.  Displays suggested vocabularies based on detected domains

4.  Prompts user to accept or override suggested vocabularies

5.  Creates a new xlsx workbook

6.  For each concept set in the manifest:

    - Reads the CIRCE JSON definition

    - Builds a concept query selecting standard concepts (using CirceR)

    - Performs SQL join: concepts -\> concept_relationship (Maps to) -\>
      source concepts

    - Finds matching source codes in the specified vocabularies

    - Adds results as a new sheet in the xlsx workbook with formatted
      header

    - Provides status messages for each concept set

7.  Exports combined results to `{outputFolder}/SourceCodeWorkbook.xlsx`

8.  Each sheet contains columns: vocabulary_id, concept_code,
    concept_name

9.  Sheet headers are styled with blue background and white bold text

10. Column widths are auto-fitted for readability

**SQL Query Pattern:** For each concept set, the following logic is
executed:

- CTE selects all standard concepts in the concept set

- Joins to concept_relationship table with relationship_id = 'Maps to'

- Maps relationship finds what source codes map TO standard concepts

- Filters to valid, non-invalid source codes in specified vocabularies

- Results ordered by vocabulary_id and concept_code

**Requirements:**

- ExecutionSettings must be initialized with a valid database connection

- Vocabulary schema must be accessible from ExecutionSettings

- openxlsx2 package must be installed

- User must have READ permissions on vocabulary tables

**Error Handling:**

- Displays warnings if any concept set processing fails but continues
  with others

- Provides clear error messages if database connection is unavailable

- Validates source vocabularies against known vocabulary IDs

This function identifies which standard concepts are included in each
concept set by finding the reverse mapping relationship. For each
concept set:

1.  Reads the CIRCE JSON definition

2.  Builds a concept query using CirceR

3.  Joins with concept_relationship via reverse "Maps to" relationship
    (finds what maps TO the concept set concepts)

4.  Filters for standard concepts (standard_concept = 'S')

5.  Adds results to a new sheet in the xlsx workbook

6.  Exports all results to `{outputFolder}/IncludedCodes.xlsx`

7.  Each sheet contains: concept_id, concept_name, vocabulary_id

**Requirements:**

- ExecutionSettings must be initialized with a valid connection

- Vocabulary schema must be accessible from ExecutionSettings

- openxlsx2 package must be installed

## Methods

### Public methods

- [`ConceptSetManifest$new()`](#method-ConceptSetManifest-new)

- [`ConceptSetManifest$getManifest()`](#method-ConceptSetManifest-getManifest)

- [`ConceptSetManifest$getDbPath()`](#method-ConceptSetManifest-getDbPath)

- [`ConceptSetManifest$getExecutionSettings()`](#method-ConceptSetManifest-getExecutionSettings)

- [`ConceptSetManifest$setExecutionSettings()`](#method-ConceptSetManifest-setExecutionSettings)

- [`ConceptSetManifest$getConceptSetById()`](#method-ConceptSetManifest-getConceptSetById)

- [`ConceptSetManifest$getConceptSetsByTag()`](#method-ConceptSetManifest-getConceptSetsByTag)

- [`ConceptSetManifest$getConceptSetsByLabel()`](#method-ConceptSetManifest-getConceptSetsByLabel)

- [`ConceptSetManifest$nConceptSets()`](#method-ConceptSetManifest-nConceptSets)

- [`ConceptSetManifest$grabConceptSetById()`](#method-ConceptSetManifest-grabConceptSetById)

- [`ConceptSetManifest$grabConceptSetsByTag()`](#method-ConceptSetManifest-grabConceptSetsByTag)

- [`ConceptSetManifest$grabConceptSetsByLabel()`](#method-ConceptSetManifest-grabConceptSetsByLabel)

- [`ConceptSetManifest$validateManifest()`](#method-ConceptSetManifest-validateManifest)

- [`ConceptSetManifest$getManifestStatus()`](#method-ConceptSetManifest-getManifestStatus)

- [`ConceptSetManifest$deleteConceptSet()`](#method-ConceptSetManifest-deleteConceptSet)

- [`ConceptSetManifest$hardRemoveConceptSet()`](#method-ConceptSetManifest-hardRemoveConceptSet)

- [`ConceptSetManifest$cleanupMissing()`](#method-ConceptSetManifest-cleanupMissing)

- [`ConceptSetManifest$extractSourceCodes()`](#method-ConceptSetManifest-extractSourceCodes)

- [`ConceptSetManifest$extractIncludedCodes()`](#method-ConceptSetManifest-extractIncludedCodes)

- [`ConceptSetManifest$clone()`](#method-ConceptSetManifest-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize a new ConceptSetManifest

#### Usage

    ConceptSetManifest$new(
      conceptSetEntries,
      executionSettings = NULL,
      dbPath = "inputs/conceptSets/conceptSetManifest.sqlite"
    )

#### Arguments

- `conceptSetEntries`:

  List. A list of ConceptSetDef objects.

- `executionSettings`:

  Object. (Optional) Execution settings for accessing the vocabulary
  database. Can be any object type containing configuration for
  vocabulary queries. Defaults to NULL. Only required for operations
  like extractSourceCodes().

- `dbPath`:

  Character. Path to the SQLite database. Defaults to
  "inputs/conceptSets/conceptSetManifest.sqlite" Get the manifest as a
  data frame

------------------------------------------------------------------------

### Method `getManifest()`

#### Usage

    ConceptSetManifest$getManifest()

#### Returns

Data frame. The manifest with id, label, tags, filePath, hash, and
timestamp columns. Get the manifest path

------------------------------------------------------------------------

### Method `getDbPath()`

#### Usage

    ConceptSetManifest$getDbPath()

#### Returns

Character. The path to the SQLite database. Get the execution settings

------------------------------------------------------------------------

### Method `getExecutionSettings()`

#### Usage

    ConceptSetManifest$getExecutionSettings()

#### Returns

Object. The execution settings object for vocabulary access, or NULL if
not set. Set or update execution settings

------------------------------------------------------------------------

### Method `setExecutionSettings()`

#### Usage

    ConceptSetManifest$setExecutionSettings(executionSettings)

#### Arguments

- `executionSettings`:

  ExecutionSettings object for database access.

#### Returns

Invisibly returns self for method chaining. Get a specific concept set
by ID

------------------------------------------------------------------------

### Method `getConceptSetById()`

#### Usage

    ConceptSetManifest$getConceptSetById(id)

#### Arguments

- `id`:

  Integer. The concept set ID.

#### Returns

Data frame. A subset of the manifest with columns id, label, tags,
filePath, hash, timestamp for the requested concept set. Get concept
sets by tag

------------------------------------------------------------------------

### Method `getConceptSetsByTag()`

#### Usage

    ConceptSetManifest$getConceptSetsByTag(tagString)

#### Arguments

- `tagString`:

  Character. A tag in the format "name: value" (e.g., "category:
  primary").

#### Returns

Data frame. A subset of the manifest with matching tags, or NULL if none
found. Get concept sets by label

------------------------------------------------------------------------

### Method `getConceptSetsByLabel()`

#### Usage

    ConceptSetManifest$getConceptSetsByLabel(
      label,
      matchType = c("exact", "pattern")
    )

#### Arguments

- `label`:

  Character. The label to search for.

- `matchType`:

  Character. Either "exact" for exact match or "pattern" for pattern
  matching. Defaults to "exact".

#### Returns

Data frame. A subset of the manifest with matching labels, or NULL if
none found.

------------------------------------------------------------------------

### Method `nConceptSets()`

Get number of concept sets in manifest

#### Usage

    ConceptSetManifest$nConceptSets()

#### Returns

Integer. The number of concept sets. Grab a specific concept set by ID

------------------------------------------------------------------------

### Method `grabConceptSetById()`

#### Usage

    ConceptSetManifest$grabConceptSetById(id)

#### Arguments

- `id`:

  Integer. The concept set ID.

#### Returns

ConceptSetDef. The ConceptSetDef object with matching ID, or NULL if not
found. Grab concept sets by tag

------------------------------------------------------------------------

### Method `grabConceptSetsByTag()`

#### Usage

    ConceptSetManifest$grabConceptSetsByTag(tagString)

#### Arguments

- `tagString`:

  Character. A tag in the format "name: value" (e.g., "category:
  primary").

#### Returns

List. A list of ConceptSetDef objects with matching tags, or NULL if
none found. Grab concept sets by label

------------------------------------------------------------------------

### Method `grabConceptSetsByLabel()`

#### Usage

    ConceptSetManifest$grabConceptSetsByLabel(
      label,
      matchType = c("exact", "pattern")
    )

#### Arguments

- `label`:

  Character. The label to search for.

- `matchType`:

  Character. Either "exact" for exact match or "pattern" for pattern
  matching. Defaults to "exact".

#### Returns

List. A list of ConceptSetDef objects with matching labels, or NULL if
none found.

------------------------------------------------------------------------

### Method `validateManifest()`

Validate manifest and return status of all concept sets

#### Usage

    ConceptSetManifest$validateManifest()

#### Returns

A tibble with columns: id, label, status (active/missing/deleted),
deleted_at, file_exists

------------------------------------------------------------------------

### Method `getManifestStatus()`

Get summary status of manifest

#### Usage

    ConceptSetManifest$getManifestStatus()

#### Returns

List with elements: active_count, missing_count, deleted_count,
next_available_id

------------------------------------------------------------------------

### Method `deleteConceptSet()`

Soft delete a concept set (mark as deleted, preserve record)

#### Usage

    ConceptSetManifest$deleteConceptSet(id, reason = NULL)

#### Arguments

- `id`:

  Integer. The concept set ID to delete.

- `reason`:

  Character. Optional reason for deletion.

#### Returns

Invisibly returns TRUE if successful, FALSE otherwise.

------------------------------------------------------------------------

### Method `hardRemoveConceptSet()`

Hard delete a concept set (removes the record from database,
irreversible)

#### Usage

    ConceptSetManifest$hardRemoveConceptSet(id)

#### Arguments

- `id`:

  Integer. The concept set ID to permanently remove.

#### Returns

Invisibly returns TRUE if successful, FALSE otherwise.

------------------------------------------------------------------------

### Method `cleanupMissing()`

Clean up missing concept sets from manifest

#### Usage

    ConceptSetManifest$cleanupMissing(keep_trace = TRUE)

#### Arguments

- `keep_trace`:

  Logical. If TRUE, marks missing as deleted with timestamp (soft
  delete). If FALSE, permanently removes from database (hard delete).
  Defaults to TRUE.

#### Returns

Invisibly returns NULL. Displays summary of cleanup actions. Extract
Source Codes for Concept Sets

------------------------------------------------------------------------

### Method `extractSourceCodes()`

Finds source codes from specified vocabularies that map to each concept
set's standard concepts. Results are exported to a single xlsx file with
one sheet per concept set, saved in the inputs/conceptSets folder. The
function provides interactive vocabulary suggestions based on detected
concept set domains.

#### Usage

    ConceptSetManifest$extractSourceCodes(
      sourceVocabs = c("ICD10CM"),
      outputFolder = here::here("inputs/conceptSets")
    )

#### Arguments

- `sourceVocabs`:

  Character vector. Source vocabulary IDs to search for. Valid options:
  "ICD9CM", "ICD10CM", "HCPCS", "CPT4", "LOINC", "NDC". Defaults to
  c("ICD10CM"). The function will suggest appropriate vocabularies based
  on the domains of your concept sets and prompt you to use them.

- `outputFolder`:

  Character. Path where the xlsx file will be saved. Defaults to
  "inputs/conceptSets".

#### Returns

Invisibly returns NULL. Saves xlsx file to outputFolder and prints
status messages via cli package. Output file is ready to open in Excel
or other spreadsheet software.

Extract Included Standard Concepts for Concept Sets

Finds standard concepts that are included in (map TO) each concept set's
included concepts. Results are exported to a single xlsx file with one
sheet per concept set, saved in the inputs/conceptSets folder.

------------------------------------------------------------------------

### Method `extractIncludedCodes()`

#### Usage

    ConceptSetManifest$extractIncludedCodes(
      outputFolder = here::here("inputs/conceptSets")
    )

#### Arguments

- `outputFolder`:

  Character. Path where the xlsx file will be saved. Defaults to
  "inputs/conceptSets".

#### Returns

Invisibly returns NULL. Saves xlsx file to outputFolder and prints
status messages.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    ConceptSetManifest$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
