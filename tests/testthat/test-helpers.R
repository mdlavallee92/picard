test_that("tableExists returns FALSE for non-existent table", {
  # Create a temporary in-memory database
  conn <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(conn))

  # Try to check for non-existent table
  result <- tableExists(conn, "public", "nonexistent_table", "sqlite")
  expect_false(result)
})

test_that("tableExists returns TRUE for existing table", {
  conn <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(conn))

  # Create a test table
  DBI::dbCreateTable(conn, "test_table", list(id = "INTEGER", name = "TEXT"))

  # Check that table exists
  result <- tableExists(conn, "main", "test_table", "sqlite")
  expect_true(result)
})

test_that("getCohortTableNames returns all expected table names", {
  names <- getCohortTableNames()

  expect_true("cohortTable" %in% names(names))
  expect_true("cohortInclusionTable" %in% names(names))
  expect_true("cohortInclusionResultTable" %in% names(names))
  expect_true("cohortInclusionStatsTable" %in% names(names))
  expect_true("cohortSummaryStatsTable" %in% names(names))
  expect_true("cohortCensorStatsTable" %in% names(names))
  expect_true("cohortChecksumTable" %in% names(names))
})

test_that("getCohortTableNames uses custom base table name", {
  names <- getCohortTableNames(cohortTable = "custom_cohort")

  expect_equal(names$cohortTable, "custom_cohort")
  expect_equal(names$cohortInclusionTable, "custom_cohort_inclusion")
  expect_equal(names$cohortChecksumTable, "custom_cohort_checksum")
})

test_that("createMainCohortTableSql generates valid SQL", {
  sql <- createMainCohortTableSql("results", "cohort", "sqlite")

  expect_true(grepl("CREATE TABLE", sql, ignore.case = TRUE))
  expect_true(grepl("cohort_definition_id", sql, ignore.case = TRUE))
  expect_true(grepl("subject_id", sql, ignore.case = TRUE))
  expect_true(grepl("cohort_start_date", sql, ignore.case = TRUE))
  expect_true(grepl("cohort_end_date", sql, ignore.case = TRUE))
})

test_that("createInclusionTableSql generates valid SQL", {
  sql <- createInclusionTableSql("results", "cohort_inclusion", "sqlite")

  expect_true(grepl("CREATE TABLE", sql, ignore.case = TRUE))
  expect_true(grepl("cohort_definition_id", sql, ignore.case = TRUE))
  expect_true(grepl("rule_sequence", sql, ignore.case = TRUE))
})

test_that("createInclusionResultTableSql generates valid SQL", {
  sql <- createInclusionResultTableSql("results", "cohort_inclusion_result", "sqlite")

  expect_true(grepl("CREATE TABLE", sql, ignore.case = TRUE))
  expect_true(grepl("inclusion_rule_mask", sql, ignore.case = TRUE))
})

test_that("createInclusionStatsTableSql generates valid SQL", {
  sql <- createInclusionStatsTableSql("results", "cohort_inclusion_stats", "sqlite")

  expect_true(grepl("CREATE TABLE", sql, ignore.case = TRUE))
  expect_true(grepl("rule_sequence", sql, ignore.case = TRUE))
})

test_that("createSummaryStatsTableSql generates valid SQL", {
  sql <- createSummaryStatsTableSql("results", "cohort_summary_stats", "sqlite")

  expect_true(grepl("CREATE TABLE", sql, ignore.case = TRUE))
  expect_true(grepl("base_count", sql, ignore.case = TRUE))
  expect_true(grepl("final_count", sql, ignore.case = TRUE))
})

test_that("createCensorStatsTableSql generates valid SQL", {
  sql <- createCensorStatsTableSql("results", "cohort_censor_stats", "sqlite")

  expect_true(grepl("CREATE TABLE", sql, ignore.case = TRUE))
  expect_true(grepl("cohort_definition_id", sql, ignore.case = TRUE))
  expect_true(grepl("lost_count", sql, ignore.case = TRUE))
})

test_that("createChecksumTableSql generates valid SQL", {
  sql <- createChecksumTableSql("results", "cohort_checksum", "sqlite")

  expect_true(grepl("CREATE TABLE", sql, ignore.case = TRUE))
  expect_true(grepl("cohort_definition_id", sql, ignore.case = TRUE))
  expect_true(grepl("checksum", sql, ignore.case = TRUE))
})
