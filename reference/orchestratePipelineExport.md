# Orchestrate Pipeline Export with Merging and QC

Orchestrates complete pipeline export process: merges results across all
tasks for a specified pipeline version, generates reference files
(cohortKey, databaseInfo, schema_review), runs QC validation on cohort
completeness, and generates execution metadata.

## Usage

``` r
orchestratePipelineExport(
  pipelineVersion,
  dbIds,
  resultsPath = here::here("exec/results"),
  exportPath = here::here("dissemination/export/merge"),
  cohortsFolderPath = here::here("inputs/cohorts")
)
```

## Arguments

- pipelineVersion:

  Character. Pipeline version (e.g., "1.0.0")

- dbIds:

  Character vector of database configuration IDs from config.yml

- resultsPath:

  Character. Path to results root folder. Defaults to "exec/results"

- exportPath:

  Character. Path where combined results will be saved. Defaults to
  "dissemination/export/merge"

- cohortsFolderPath:

  Character. Path to cohorts folder for the CohortManifest. Defaults to
  "inputs/cohorts". If the path exists and contains a cohort manifest,
  generates a cohortKey reference file with id, label, and tags.

## Value

Data frame summarizing all merged tasks with columns:

- taskName: Name of the task

- fileCount: Number of result files found for that task

- totalRows: Total rows across all result files

- filesExported: Comma-separated list of exported file names

## Details

The function orchestrates the complete pipeline export:

1.  Validates code state (git commit must be clean)

2.  Validates environment state and snapshots renv.lock

3.  Discovers tasks for the specified pipeline version

4.  Merges results across all databases for each task via
    importAndBind()

5.  Generates reference files: cohortKey.csv, databaseInfo.csv

6.  Reviews schema of exported files (schema_review.csv)

7.  Validates cohort completeness (qc_cohortValidation.csv)

8.  Generates execution metadata (qc_processMeta.csv)

Output files created in version export folder:

- Merged result CSVs (per task)

- cohortKey.csv: Cohort reference with ids and metadata

- databaseInfo.csv: Databases included in merge operation

- schema_review.csv: Column-level inspection of all files

- qc_cohortValidation.csv: Cohort completeness validation results

- qc_processMeta.csv: Execution metadata and summary statistics

  - executionTimestamp: When the export ran

  - pipelineVersion: Version being exported

  - codeCommitSha: Git commit SHA of code at execution time

  - lockfileHash: Hash of renv.lock for dependency reproducibility

  - filesExported: Comma-separated list of exported file names

The function:

1.  Scans the first database's version folder to discover available
    tasks

2.  For each task found, calls importAndBind() to merge across databases

3.  Tracks which files were successfully merged

4.  Returns a summary data frame of the merge operation

Expected folder structure:

    exec/results/
      databaseName1/
        version/
          task1/
            results.csv
          task2/
            results.csv
      databaseName2/
        version/
          task1/
            results.csv
          task2/
            results.csv
