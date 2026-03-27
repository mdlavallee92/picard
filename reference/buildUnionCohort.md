# Build a Union Cohort Definition

Creates a SQL file and metadata for a union cohort that combines
multiple input cohorts. Returns a CohortDef object ready to add to a
CohortManifest.

## Usage

``` r
buildUnionCohort(
  label,
  cohortIds,
  unionRule = "any",
  atLeastN = 2L,
  cohortsDirectory = NULL,
  manifest = NULL
)
```

## Arguments

- label:

  Character. User-friendly name for the union (e.g., "Chronic Kidney
  Disease Phenotypes")

- cohortIds:

  Numeric vector (minimum 2). Cohort IDs to union.

- unionRule:

  Character. One of 'any', 'all', 'at_least_n'. Default: 'any'

  - 'any': subjects appearing in ANY input cohort

  - 'all': subjects appearing in ALL input cohorts

  - 'at_least_n': subjects appearing in at least N cohorts

- atLeastN:

  Integer. Number of cohorts required (only if unionRule='at_least_n').
  Default: 2

- cohortsDirectory:

  Character. Path to inputs/cohorts/. Uses study hierarchy if not
  provided.

- manifest:

  CohortManifest object (optional). If provided, validates that all
  input cohorts exist. Recommended to ensure referential integrity. If
  NULL, a warning is issued.

## Value

A CohortDef object with cohortType='union' and dependencies set.

## Details

Creates three files:

- SQL file:
  `inputs/cohorts/derived/union/union_cohorts_{cohort_id_list}.sql`

- Metadata JSON: Same path with `.json` extension

- Context file: `.metadata` with rule description
