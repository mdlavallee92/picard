# Reset Cohort Manifest Database

Deletes the cohortManifest.sqlite database file. Use this function when
you need to reset the manifest and rebuild it from the available cohort
files.

## Usage

``` r
resetCohortManifest(cohortsFolderPath = here::here("inputs/cohorts"))
```

## Arguments

- cohortsFolderPath:

  Character. Path to the cohorts folder containing the manifest
  database. Defaults to "inputs/cohorts".

## Value

Invisibly returns NULL. Deletes the manifest file and prints status
messages.

## Details

This function is useful for:

- Starting fresh with a new set of cohorts

- Clearing cached manifest data

- Resolving manifest corruption issues

After resetting, call
[`loadCohortManifest()`](https://ohdsi.github.io/picard/reference/loadCohortManifest.md)
to rebuild the manifest from the available cohort files in the json/ and
sql/ subdirectories.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Reset the manifest
  resetCohortManifest()

  # Rebuild it (with or without settings)
  manifest <- loadCohortManifest()
} # }
```
