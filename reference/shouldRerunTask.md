# Check if Task Needs to be Rerun

Determines whether a task needs to be rerun by checking:

1.  Task file modifications (file hash comparison)

2.  Dependency file modifications (extracted from source() calls)

3.  Cohort generation changes (hash comparison in database)

4.  Previous run errors (checked in logs and history)

5.  Version changes

## Usage

``` r
shouldRerunTask(
  taskFile,
  configBlock,
  executionSettings,
  pipelineVersion,
  tasksFolderPath = here::here("analysis/tasks")
)
```

## Arguments

- taskFile:

  Character. Name or path of the task file (e.g., "task1.R")

- configBlock:

  Character. The config block name (e.g., "optum_dod")

- executionSettings:

  ExecutionSettings object

- pipelineVersion:

  Character. Current pipeline version (e.g., "1.0.0")

- tasksFolderPath:

  Character. Path to tasks folder (default:
  here::here("analysis/tasks"))

## Value

List with elements:

- should_rerun: Logical. TRUE if task should be rerun

- reasons: Character vector. Why task should be rerun

- last_run_info: List with previous run details (time, version, status)

- task_file_hash: Current hash of task file

- cohort_hash_status: List comparing manifest hashes to database hashes

## Details

Creates/updates exec/logs/task_run_history.csv tracking:

- task_name, config_block, last_run_time, pipeline_version

- task_file_hash, cohort_hash_match, status, error_message
