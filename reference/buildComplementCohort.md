# Build a Complement Cohort Definition

Creates a SQL file and metadata for a complement cohort that excludes
subjects from a population cohort based on other cohorts. Returns a
CohortDef object ready to add to a CohortManifest.

## Usage

``` r
buildComplementCohort(
  label,
  populationCohortId,
  excludeCohortIds,
  complementType = "exclude_any",
  cohortsDirectory = NULL,
  manifest = NULL
)
```

## Arguments

- label:

  Character. User-friendly name for the complement (e.g., "Females
  without Pregnancy")

- populationCohortId:

  Integer. The population/base cohort ID.

- excludeCohortIds:

  Numeric vector (minimum 1). Cohort IDs to exclude.

- complementType:

  Character. One of 'exclude_any', 'exclude_all'. Default: 'exclude_any'

  - 'exclude_any': remove subjects in ANY exclude cohort

  - 'exclude_all': remove subjects only if in ALL exclude cohorts

- cohortsDirectory:

  Character. Path to inputs/cohorts/. Uses study hierarchy if not
  provided.

- manifest:

  CohortManifest object (optional). If provided, validates that
  population and exclude cohorts exist. Recommended to ensure
  referential integrity. If NULL, a warning is issued.

## Value

A CohortDef object with cohortType='complement' and dependencies set.

## Details

Creates three files:

- SQL file:
  `inputs/cohorts/derived/complement/complement_cohort_{popId}_exclude_{excludeIds}.sql`

- Metadata JSON: Same path with `.json` extension

- Context file: `.metadata` with rule description
