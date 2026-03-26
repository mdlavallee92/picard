# Tests for R/manifest_conceptSets.R and ConceptSetDef/ConceptSetManifest
# Focuses on functions that don't require a live vocabulary DB connection

# Helper to create minimal valid CIRCE concept set JSON
make_circe_concept_set_json <- function() {
  '{"items":[]}'
}

# ---- ConceptSetDef ----

test_that("ConceptSetDef initializes with valid CIRCE JSON", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(
    label = "Test Concept Set",
    tags = list(category = "medications"),
    filePath = temp_json,
    domain = "drug_exposure"
  )

  expect_equal(cs$label, "Test Concept Set")
  expect_true(nchar(cs$getHash()) > 0)
  expect_equal(cs$getId(), NA_integer_)
})

test_that("ConceptSetDef getFilePath returns path ending in .json", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(label = "CS", filePath = temp_json)
  expect_match(cs$getFilePath(), "\\.json$")
})

test_that("ConceptSetDef getJson returns non-empty string", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(label = "CS", filePath = temp_json)
  expect_type(cs$getJson(), "character")
  expect_true(nchar(cs$getJson()) > 0)
})

test_that("ConceptSetDef getId returns NA before assignment", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(label = "CS", filePath = temp_json)
  expect_equal(cs$getId(), NA_integer_)
})

test_that("ConceptSetDef setId and getId round-trip", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(label = "CS", filePath = temp_json)
  cs$setId(7L)
  expect_equal(cs$getId(), 7L)
})

test_that("ConceptSetDef domain tag is added automatically", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(label = "CS", filePath = temp_json, domain = "condition_occurrence")
  expect_equal(cs$tags$domain, "condition_occurrence")
})

test_that("ConceptSetDef errors for invalid domain", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  expect_error(
    ConceptSetDef$new(label = "CS", filePath = temp_json, domain = "not_a_domain")
  )
})

test_that("ConceptSetDef errors for non-existent file", {
  expect_error(
    ConceptSetDef$new(label = "CS", filePath = "/does/not/exist.json")
  )
})

test_that("ConceptSetDef errors for non-JSON file", {
  temp_sql <- tempfile(fileext = ".sql")
  writeLines("SELECT 1;", temp_sql)
  on.exit(unlink(temp_sql), add = TRUE)

  expect_error(
    ConceptSetDef$new(label = "CS", filePath = temp_sql)
  )
})

test_that("ConceptSetDef label active binding get/set works", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(label = "Original", filePath = temp_json)
  expect_equal(cs$label, "Original")
  cs$label <- "Modified"
  expect_equal(cs$label, "Modified")
})

test_that("ConceptSetDef formatTagsAsString includes all tags", {
  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(
    label = "CS",
    tags = list(category = "medications", source = "atlas"),
    filePath = temp_json
  )
  tags_str <- cs$formatTagsAsString()
  expect_true(grepl("category: medications", tags_str))
  expect_true(grepl("source: atlas", tags_str))
})

# ---- ConceptSetManifest ----

test_that("ConceptSetManifest initializes and creates SQLite database", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(label = "Test CS", filePath = temp_json)
  db_path <- file.path(temp_dir, "conceptSetManifest.sqlite")

  manifest <- ConceptSetManifest$new(
    conceptSetEntries = list(cs),
    dbPath = db_path
  )

  expect_true(file.exists(db_path))
})

test_that("ConceptSetManifest getManifest returns data frame", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(label = "My CS", filePath = temp_json)
  db_path <- file.path(temp_dir, "test.sqlite")

  manifest <- ConceptSetManifest$new(
    conceptSetEntries = list(cs),
    dbPath = db_path
  )

  df <- manifest$getManifest()
  expect_true(is.data.frame(df))
  expect_equal(nrow(df), 1)
  expect_equal(df$label[1], "My CS")
})

test_that("ConceptSetManifest nConceptSets returns correct count", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  concept_sets <- lapply(seq_len(3), function(i) {
    temp_json <- tempfile(fileext = ".json")
    writeLines(make_circe_concept_set_json(), temp_json)
    ConceptSetDef$new(label = paste("CS", i), filePath = temp_json)
  })

  db_path <- file.path(temp_dir, "test.sqlite")
  manifest <- ConceptSetManifest$new(conceptSetEntries = concept_sets, dbPath = db_path)

  expect_equal(manifest$nConceptSets(), 3)
})

test_that("ConceptSetManifest grabConceptSetById returns ConceptSetDef", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(label = "Grab Test", filePath = temp_json)
  db_path <- file.path(temp_dir, "test.sqlite")

  manifest <- ConceptSetManifest$new(conceptSetEntries = list(cs), dbPath = db_path)
  grabbed <- manifest$grabConceptSetById(1)

  expect_s3_class(grabbed, "ConceptSetDef")
  expect_equal(grabbed$label, "Grab Test")
})

test_that("ConceptSetManifest getConceptSetById returns data frame row", {
  temp_dir <- tempfile(prefix = "picard_csm_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  temp_json <- tempfile(fileext = ".json")
  writeLines(make_circe_concept_set_json(), temp_json)
  on.exit(unlink(temp_json), add = TRUE)

  cs <- ConceptSetDef$new(label = "Query Test", filePath = temp_json)
  db_path <- file.path(temp_dir, "test.sqlite")

  manifest <- ConceptSetManifest$new(conceptSetEntries = list(cs), dbPath = db_path)
  row <- manifest$getConceptSetById(1)

  expect_true(is.data.frame(row))
  expect_equal(nrow(row), 1)
  expect_equal(row$label[1], "Query Test")
})

# ---- createBlankConceptSetsLoadFile ----

test_that("createBlankConceptSetsLoadFile creates file in specified folder", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  createBlankConceptSetsLoadFile(conceptSetsFolderPath = temp_dir)

  expect_true(file.exists(file.path(temp_dir, "conceptSetsLoad.csv")))
})

test_that("createBlankConceptSetsLoadFile creates directory if missing", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  expect_false(dir.exists(temp_dir))
  createBlankConceptSetsLoadFile(conceptSetsFolderPath = temp_dir)
  expect_true(file.exists(file.path(temp_dir, "conceptSetsLoad.csv")))
})

test_that("createBlankConceptSetsLoadFile has correct column structure", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  createBlankConceptSetsLoadFile(conceptSetsFolderPath = temp_dir)

  df <- readr::read_csv(file.path(temp_dir, "conceptSetsLoad.csv"), show_col_types = FALSE)
  expected_cols <- c("atlasId", "label", "category", "subCategory", "sourceCode", "domain", "file_name")
  expect_true(all(expected_cols %in% colnames(df)))
})

# ---- resetConceptSetManifest ----

test_that("resetConceptSetManifest deletes existing SQLite file", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  sqlite_path <- file.path(temp_dir, "conceptSetManifest.sqlite")
  file.create(sqlite_path)
  expect_true(file.exists(sqlite_path))

  resetConceptSetManifest(conceptSetsFolderPath = temp_dir)
  expect_false(file.exists(sqlite_path))
})

test_that("resetConceptSetManifest does not error when no manifest exists", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  expect_no_error(resetConceptSetManifest(conceptSetsFolderPath = temp_dir))
})

# ---- loadConceptSetManifest ----

test_that("loadConceptSetManifest scans json/ folder and creates ConceptSetManifest", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  json_dir <- file.path(temp_dir, "json")
  dir.create(json_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  writeLines(make_circe_concept_set_json(), file.path(json_dir, "hypertension.json"))
  writeLines(make_circe_concept_set_json(), file.path(json_dir, "diabetes.json"))

  manifest <- loadConceptSetManifest(conceptSetsFolderPath = temp_dir)

  expect_s3_class(manifest, "ConceptSetManifest")
  expect_equal(manifest$nConceptSets(), 2)
})

test_that("loadConceptSetManifest creates SQLite on first load", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  json_dir <- file.path(temp_dir, "json")
  dir.create(json_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  writeLines(make_circe_concept_set_json(), file.path(json_dir, "test.json"))

  loadConceptSetManifest(conceptSetsFolderPath = temp_dir)

  expect_true(file.exists(file.path(temp_dir, "conceptSetManifest.sqlite")))
})

test_that("loadConceptSetManifest loads from existing sqlite on second call", {
  temp_dir <- tempfile(prefix = "picard_cs_")
  json_dir <- file.path(temp_dir, "json")
  dir.create(json_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  writeLines(make_circe_concept_set_json(), file.path(json_dir, "cs1.json"))

  loadConceptSetManifest(conceptSetsFolderPath = temp_dir)
  manifest2 <- loadConceptSetManifest(conceptSetsFolderPath = temp_dir)

  expect_s3_class(manifest2, "ConceptSetManifest")
  expect_equal(manifest2$nConceptSets(), 1)
})
