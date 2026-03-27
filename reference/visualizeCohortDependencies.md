# Visualize Cohort Dependencies in a Report

Creates a comprehensive markdown report visualizing the dependency
structure of all cohorts in a CohortManifest. The report includes a
mermaid diagram showing the dependency graph and a detailed table of all
cohorts with their relationships.

## Usage

``` r
visualizeCohortDependencies(manifest, outputPath = NULL)
```

## Arguments

- manifest:

  A CohortManifest object containing loaded cohorts.

- outputPath:

  Character. Optional path to save the markdown report. If NULL, the
  report is not saved to file. If a folder path is provided, the report
  is saved as "cohort_dependencies.md" in that folder. Defaults to NULL.

## Value

Character. The markdown report content (invisibly if saved to file).

## Details

The report includes:

- **Overview**: Summary statistics (total cohorts, base cohorts,
  dependent cohorts)

- **Dependency Diagram**: Mermaid graph showing how cohorts depend on
  each other

- **Cohort Summary Table**: Details on each cohort including type and
  dependencies

- **Dependency Tree**: Hierarchical view of base cohorts and their
  dependents

The mermaid diagram uses:

- Rectangles for CIRCE (base) cohorts

- Circles for subset cohorts

- Diamonds for union cohorts

- Hexagons for complement cohorts

- Arrows showing dependency direction (parent → dependent)

## Examples

``` r
if (FALSE) { # \dontrun{
  manifest <- loadCohortManifest()
  
  # View report in console
  report <- visualizeCohortDependencies(manifest)
  
  # Save report to cohorts folder
  visualizeCohortDependencies(manifest, outputPath = "inputs/cohorts")
} # }
```
