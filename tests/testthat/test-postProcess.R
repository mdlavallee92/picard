# Tests for R/postProcess.R
# Tests for pure/file-based functions only - skipping DB-dependent operations

# ---- validateResultsColumns ----

test_that("validateResultsColumns passes when all required columns present", {
  df <- data.frame(
    databaseId = "db1",
    cohortId = 1L,
    cohortLabel = "Test Cohort",
    count = 100L
  )
  expect_true(validateResultsColumns(df, stepName = "test_step"))
})

test_that("validateResultsColumns errors when databaseId is missing", {
  df <- data.frame(cohortId = 1L, cohortLabel = "Test")
  expect_error(validateResultsColumns(df, stepName = "test"), "Missing columns")
})

test_that("validateResultsColumns errors when cohortId is missing", {
  df <- data.frame(databaseId = "db1", cohortLabel = "Test")
  expect_error(validateResultsColumns(df, stepName = "test"), "Missing columns")
})

test_that("validateResultsColumns errors when cohortLabel is missing", {
  df <- data.frame(databaseId = "db1", cohortId = 1L)
  expect_error(validateResultsColumns(df, stepName = "test"), "Missing columns")
})

test_that("validateResultsColumns errors when multiple required columns missing", {
  df <- data.frame(extra_col = "x")
  expect_error(validateResultsColumns(df, stepName = "test"))
})

# ---- reviewExportSchema ----

test_that("reviewExportSchema returns empty data frame when folder has no CSVs", {
  temp_dir <- tempfile(prefix = "picard_export_")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  result <- reviewExportSchema(exportPath = temp_dir)
  expect_true(inherits(result, "data.frame"))
  expect_equal(nrow(result), 0)
})

test_that("reviewExportSchema returns schema with correct columns", {
  temp_dir <- tempfile(prefix = "picard_export_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Write a test CSV
  test_data <- data.frame(
    databaseId = c("db1", "db2"),
    cohortId = c(1L, 2L),
    cohortLabel = c("Cohort A", "Cohort B")
  )
  readr::write_csv(test_data, file.path(temp_dir, "cohort_counts.csv"))

  result <- reviewExportSchema(exportPath = temp_dir)

  expect_true("fileName" %in% colnames(result))
  expect_true("columnName" %in% colnames(result))
  expect_true("dataType" %in% colnames(result))
  expect_true("rowCount" %in% colnames(result))
})

test_that("reviewExportSchema finds all columns from CSV", {
  temp_dir <- tempfile(prefix = "picard_export_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  test_data <- data.frame(
    databaseId = "db1",
    cohortId = 1L,
    cohortLabel = "Test"
  )
  readr::write_csv(test_data, file.path(temp_dir, "results.csv"))

  result <- reviewExportSchema(exportPath = temp_dir)
  detected_cols <- result$columnName

  expect_true("databaseId" %in% detected_cols)
  expect_true("cohortId" %in% detected_cols)
  expect_true("cohortLabel" %in% detected_cols)
})

test_that("reviewExportSchema excludes schema_review files from self-review", {
  temp_dir <- tempfile(prefix = "picard_export_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Write a normal CSV and a schema_review CSV
  readr::write_csv(
    data.frame(cohortId = 1L, count = 5L),
    file.path(temp_dir, "cohort_counts.csv")
  )
  readr::write_csv(
    data.frame(fileName = "x", columnName = "y"),
    file.path(temp_dir, "schema_review.csv")
  )

  result <- reviewExportSchema(exportPath = temp_dir)
  # Only cohort_counts.csv should be included - not schema_review.csv
  expect_true(all(result$fileName != "schema_review.csv"))
})

test_that("reviewExportSchema handles multiple CSV files", {
  temp_dir <- tempfile(prefix = "picard_export_")
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  readr::write_csv(data.frame(a = 1, b = 2), file.path(temp_dir, "file1.csv"))
  readr::write_csv(data.frame(x = "a", y = "b", z = TRUE), file.path(temp_dir, "file2.csv"))

  result <- reviewExportSchema(exportPath = temp_dir)
  expect_equal(length(unique(result$fileName)), 2)
  # file1 has 2 cols, file2 has 3 cols
  expect_equal(nrow(result), 5)
})
