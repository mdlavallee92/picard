# Developing the Pipeline

## Introduction

Once your repository is initialized, the next phase is to develop your analysis pipeline. This document walks through the complete development workflow, from defining inputs through testing your code.

## Development Workflow Overview

The typical workflow is:

1. Finalize Git and renv setup
2. Create your development branch
3. Define your inputs (cohorts and concept sets)
4. Create analysis tasks and supporting code
5. Commit your changes with `saveWork()`
6. Test individual tasks and the full pipeline
7. Iterate until your analysis is complete

## Step 1: Finalize Git and renv Setup

**Git:** You already have a local repository. If you provided `gitRemote` during setup, your code is already synced. If not, see the "Launching a Study" guide to push your code to a remote.

**renv:** This is your responsibility. It's **highly encouraged** to set this up immediately:

```r
renv::init()
```

This captures your current R environment. You should set up renv on main before switching to develop.

## Step 2: Create Your Development Branch

All development work happens on the `develop` branch (never on `main`):

```bash
git checkout -b develop
git push -u origin develop
```

All subsequent work will be done here and tested before any production execution.

## Step 3: Define Your Inputs

Before writing analysis code, you need to define the populations and phenotypes. See "Loading Inputs" guide for detailed guidance on:

- Creating cohort definitions
- Importing from ATLAS
- Building dependent cohorts
- Managing manifests

## Step 4: Create Analysis Tasks and Supporting Code

Analysis happens in the `analysis/` folder, which has two key subdirectories:

**Tasks** (`analysis/tasks/`) - Main workflow files executed by the pipeline
**Source** (`analysis/src/`) - Supporting functions and utilities used by tasks

### Creating a Task

Use `makeTaskFile()` to scaffold a new task:

```r
makeTaskFile(
  nameOfTask = "DescriptiveStats",
  author = "Jane Doe",
  description = "Generate descriptive statistics for primary cohort",
  projectPath = here::here(),
  openFile = TRUE
)
```

This creates a standardized R script in `analysis/tasks/` with a template structure. The filename is automatically generated as `01_descriptive_stats.R`.

**Task Naming Convention:** `makeTaskFile()` automatically handles the numbering based on existing files in your `analysis/tasks/` folder. You simply provide the task name (e.g., `"DescriptiveStats"`), and `makeTaskFile()` will:
- Count existing task files
- Generate the next sequential number
- Convert your task name to snake_case
- Create the file as `NN_task_name.R`

Tasks execute in alphabetical order, so the automatic numbering controls the execution sequence.

### Creating Supporting Source Files

For reusable utility functions, create files in `analysis/src/` using `makeSrcFile()`:

```r
makeSrcFile(
  fileName = "custom_analysis_functions",
  author = "Jane Doe",
  description = "Helper functions for cohort calculations and data validation"
)
```

This creates a standardized R script in `analysis/src/custom_analysis_functions.R` with a template structure for your utility functions.

**Important:** Treat source files like R package development:

- **Use `package::function()` notation** instead of `library()` calls:
  ```r
  # Good: Use explicit namespace
  result <- dplyr::filter(data, age > 18)
  
  # Avoid: Loading entire library
  # library(dplyr)
  # result <- filter(data, age > 18)
  ```

- **Document each function** with a clear comment block describing:
  - What the function does
  - What inputs it expects
  - What it returns
  
  Example:
  ```r
  # Purpose: Calculate age in years from birth date
  # Inputs: birth_date (Date or character in YYYY-MM-DD format)
  # Returns: Numeric age in years
  calculate_age <- function(birth_date) {
    birth_date <- as.Date(birth_date)
    age <- as.numeric(lubridate::interval(birth_date, Sys.Date()), "years")
    return(floor(age))
  }
  ```

Then source these files from your tasks in the **B. Dependencies** section at the top of the task file:

```r
# B. Dependencies ---------------

library(picard)
library(DatabaseConnector)
library(tidyverse)

# Source utility functions
source(here::here("analysis/src/custom_analysis_functions.R"))
```

### Creating SqlRender SQL Queries

For parameterized SQL queries, create files in `analysis/src/sql/` using `makeSrcSqlFile()`:

```r
makeSrcSqlFile(
  fileName = "drug_exposure_summary",
  author = "Jane Doe",
  description = "Create a summary table of drug exposure by observation period"
)
```

This creates a standardized SQL file in `analysis/src/sql/drug_exposure_summary.sql` with placeholders for SqlRender parameters.

**Important:** SqlRender uses `@paramName` notation for substitution. Here's a realistic example:

```sql
/* 
Document your parameters at the top:
  @cdmDatabaseSchema - Schema containing OMOP CDM tables
  @workDatabaseSchema - Schema for output tables
  @workTableName - Name of the intermediate work table to create
  @studyStartDate - Start date for filtering
  @studyEndDate - End date for filtering
*/

-- Create intermediate table of drug exposures by observation period
CREATE TABLE @workDatabaseSchema.@workTableName AS

WITH obs_periods AS (
  -- Get all observation periods for study participants
  SELECT 
    person_id,
    observation_period_start_date,
    observation_period_end_date
  FROM @cdmDatabaseSchema.observation_period
  WHERE observation_period_start_date >= '@studyStartDate'
    AND observation_period_start_date <= '@studyEndDate'
)

SELECT * FROM obs_periods;
```

**Best Practice:** Wrap your SQL queries in utility functions stored in `analysis/src/` files, then call those functions from your tasks.

### Task File Structure

Each task follows a standardized template with sections:

**A. Setup** - Load configurations and execution settings
**B. Dependencies** - Library imports and source file loading
**C. Main Logic** - Task-specific analysis code
**D. Save Results** - Write outputs to exec/results/

Example task structure:

```r
# ============================================================================
# Task: 01_descriptiveStats.R
# Author: Jane Doe
# Description: Generate descriptive statistics for primary cohort
# ============================================================================

# A. Setup ---------------------------------------------------------------

library(picard)
library(tidyverse)

# Load configuration
projectPath <- here::here()
settings <- createExecutionSettingsFromConfig()

# B. Dependencies --------------------------------------------------------

source(here::here("analysis/src/custom_functions.R"))

# C. Main Logic ----------------------------------------------------------

# Load cohort counts (generated automatically before task execution)
cohort_counts <- readr::read_csv(
  here::here("exec/results/[db_id]/[version]/00_buildCohorts/cohortCounts.csv")
)

# Generate summary statistics
summary_table <- cohort_counts %>%
  dplyr::group_by(cohortId) %>%
  dplyr::summarise(
    total_subjects = sum(cohort_subjects),
    total_records = sum(cohort_entries),
    mean_records_per_subject = mean(cohort_entries / cohort_subjects)
  )

# D. Save Results --------------------------------------------------------

output_path <- here::here("exec/results/[db_id]/[version]/01_descriptiveStats")
fs::dir_create(output_path, recurse = TRUE)

readr::write_csv(summary_table, file.path(output_path, "summary.csv"))
```

## Step 5: Commit Your Changes

Use `saveWork()` to manage your commits:

```r
saveWork(
  message = "Add cohort definitions and initial descriptive stats task",
  branch = "develop"
)
```

This function:
- Commits all changes to git
- Prompts for meaningful commit message
- Ensures code is ready for sharing

## Step 6: Testing Your Tasks

### Test Individual Tasks

```r
testStudyTask(
  taskId = 1,
  configBlock = "my_cdm"
)
```

This runs a specific task in isolation, useful for debugging.

### Test Full Pipeline

```r
# Run full pipeline in development mode (truncated data or subset)
testStudyPipeline(
  configBlock = "my_cdm",
  verbose = TRUE
)
```

### Review Results

Results are saved to `exec/results/[database]/[version]/[task]/`:

```r
# List all result files
list.files("exec/results", recursive = TRUE)

# Read specific results
results <- readr::read_csv("exec/results/primary_db/dev/01_descriptiveStats/results.csv")
```

## Step 7: Iterate

Repeat steps 4-6:
1. Modify task logic
2. Test the task
3. Commit changes
4. Move to next task

---

## Best Practices for Development

1. **Use relative paths** - Always use `here::here()` for project-relative paths
2. **Comment your code** - Explain WHY you're doing something, not just WHAT
3. **Test early and often** - Don't wait until you have all tasks done to test
4. **Commit frequently** - Small, focused commits are easier to debug and review
5. **Document dependencies** - Clearly specify what each task requires and produces
6. **Use consistent naming** - Follow naming conventions in existing code
7. **Handle errors gracefully** - Use try/tryCatch to manage unexpected failures

---

## Common Patterns

### Loading Configuration within a Task

```r
settings <- createExecutionSettingsFromConfig(configBlock = "my_cdm")
connection <- settings$getConnection()
```

### Reading OMOP Tables

```r
cdm_schema <- settings$cdmDatabaseSchema

sql <- glue::glue("SELECT * FROM {cdm_schema}.condition_occurrence")
conditions <- DatabaseConnector::querySql(connection, sql)
```

### Writing Results

```r
output_dir <- here::here(glue::glue("exec/results/{db_id}/{version}/01_descriptiveStats"))
fs::dir_create(output_dir, recurse = TRUE)

readr::write_csv(results, file.path(output_dir, "results.csv"))
```

---

## Next Steps

1. **Create all required tasks** - Base your task structure on your Evidence Generation Plan
2. **Test thoroughly** - Use individual and full pipeline testing
3. **Document your logic** - Add comments and maintain a clear code structure
4. **Prepare for production** - When confident in your code, see "Running the Pipeline"
