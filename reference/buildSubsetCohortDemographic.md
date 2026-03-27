# Build a Subset Cohort Definition (Demographic)

Creates a SQL file and metadata for a subset cohort based on
person-level demographics. Returns a CohortDef object ready to add to a
CohortManifest.

## Usage

``` r
buildSubsetCohortDemographic(
  label,
  baseCohortId,
  minAge = NULL,
  maxAge = NULL,
  genderConceptIds = NULL,
  raceConceptIds = NULL,
  ethnicityConceptIds = NULL,
  cohortsDirectory = NULL,
  manifest = NULL
)
```

## Arguments

- label:

  Character. User-friendly name for the subset (e.g., "CKD - Males
  40-75")

- baseCohortId:

  Integer. The cohort ID to subset.

- minAge:

  Integer. Minimum age at cohort start. NULL = no minimum. Default: NULL

- maxAge:

  Integer. Maximum age at cohort start. NULL = no maximum. Default: NULL

- genderConceptIds:

  Numeric vector. Gender concept IDs to include. NULL = all. Default:
  NULL

- raceConceptIds:

  Numeric vector. Race concept IDs to include. NULL = all. Default: NULL

- ethnicityConceptIds:

  Numeric vector. Ethnicity concept IDs to include. NULL = all. Default:
  NULL

- cohortsDirectory:

  Character. Path to inputs/cohorts/. Uses study hierarchy if not
  provided.

- manifest:

  CohortManifest object (optional). If provided, validates that base
  cohort exists. Recommended to ensure referential integrity. If NULL, a
  warning is issued.

## Value

A CohortDef object with cohortType='subset' and dependencies set.

## Details

Creates three files:

- SQL file:
  `inputs/cohorts/derived/subset_demo/subset_demo_cohort_{baseCohortId}.sql`

- Metadata JSON: Same path with `.json` extension

- Context file: `.metadata` with filter description
