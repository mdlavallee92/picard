# CohortManifest R6 Class

CohortManifest R6 Class

CohortManifest R6 Class

## Details

An R6 class that manages a collection of CohortDef objects and maintains
metadata in a SQLite database.

The CohortManifest class manages multiple cohort definitions and stores
their metadata in a SQLite database located at
inputs/cohorts/cohortManifest.sqlite. Each CohortDef is assigned a
sequential ID based on its position in the manifest.

Returns a tabular view of the manifest from the database, suitable for
viewing, filtering, and reporting. Columns include: id, label, tags,
filePath, hash, timestamp.

Requires that executionSettings has been set and includes:

- A database connection (via getConnection())

- workDatabaseSchema for the target schema

- cohortTable with the desired table name

- tempEmulationSchema if needed for the database platform

Requires that executionSettings has been set and includes:

- A database connection (via getConnection())

- workDatabaseSchema for the target schema

- cohortTable with the desired table name

The cohort is assigned a new ID equal to max(existing_id) + 1. Parent
cohorts (specified in dependsOnCohortIds) must already exist in this
manifest. The cohort is immediately persisted to the SQLite manifest
database.

Execution flow:

1.  Build dependency graph from all CohortDef objects

2.  Validate no circular dependencies (error if found)

3.  Topologically sort cohorts by dependencies (parents before children)

4.  For each cohort in topological order:

    - circe cohorts: check SQL hash (existing logic)

    - dependent cohorts: compute dependency hash from parent hashes +
      rule

5.  Render and execute SQL (circe uses SqlRender parameters, dependent
    uses metadata JSON)

6.  Record checksums and dependency hashes in database

7.  Report results with cohort_type, depends_on, dependency_status
    columns

Requires that executionSettings has been set and includes:

- A database connection (via getConnection())

- cdmDatabaseSchema (where the OMOP CDM data resides)

- workDatabaseSchema (where cohort results are written)

- cohortTable (destination table name)

- tempEmulationSchema if needed for the database platform

## Methods

### Public methods

- [`CohortManifest$new()`](#method-CohortManifest-new)

- [`CohortManifest$getManifest()`](#method-CohortManifest-getManifest)

- [`CohortManifest$tabulateManifest()`](#method-CohortManifest-tabulateManifest)

- [`CohortManifest$getDbPath()`](#method-CohortManifest-getDbPath)

- [`CohortManifest$getExecutionSettings()`](#method-CohortManifest-getExecutionSettings)

- [`CohortManifest$setExecutionSettings()`](#method-CohortManifest-setExecutionSettings)

- [`CohortManifest$getCohortById()`](#method-CohortManifest-getCohortById)

- [`CohortManifest$getCohortsByTag()`](#method-CohortManifest-getCohortsByTag)

- [`CohortManifest$getCohortsByLabel()`](#method-CohortManifest-getCohortsByLabel)

- [`CohortManifest$nCohorts()`](#method-CohortManifest-nCohorts)

- [`CohortManifest$grabCohortById()`](#method-CohortManifest-grabCohortById)

- [`CohortManifest$grabCohortsByTag()`](#method-CohortManifest-grabCohortsByTag)

- [`CohortManifest$grabCohortsByLabel()`](#method-CohortManifest-grabCohortsByLabel)

- [`CohortManifest$createCohortTables()`](#method-CohortManifest-createCohortTables)

- [`CohortManifest$dropCohortTables()`](#method-CohortManifest-dropCohortTables)

- [`CohortManifest$addDependentCohort()`](#method-CohortManifest-addDependentCohort)

- [`CohortManifest$generateCohorts()`](#method-CohortManifest-generateCohorts)

- [`CohortManifest$retrieveCohortCounts()`](#method-CohortManifest-retrieveCohortCounts)

- [`CohortManifest$validateManifest()`](#method-CohortManifest-validateManifest)

- [`CohortManifest$getManifestStatus()`](#method-CohortManifest-getManifestStatus)

- [`CohortManifest$deleteCohort()`](#method-CohortManifest-deleteCohort)

- [`CohortManifest$hardRemoveCohort()`](#method-CohortManifest-hardRemoveCohort)

- [`CohortManifest$cleanupMissing()`](#method-CohortManifest-cleanupMissing)

- [`CohortManifest$clone()`](#method-CohortManifest-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize a new CohortManifest

#### Usage

    CohortManifest$new(
      cohortEntries,
      executionSettings = NULL,
      dbPath = "inputs/cohorts/cohortManifest.sqlite"
    )

#### Arguments

- `cohortEntries`:

  List. A list of CohortDef objects.

- `executionSettings`:

  Object. Execution settings for DBMS cohort generation (optional). If
  provided, enables database operations like generateCohorts(). Can be
  added later via setExecutionSettings(). Defaults to NULL for read-only
  mode.

- `dbPath`:

  Character. Path to the SQLite database. Defaults to
  "inputs/cohorts/cohortManifest.sqlite" Get the manifest as a list of
  CohortDef objects

------------------------------------------------------------------------

### Method `getManifest()`

#### Usage

    CohortManifest$getManifest()

#### Returns

List. A list of CohortDef objects in the manifest, indexed by cohort ID.
Tabulate the manifest as a data frame

------------------------------------------------------------------------

### Method `tabulateManifest()`

#### Usage

    CohortManifest$tabulateManifest()

#### Returns

Data frame. Manifest data with columns: id, label, tags, filePath, hash,
timestamp Get the manifest path

------------------------------------------------------------------------

### Method `getDbPath()`

#### Usage

    CohortManifest$getDbPath()

#### Returns

Character. The path to the SQLite database. Get the execution settings

------------------------------------------------------------------------

### Method `getExecutionSettings()`

#### Usage

    CohortManifest$getExecutionSettings()

#### Returns

Object. The execution settings object for DBMS cohort generation, or
NULL if not set. Set the execution settings

------------------------------------------------------------------------

### Method `setExecutionSettings()`

#### Usage

    CohortManifest$setExecutionSettings(executionSettings)

#### Arguments

- `executionSettings`:

  Object. Execution settings for DBMS cohort generation. Get a specific
  cohort by ID

------------------------------------------------------------------------

### Method `getCohortById()`

#### Usage

    CohortManifest$getCohortById(id)

#### Arguments

- `id`:

  Integer. The cohort ID.

#### Returns

Data frame. A subset of the manifest with columns id, label, tags,
filePath, hash, timestamp for the requested cohort. Get cohorts by tag

------------------------------------------------------------------------

### Method `getCohortsByTag()`

#### Usage

    CohortManifest$getCohortsByTag(tagString)

#### Arguments

- `tagString`:

  Character. A tag in the format "name: value" (e.g., "category:
  primary").

#### Returns

Data frame. A subset of the manifest with columns id, label, tags,
filePath, hash, timestamp for matching cohorts, or NULL if none found.
Get cohorts by label

------------------------------------------------------------------------

### Method `getCohortsByLabel()`

#### Usage

    CohortManifest$getCohortsByLabel(label, matchType = c("exact", "pattern"))

#### Arguments

- `label`:

  Character. The label to search for.

- `matchType`:

  Character. Either "exact" for exact match or "pattern" for pattern
  matching. Defaults to "exact".

#### Returns

Data frame. A subset of the manifest with columns id, label, tags,
filePath, hash, timestamp for matching cohorts, or NULL if none found.

------------------------------------------------------------------------

### Method `nCohorts()`

Get number of cohorts in manifest

#### Usage

    CohortManifest$nCohorts()

#### Returns

Integer. The number of cohorts. Grab a specific cohort by ID

------------------------------------------------------------------------

### Method `grabCohortById()`

#### Usage

    CohortManifest$grabCohortById(id)

#### Arguments

- `id`:

  Integer. The cohort ID.

#### Returns

CohortDef. The CohortDef object with matching ID, or NULL if not found.
Grab cohorts by tag

------------------------------------------------------------------------

### Method `grabCohortsByTag()`

#### Usage

    CohortManifest$grabCohortsByTag(tagString)

#### Arguments

- `tagString`:

  Character. A tag in the format "name: value" (e.g., "category:
  primary").

#### Returns

List. A list of CohortDef objects with matching tags, or NULL if none
found. Grab cohorts by label

------------------------------------------------------------------------

### Method `grabCohortsByLabel()`

#### Usage

    CohortManifest$grabCohortsByLabel(label, matchType = c("exact", "pattern"))

#### Arguments

- `label`:

  Character. The label to search for.

- `matchType`:

  Character. Either "exact" for exact match or "pattern" for pattern
  matching. Defaults to "exact".

#### Returns

List. A list of CohortDef objects with matching labels, or NULL if none
found. Create cohort tables in the database

------------------------------------------------------------------------

### Method `createCohortTables()`

Creates the necessary cohort tables in the target database using the
execution settings. First checks if tables already exist before
attempting creation.

#### Usage

    CohortManifest$createCohortTables()

#### Returns

Invisible NULL. Creates tables in the database and prints status
messages. Drop cohort tables from the database

------------------------------------------------------------------------

### Method `dropCohortTables()`

Drops cohort tables from the target database. Can drop all standard
cohort tables or specific tables. This is useful for cleaning up or
resetting the cohort generation environment.

#### Usage

    CohortManifest$dropCohortTables(tableTypes = NULL)

#### Arguments

- `tableTypes`:

  Character vector. Types of tables to drop. Options: "cohort",
  "inclusion", "inclusion_result", "inclusion_stats", "summary_stats",
  "censor_stats", "checksum". If NULL (default), drops all table types.

#### Returns

Invisible NULL. Drops tables from the database and prints status
messages. Add a dependent cohort to the manifest

------------------------------------------------------------------------

### Method `addDependentCohort()`

Adds a dependent CohortDef object (subset, union, or complement) to the
manifest. Only works for cohorts created with the builder functions in
buildDependentCohorts.R. Validates that parent cohorts exist in this
manifest before adding.

#### Usage

    CohortManifest$addDependentCohort(cohortDef)

#### Arguments

- `cohortDef`:

  A CohortDef object with cohortType of 'subset', 'union', or
  'complement' (created via buildSubsetCohort_Temporal,
  buildUnionCohort, etc.)

#### Returns

Invisibly returns the assigned cohort ID.

------------------------------------------------------------------------

### Method [`generateCohorts()`](https://ohdsi.github.io/picard/reference/generateCohorts.md)

Generates cohorts in the manifest in the target database using the
execution settings. Checks dependency ordering and regenerates dependent
cohorts when parents change. Checks the hash of each cohort definition
and skips generation if the hash matches what's already stored in the
cohort_checksum table. If hashes differ or the cohort is not yet in the
checksum table, regenerates and updates the hash.

#### Usage

    CohortManifest$generateCohorts()

#### Returns

Data frame with execution results including:

- cohort_id: ID of the generated cohort

- label: Label of the cohort

- cohort_type: 'circe', 'subset', 'union', or 'complement'

- depends_on: Comma-separated parent cohort IDs (empty for circe
  cohorts)

- execution_time_min: Time taken to generate (0 for skipped)

- status: 'Success', 'Skipped - already generated', 'Dependency
  skipped', or error message

- dependency_status: 'Not applicable' for circe, 'Parent changed' or
  'Unchanged' for dependent

------------------------------------------------------------------------

### Method `retrieveCohortCounts()`

Retrieve cohort counts from the database

Retrieves entry and subject counts for cohorts from the cohort table in
the target database. Can retrieve counts for all cohorts or a specific
subset. Enriches the results with metadata (label and tags) from the
CohortDef objects in the manifest.

#### Usage

    CohortManifest$retrieveCohortCounts(cohortIds = NULL)

#### Arguments

- `cohortIds`:

  Integer vector. Optional. Specific cohort IDs to retrieve counts for.
  If NULL (default), returns counts for all cohorts.

#### Returns

Data frame with columns:

- cohort_id: The cohort definition ID

- label: The cohort label from the CohortDef object

- tags: The cohort tags formatted as a string

- cohort_entries: Total number of cohort records

- cohort_subjects: Number of distinct subjects in the cohort

------------------------------------------------------------------------

### Method `validateManifest()`

Validate manifest and return status of all cohorts

#### Usage

    CohortManifest$validateManifest()

#### Returns

A tibble with columns: id, label, status (active/missing/deleted),
deleted_at, file_exists

------------------------------------------------------------------------

### Method `getManifestStatus()`

Get summary status of manifest

#### Usage

    CohortManifest$getManifestStatus()

#### Returns

List with elements: active_count, missing_count, deleted_count,
next_available_id

------------------------------------------------------------------------

### Method `deleteCohort()`

Soft delete a cohort (mark as deleted, preserve record)

#### Usage

    CohortManifest$deleteCohort(id, reason = NULL)

#### Arguments

- `id`:

  Integer. The cohort ID to delete.

- `reason`:

  Character. Optional reason for deletion.

#### Returns

Invisibly returns TRUE if successful, FALSE otherwise.

------------------------------------------------------------------------

### Method `hardRemoveCohort()`

Hard delete a cohort (removes the record from database, irreversible)

#### Usage

    CohortManifest$hardRemoveCohort(id)

#### Arguments

- `id`:

  Integer. The cohort ID to permanently remove.

#### Returns

Invisibly returns TRUE if successful, FALSE otherwise.

------------------------------------------------------------------------

### Method `cleanupMissing()`

Clean up missing cohorts from manifest

#### Usage

    CohortManifest$cleanupMissing(keep_trace = TRUE)

#### Arguments

- `keep_trace`:

  Logical. If TRUE, marks missing as deleted with timestamp (soft
  delete). If FALSE, permanently removes from database (hard delete).
  Defaults to TRUE.

#### Returns

Invisibly returns NULL. Displays summary of cleanup actions.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    CohortManifest$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
