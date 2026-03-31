args <- commandArgs(trailingOnly = TRUE)

# Usage:
#   Rscript makePrintFriendlyFile.R [cohorts_dir] [output_base]
#
# Defaults:
#   cohorts_dir = "inputs/cohorts"  (Ulysses standard structure)
#   json_dir    = cohorts_dir/json
#   output_base = "AI_translation"  (created at repo root, separate from inputs/)
#   output_dir  = output_base/printFriendly  (created automatically)

cohorts_dir <- if (length(args) >= 1) args[[1]] else "inputs/cohorts"
output_base <- if (length(args) >= 2) args[[2]] else "AI_translation"
json_dir <- file.path(cohorts_dir, "json")
output_dir <- file.path(output_base, "printFriendly")

if (!dir.exists(json_dir)) {
  stop(sprintf("json_dir not found: %s", json_dir))
}
# output_dir is the base; category subfolders are created per-file below

if (!requireNamespace("CirceR", quietly = TRUE)) {
  stop("Package 'CirceR' is required. Install it in R first (e.g., remotes::install_github('ohdsi/CirceR')).")
}

json_paths <- list.files(json_dir, pattern = "\\.json$", full.names = TRUE, recursive = TRUE)
if (length(json_paths) == 0) {
  stop(sprintf("No .json files found in %s", cohorts_dir))
}

for (json_path in json_paths) {
  cohort_basename <- tools::file_path_sans_ext(basename(json_path))

  # Preserve category subfolder (e.g. target/, comparator/) from json_dir
  rel_dir <- dirname(sub(paste0("^", normalizePath(json_dir), "/?"), "", normalizePath(json_path)))
  category_out_dir <- if (rel_dir == ".") output_dir else file.path(output_dir, rel_dir)
  if (!dir.exists(category_out_dir)) {
    dir.create(category_out_dir, recursive = TRUE)
    message(sprintf("Created output directory: %s", category_out_dir))
  }

  json_text <- paste(readLines(json_path, warn = FALSE), collapse = "\n")
  cohort_def <- CirceR::cohortExpressionFromJson(json_text)
  rmd_content <- CirceR::cohortPrintFriendly(cohort_def)

  out_rmd <- file.path(category_out_dir, paste0(cohort_basename, " - cohort_print_friendly.Rmd"))
  cat(sprintf("Writing: %s\n", out_rmd))
  writeLines(rmd_content, out_rmd)
}

cat("Done generating print-friendly cohort Rmd files.\n")

