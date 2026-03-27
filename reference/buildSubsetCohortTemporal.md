# Build a Subset Cohort Definition (Temporal)

Creates a SQL file and metadata for a subset cohort based on temporal
filtering between two cohorts. Returns a CohortDef object ready to add
to a CohortManifest.

## Usage

``` r
buildSubsetCohortTemporal(
  label,
  baseCohortId,
  filterCohortId,
  temporalOperator = "during",
  temporalStartOffset = 0L,
  temporalEndOffset = 0L,
  cohortsDirectory = NULL,
  manifest = NULL
)
```

## Arguments

- label:

  Character. User-friendly name for the subset (e.g., "CKD with T2D
  prior")

- baseCohortId:

  Integer. The cohort ID to subset.

- filterCohortId:

  Integer. The cohort ID to use for temporal filtering.

- temporalOperator:

  Character. One of 'during', 'before', 'after', 'overlapping'. Default:
  'during'

- temporalStartOffset:

  Integer. Window start relative to base cohort (negative = before).
  Default: 0

- temporalEndOffset:

  Integer. Window end relative to base cohort. Default: 0

- cohortsDirectory:

  Character. Path to inputs/cohorts/. Uses study hierarchy if not
  provided.

- manifest:

  CohortManifest object (optional). If provided, validates that base
  cohorts exist. Recommended to ensure referential integrity. If NULL, a
  warning is issued.

## Value

A CohortDef object with cohortType='subset' and dependencies set.

## Details

Creates three files:

- SQL file:
  `inputs/cohorts/derived/subset/subset_cohort_{baseCohortId}_cohort_{filterCohortId}.sql`

- Metadata JSON: Same path with `.json` extension (parameters for
  execution)

- Context file: `.metadata` with rule description
