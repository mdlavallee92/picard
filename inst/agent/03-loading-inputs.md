# Loading Inputs: Cohorts and Concept Sets

## Introduction

Before running your study pipeline, you need to define the populations and phenotypes your analysis will use. Picard organizes these through two key input types:

- **Cohorts:** Define study populations, comparators, and outcomes as CIRCE-based JSON definitions or custom SQL
- **Concept Sets:** Define phenotypes for diseases, exposures, covariates, etc. as CIRCE-based JSON definitions

Picard uses *manifests* to catalog, version, and track these definitions throughout your study. This document walks through the complete workflow for loading and managing cohorts and concept sets.

## Manifest Overview

A manifest is a SQLite database that catalogs and tracks definitions. For each cohort or concept set, the manifest stores:

- **Metadata:** ID, label, category, source (ATLAS or manual)
- **File information:** Path and MD5 hash for change detection
- **Provenance:** When added, last modified, execution status
- **Tags:** Categorization for querying and grouping

Manifests enable reproducibility and change tracking as your study evolves.

## Working with Cohorts

The cohort workflow has several key steps:

### Step 1: Create or Update Cohorts Load File (Optional)

The `cohortsLoad.csv` file provides metadata for organizing and enriching your cohorts. You can create a blank template or edit it interactively:

**Option A: Create a blank template**

```r
createBlankCohortsLoadFile(cohortsFolderPath = here::here("inputs/cohorts"))
```

This creates `inputs/cohorts/cohortsLoad.csv` with columns: `atlasId`, `label`, `category`, `subCategory`, `file_name`

**Option B: Use the interactive editor**

```r
launchCohortsLoadEditor(cohortsFolderPath = here::here("inputs/cohorts"))
```

This launches a Shiny app where you can add/edit cohort metadata without touching the CSV directly.

### Step 2: Import Cohort Definitions from ATLAS

Connect to ATLAS and download cohort JSON definitions:

```r
atlasConn <- setAtlasConnection()

importAtlasCohorts(
  cohortsFolderPath = here::here("inputs/cohorts"),
  atlasConnection = atlasConn
)
```

This downloads JSON definitions to `inputs/cohorts/json/` and updates your manifest with metadata.

### Step 3: Load the Cohort Manifest

Load the manifest to access all cohort definitions in your study:

```r
cm <- loadCohortManifest()
```

### Step 4: Review and Validate Manifests

Examine the cohorts that were loaded:

```r
# View manifest list (metadata for all cohorts)
manifest_df <- cm$getManifest()

# Or get a formatted summary
summary_df <- cm$tabulateManifest()

# Query specific cohorts
cohort_1 <- cm$getCohortById(id = 1)
cohorts_by_tag <- cm$getCohortsByTag(tagString = "category: Primary")
```

### Step 5: Apply Functions for Cohort Operations

Once manifests are loaded, you need `ExecutionSettings` to interact with the database:

```r
# Create execution settings for a specific database
settings <- createExecutionSettingsFromConfig(configBlock = "my_cdm")

# Set execution settings on the manifest
cm$setExecutionSettings(settings)

# Create cohort tables in the database
cm$createCohortTables()

# Generate cohort populations
cm$generateCohorts()

# Get cohort counts
counts <- cm$retrieveCohortCounts()
print(counts)
```

## Building Dependent Cohorts

Beyond base cohorts (imported from ATLAS or written as SQL), you can define dependent cohorts that derive from other cohorts using demographic or temporal constraints. This is useful for subpopulation analyses.

### Temporal Subset Cohorts

Build cohorts based on temporal relationships between events. Example: "Chronic Kidney Disease (CKD) in patients with prior Type 2 Diabetes":

```r
ckd_given_t2d <- buildSubsetCohortTemporal(
  label = "CKD given prior T2D",
  baseCohortId = 1,          # CKD is the outcome
  filterCohortId = 2,        # Must have T2D
  temporalOperator = "before",
  temporalStartOffset = 365, # Within 1 year before CKD
  manifest = cm
)

cm$addDependentCohort(ckd_given_t2d)
```

### Demographic Subset Cohorts

Build cohorts based on demographic characteristics. Example: "CKD in males only":

```r
ckd_males <- buildSubsetCohortDemographic(
  label = "CKD Males",
  baseCohortId = 1,                  # CKD population
  genderConceptIds = c(8507),        # 8507 = Male
  manifest = cm
)

cm$addDependentCohort(ckd_males)
```

Example: "CKD in adults (18+) only":

```r
ckd_adults <- buildSubsetCohortDemographic(
  label = "CKD Adults",
  baseCohortId = 1,
  minAge = 18,
  manifest = cm
)

cm$addDependentCohort(ckd_adults)
```

### Union and Complement Cohorts

Combine multiple cohorts or create exclusions:

**Union:** Patients in either CKD OR Diabetes:

```r
ckd_or_t2d <- buildUnionCohort(
  label = "CKD or Type 2 Diabetes",
  cohortIds = c(1, 2),
  manifest = cm
)

cm$addDependentCohort(ckd_or_t2d)
```

**Complement:** All patients NOT in a cohort:

```r
no_ckd <- buildComplementCohort(
  label = "No Chronic Kidney Disease",
  cohortId = 1,
  manifest = cm
)

cm$addDependentCohort(no_ckd)
```

### Visualizing Dependencies

Once you've defined dependent cohorts, visualize the relationship graph:

```r
# Generate a dependency report (Mermaid diagram + table)
report <- visualizeCohortDependencies(cm)

# Optionally save to file
visualizeCohortDependencies(cm, outputPath = here::here("inputs/cohorts"))
```

---

## Working with Concept Sets

The concept set workflow is similar to cohorts with slightly different organization.

### Step 1: Create or Update Concept Sets Load File

Create metadata for organizing your concept sets:

```r
createBlankConceptSetsLoadFile(conceptSetsFolderPath = here::here("inputs/conceptSets"))
```

### Step 2: Import Concept Sets from ATLAS

```r
atlasConn <- setAtlasConnection()

importAtlasConceptSets(
  conceptSetsFolderPath = here::here("inputs/conceptSets"),
  atlasConnection = atlasConn
)
```

### Step 3: Load and Review

```r
csm <- loadConceptSetManifest()

# View manifest
manifest_df <- csm$getManifest()

# Query by concept
malaria_concepts <- csm$getConceptSetById(id = 1)
```

---

## Key Files and Folders

```
inputs/
├── cohorts/
│   ├── cohortsLoad.csv           # Metadata file
│   └── json/                     # ATLAS JSON exports
│       ├── cohort_1.json
│       └── cohort_2.json
└── conceptSets/
    ├── conceptSetsLoad.csv        # Metadata file
    └── json/                      # ATLAS JSON exports
        ├── concept_set_1.json
        └── concept_set_2.json
```

---

## Manifest Database Structure

Manifests are SQLite databases storing:

- **ID:** Unique identifier for each definition
- **Name/Label:** Human-readable name
- **File path:** Where the definition JSON/SQL is stored
- **Hash:** MD5 hash for detecting changes
- **Status:** Current state (new, modified, deleted, executed)
- **Metadata:** Custom tags and categories

The manifest enables:
- **Change tracking:** Detects when definitions are modified
- **Version history:** Traces which version produced which results
- **Dependency management:** Tracks dependent cohorts and their relationships
- **Validation:** Ensures all referenced definitions exist

---

## Next Steps

1. **Define cohorts** - Import from ATLAS or create manually
2. **Load manifest** - `cm <- loadCohortManifest()`
3. **Create dependent cohorts** - Build subsets for analyses
4. **Configure execution** - Set up database connection settings
5. **Generate cohorts** - Run pipeline to generate populations in database

See "Developing the Pipeline" for how to use these cohorts in your analysis tasks.
