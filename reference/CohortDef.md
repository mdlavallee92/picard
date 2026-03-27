# CohortDef R6 Class

CohortDef R6 Class

CohortDef R6 Class

## Details

An R6 class that stores key information about CIRCE cohorts that need to
be generated for a study.

The CohortDef class manages cohort metadata and SQL generation. Upon
initialization, it loads and validates cohort definitions from either
JSON (CIRCE format) or SQL files, and creates a hash to uniquely
identify the generated SQL.

## Active bindings

- `label`:

  character to set the label to. If missing, returns the current label.

- `tags`:

  list of the values to set the tags to. If missing, returns the current
  label.

## Methods

### Public methods

- [`CohortDef$new()`](#method-CohortDef-new)

- [`CohortDef$getFilePath()`](#method-CohortDef-getFilePath)

- [`CohortDef$getSql()`](#method-CohortDef-getSql)

- [`CohortDef$getHash()`](#method-CohortDef-getHash)

- [`CohortDef$getId()`](#method-CohortDef-getId)

- [`CohortDef$setId()`](#method-CohortDef-setId)

- [`CohortDef$formatTagsAsString()`](#method-CohortDef-formatTagsAsString)

- [`CohortDef$getCohortType()`](#method-CohortDef-getCohortType)

- [`CohortDef$setCohortType()`](#method-CohortDef-setCohortType)

- [`CohortDef$getDependencies()`](#method-CohortDef-getDependencies)

- [`CohortDef$setDependencies()`](#method-CohortDef-setDependencies)

- [`CohortDef$getDependencyHash()`](#method-CohortDef-getDependencyHash)

- [`CohortDef$setDependencyHash()`](#method-CohortDef-setDependencyHash)

- [`CohortDef$clone()`](#method-CohortDef-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize a new CohortDef

#### Usage

    CohortDef$new(label, tags = list(), filePath)

#### Arguments

- `label`:

  Character. The common name of the cohort.

- `tags`:

  List. A named list of tags that give metadata about the cohort.

- `filePath`:

  Character. Path to the cohort file in inputs/cohorts folder (can be
  .json or .sql). Get the file path

------------------------------------------------------------------------

### Method `getFilePath()`

#### Usage

    CohortDef$getFilePath()

#### Returns

Character. Relative path to the cohort file. Get the generated SQL

------------------------------------------------------------------------

### Method `getSql()`

#### Usage

    CohortDef$getSql()

#### Returns

Character. The SQL definition of the cohort. Get the SQL hash

------------------------------------------------------------------------

### Method `getHash()`

#### Usage

    CohortDef$getHash()

#### Returns

Character. MD5 hash of the current SQL definition. Get the cohort ID

------------------------------------------------------------------------

### Method `getId()`

#### Usage

    CohortDef$getId()

#### Returns

Integer. The cohort ID, or NA_integer\_ if not set. Set the cohort ID
(internal use)

------------------------------------------------------------------------

### Method `setId()`

#### Usage

    CohortDef$setId(id)

#### Arguments

- `id`:

  Integer. The cohort ID to set. Format tags as string

------------------------------------------------------------------------

### Method `formatTagsAsString()`

#### Usage

    CohortDef$formatTagsAsString()

#### Returns

Character. Tags formatted as "name: value \| name: value". Get the
cohort type

------------------------------------------------------------------------

### Method `getCohortType()`

#### Usage

    CohortDef$getCohortType()

#### Returns

Character. One of 'source', 'subset', 'union', 'complement'. Default:
'source'. Set the cohort type (internal use)

------------------------------------------------------------------------

### Method `setCohortType()`

#### Usage

    CohortDef$setCohortType(cohortType)

#### Arguments

- `cohortType`:

  Character. One of 'circe', 'subset', 'union', 'complement'. Get
  dependency information

------------------------------------------------------------------------

### Method `getDependencies()`

#### Usage

    CohortDef$getDependencies()

#### Returns

List with elements: cohort_ids (integer vector), rule (list of
parameters). Set dependency information (internal use)

------------------------------------------------------------------------

### Method `setDependencies()`

#### Usage

    CohortDef$setDependencies(dependsOnCohortIds, dependencyRule)

#### Arguments

- `dependsOnCohortIds`:

  Integer vector of parent cohort IDs.

- `dependencyRule`:

  List of dependency parameters. Get the dependency hash

------------------------------------------------------------------------

### Method `getDependencyHash()`

#### Usage

    CohortDef$getDependencyHash()

#### Returns

Character. Hash of dependencies for change detection, or NULL if none.
Set the dependency hash (internal use)

------------------------------------------------------------------------

### Method `setDependencyHash()`

#### Usage

    CohortDef$setDependencyHash(depHash)

#### Arguments

- `depHash`:

  Character. Hash to set.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    CohortDef$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
