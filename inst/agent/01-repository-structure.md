# The Ulysses Standard Repository Structure

## Introduction

Picard is built on the Ulysses framework, which follows the philosophy that real-world evidence (RWE) studies should be organized and versioned as software projects. Just as databases require a schema to organize data, RWE studies benefit from a standard directory structure to organize code, inputs, analyses, and outputs. This standardization enables:

- **Reproducibility:** Anyone can understand the project structure at a glance
- **Collaboration:** Multiple contributors follow the same conventions
- **Automation:** Consistent organization enables reliable workflows and tooling
- **Version control:** Clear separation of concerns makes git history more meaningful

Picard uses the Ulysses repository structure, adding specialized directories and configuration for cohort-based studies, Evidence Generation Plans, and results dissemination. This document describes the standard Ulysses repository structure created when you initialize a project using `launchUlyssesRepo()`.

## Pipeline Workflow and Folder Organization

The Ulysses repository organizes folders to match the flow of a real-world evidence study:

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. META & CONFIG                                                │
│    (config.yml, README.md, NEWS.md, main.R, test_main.R)       │
│         ↓                                                        │
│ 2. INPUTS                                                       │
│    inputs/cohorts/ + inputs/conceptSets/                      │
│    (Define phenotypes, cohorts, covariates)                    │
│         ↓                                                        │
│ 3. ANALYSIS                                                     │
│    analysis/tasks/ + analysis/src/ + analysis/migrations/     │
│    (Execute analyses, generate statistics)                      │
│         ↓                                                        │
│ 4. EXECUTION OUTPUT                                             │
│    exec/results/[database]/[version]/[task]/                  │
│    (Raw results by task, database, version)                     │
│         ↓                                                        │
│ 5. DISSEMINATION                                                │
│    dissemination/export/ + dissemination/quarto/               │
│    (Format results, create Study Hub website)                   │
└─────────────────────────────────────────────────────────────────┘
```

**Workflow sequence:**
1. Initialize with metadata (config.yml defines databases and credentials)
2. Load or create inputs (cohorts and concept sets)
3. Execute analysis tasks (code in analysis/tasks runs using inputs)
4. Raw results written to exec/results organized by database and version
5. Post-processing (migrations) and formatting (excel, CSV)
6. Dissemination via Study Hub (quarto website) and formatted exports

## Ulysses Repository Outline

A newly initialized Picard study has the following high-level structure:

```
study-repository/
├── analysis/          # Study analysis code and workflows
├── inputs/            # Cohort definitions and concept sets
├── dissemination/     # Results and evidence outputs
├── exec/              # Execution artifacts and logs
├── docs/              # Generated documentation (pkgdown)
├── extras/            # Reference scripts and development files
├── config.yml         # Project configuration
├── main.R             # Production pipeline execution script
├── README.md          # Project overview
├── NEWS.md            # Release notes and changelog
├── .gitignore         # Git configuration
└── study.Rproj        # RStudio project file
```

## Elements of the Ulysses Repository

### Vital Files

These files are essential to the project and should be maintained throughout its lifecycle.

#### project.Rproj

An RStudio project file that configures the working directory and development environment. The Ulysses structure uses this to ensure consistent behavior across team members. When you open this file in RStudio, the working directory is automatically set to the project root.

If using VS Code, Picard supports project detection through `.code-workspace` files and agent instructions.

#### .gitignore

Prevents sensitive files and intermediate outputs from being committed to version control. The standard `.gitignore` for Ulysses repository includes:

- `renv/` - Local package library snapshots (renv-specific files)
- `exec/` - Execution results and temporary files
- `.env` - Environment variables and credentials
- `*.log` - Log files
- RStudio temporary files (`.Rhistory`, `.RData`, etc.)

This ensures that your git repository contains only source code and documentation, not generated outputs or sensitive credentials.

#### README.md

The README serves as the project's front door, communicating key study information: description, objectives, key personnel, status, and links to vital resources. The README includes:

- **Study metadata:** Title, ID, start/end dates, study type, therapeutic area
- **Status badges:** Current version and project status
- **Tags:** Keywords for searching similar studies within your organization
- **Links:** References to ATLAS, protocols, publications, and repository

Ulysses auto-generates a README template when you launch a project. You should customize the Study Description section to clearly explain your research question and study design, following your organization's documentation standards.

#### NEWS.md

Tracks changes across study versions. When you run a production pipeline with `execStudyPipeline()`, the Ulysses workflow automatically updates NEWS.md with version information and change summaries. This creates an audit trail of what changed in each release.

#### config.yml

Central configuration file specifying parameters needed to establish database connections. Uses YAML format with two section types:

- **default:** Universal study settings (project name, version)
- **block headers:** Database-specific configurations (dbms, credentials, schemas)

When you source a block header in a task file, the pipeline runs using only that block's configuration, enabling multi-database studies.

**Important:** Connection details vary by database system. The codebase distinguishes between:

- **Snowflake:** Uses `connectionString` format (JDBC connection string)
- **PostgreSQL, SQL Server, MySQL, Oracle, Redshift:** Use `server` and `port` fields

**Protecting Credentials with !expr:**

The `!expr` tag (from the config package) allows you to evaluate R code within the config file. This is critical for security: it enables pulling credentials from environment variables rather than storing them as plain text in config.yml.

```yaml
user: !expr Sys.getenv('dbUser')        # Evaluates R code: retrieves DB_USER from environment
password: !expr Sys.getenv('dbPassword') # Evaluates R code: retrieves DB_PASSWORD from environment
```

**Best practice:** Always use `!expr` with a secure credential storage system. Never store passwords or connection strings as plain text in config.yml or commit them to git.

**Common credentials:**

- `dbms`: Database type (snowflake, sql server, postgresql, mysql, oracle, redshift)
- `user`: Database username (from environment variable via `!expr Sys.getenv()`)
- `password`: Database password (from environment variable)
- `databaseName`: Internal reference name (snake_case with database + snapshot date)
- `databaseLabel`: Pretty name for output formatting
- `cdmDatabaseSchema`: Schema containing OMOP CDM tables (format: `schema` or `database.schema`)
- `vocabDatabaseSchema`: Schema containing vocabulary tables (usually same as cdmDatabaseSchema)
- `workDatabaseSchema`: Schema where user has write access (for cohort tables and intermediary work)
- `tempEmulationSchema`: Optional schema for temp tables (snowflake, oracle)
- `cohortTable`: Name of cohort table to create (default: `{repoName}_{databaseName}`)

#### main.R

The primary execution script for running the study pipeline in production mode. This file is initialized by Ulysses when launching a new repository using `launchUlyssesRepo()`. The main.R file coordinates the execution of all analytical tasks and follows a structured workflow: loading dependencies, initializing manifests for cohorts and concept sets, populating manifests from external sources (such as ATLAS), executing the pipeline on specified databases, and performing post-execution steps such as building the study hub and archiving results.

### Analysis Folder

Contains the study code organized into executable analysis tasks.

#### analysis/tasks/

Individual R scripts that perform analytical steps. Each task is a self-contained unit that:

- Loads necessary inputs (cohorts, concept sets, configuration)
- Performs a specific analytical step
- Saves results to a standardized output location

**Note:** Cohort generation is a built-in Picard feature handled automatically when you run the pipeline. You do not create a cohort generation task file. Tasks start after cohorts are generated.

Tasks are named sequentially (01_, 02_, etc.) and executed in order:

```
analysis/tasks/
├── 01_descriptiveStats.R
├── 02_primaryAnalysis.R
├── 03_sensitivityAnalysis.R
```

Each task is independent and can be tested individually during development using `testStudyTask()`.

#### analysis/src/

Supporting utility functions and SQL query templates. Including:

- **R functions:** Reusable helper functions written in analysis/src/custom_functions.R
- **SQL templates:** Parameterized SQL queries in analysis/src/sql/

These support files are sourced from within tasks to keep code organized and modular.

### Inputs Folder

Contains study population and phenotype definitions.

#### inputs/cohorts/

Cohort definitions in JSON format, typically exported from ATLAS. Also contains:

- `cohortsLoad.csv` - Metadata file for organizing cohort descriptions and metadata
- `json/` - Subdirectory containing ATLAS JSON definitions

#### inputs/conceptSets/

Concept set definitions for phenotypes. Organized similarly to cohorts:

- `conceptSetsLoad.csv` - Metadata and descriptions
- `json/` - ATLAS JSON definitions

### Outputs and Dissemination

#### exec/

Contains execution artifacts that should NOT be committed to git.

**exec/results/[database]/[version]/[task]/** - Raw output organized by:
- **database**: Which database was analyzed
- **version**: Study version (e.g., 1.0.0)
- **task**: Which analysis task produced the result

Example structure:
```
exec/results/
├── primary_db/
│   ├── 1.0.0/
│   │   ├── 00_buildCohorts/cohortCounts.csv
│   │   ├── 01_descriptiveStats/stats.csv
│   │   └── 02_primaryAnalysis/results.csv
│   └── 1.1.0/
│       ├── 00_buildCohorts/cohortCounts.csv
│       └── ...
└── secondary_db/
    └── 1.0.0/
        └── ...
```

**exec/logs/** - Execution logs showing pipeline run details

#### dissemination/

Published results and formatted outputs ready for external use.

**dissemination/export/merge/v{version}/** - Results merged across all databases:
- Combines raw results from all databases for each task
- Adds reference files (cohortKey.csv, databaseInfo.csv)
- Includes QC and validation reports

**dissemination/quarto/** - Study Hub website source files (Quarto format)

### Git Agent Configuration

#### .agent/

Created during repository initialization. Contains:

- `copilot-instructions.md` - Agent context specific to this study
- `reference-docs/` - Copy of picard documentation for AI assistant reference

This helps AI assistants understand the study context, folder structure, and picard workflow when working in the repository.

## Key Design Principles

1. **Sequential Execution:** Tasks in `analysis/tasks/` execute in alphabetical order (01_, 02_, etc.), controlling the pipeline flow

2. **Input-Process-Output:** Clear separation between definitions (inputs/), processing (analysis/), and results (exec/, dissemination/)

3. **Database Agnostic:** config.yml defines databases; same code runs on multiple databases via configuration blocks

4. **Reproducibility:** All code, configuration, and results are version controlled; results are organized by version for traceability

5. **Security:** Credentials go in environment variables, never in config files or git

6. **Dissemination Ready:** Results automatically organized for publication and external sharing
