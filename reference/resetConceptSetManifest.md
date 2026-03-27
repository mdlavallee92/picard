# Reset Concept Set Manifest Database

Deletes the conceptSetManifest.sqlite database file. Use this function
when you need to reset the manifest and rebuild it from the available
concept set files.

## Usage

``` r
resetConceptSetManifest(
  conceptSetsFolderPath = here::here("inputs/conceptSets")
)
```

## Arguments

- conceptSetsFolderPath:

  Character. Path to the conceptSets folder containing the manifest
  database. Defaults to "inputs/conceptSets".

## Value

Invisibly returns NULL. Deletes the manifest file and prints status
messages.

## Details

This function is useful for:

- Starting fresh with a new set of concept sets

- Clearing cached manifest data

- Resolving manifest corruption issues

After resetting, call
[`loadConceptSetManifest()`](https://ohdsi.github.io/picard/reference/loadConceptSetManifest.md)
to rebuild the manifest from the available concept set files in the
json/ subdirectory.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Reset the manifest
  resetConceptSetManifest()

  # Rebuild it (with or without settings)
  manifest <- loadConceptSetManifest()
} # }
```
