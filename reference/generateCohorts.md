# Generate Cohorts for Pipeline Execution

Loads the cohort manifest, displays the cohorts to be generated,
optionally prompts for user confirmation, and then generates the cohorts
and retrieves their counts. This function serves as the foundational
step for all subsequent analytical tasks in the pipeline.

## Usage

``` r
generateCohorts(executionSettings, pipelineVersion, override = FALSE)
```

## Arguments

- executionSettings:

  An ExecutionSettings object containing database configuration for
  cohort generation.

- pipelineVersion:

  Character. The pipeline version used to organize the output folder
  structure. Output will be saved to
  exec/results/databaseName/pipelineVersion/00_buildCohorts/

- override:

  Logical. If TRUE, skips the user confirmation prompt and proceeds
  directly with cohort generation. Defaults to FALSE.

## Value

Invisibly returns the cohort counts data frame (id, label, tags,
cohort_entries, cohort_subjects). Also saves counts to cohortCounts.csv
in the output folder.
