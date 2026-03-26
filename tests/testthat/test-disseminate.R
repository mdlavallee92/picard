# Tests for R/disseminate.R
# Pure data-frame transformation functions - no database or external connections required

# ---- cleanColumnNames ----

test_that("cleanColumnNames converts spaces to underscores", {
  df <- data.frame(check.names = FALSE, "first name" = 1, "last name" = 2)
  result <- cleanColumnNames(df)
  expect_equal(colnames(result), c("first_name", "last_name"))
})

test_that("cleanColumnNames converts periods to underscores", {
  df <- data.frame(first.name = 1, last.name = 2)
  result <- cleanColumnNames(df)
  expect_equal(colnames(result), c("first_name", "last_name"))
})

test_that("cleanColumnNames converts CamelCase to snake_case", {
  df <- data.frame(cohortId = 1, databaseName = 2, patientCount = 3)
  result <- cleanColumnNames(df)
  expect_equal(colnames(result), c("cohort_id", "database_name", "patient_count"))
})

test_that("cleanColumnNames lowercases by default", {
  df <- data.frame(COHORT_ID = 1, DATABASE = 2)
  result <- cleanColumnNames(df)
  expect_equal(colnames(result), c("cohort_id", "database"))
})

test_that("cleanColumnNames preserves case when to_lower = FALSE", {
  df <- data.frame(CohortID = 1, DatabaseName = 2)
  result <- cleanColumnNames(df, to_lower = FALSE)
  # CamelCase split happens but no lowercasing
  expect_false(any(grepl("[a-z]", colnames(result)) & grepl("[A-Z]", colnames(result))))
})

test_that("cleanColumnNames returns same row count", {
  df <- data.frame(cohort_id = 1:5, database_name = letters[1:5])
  result <- cleanColumnNames(df)
  expect_equal(nrow(result), 5)
})

test_that("cleanColumnNames errors on non-data-frame", {
  expect_error(cleanColumnNames(list(a = 1, b = 2)))
  expect_error(cleanColumnNames("not a df"))
})

# ---- formatPercentages ----

test_that("formatPercentages formats proportion columns (0-1) to percent", {
  df <- data.frame(pct_treated = c(0.25, 0.5, 0.75))
  result <- formatPercentages(df, percent_cols = "pct_treated", decimal_places = 1)
  expect_equal(result$pct_treated, c("25%", "50%", "75%"))
})

test_that("formatPercentages does not multiply values already >1", {
  df <- data.frame(pct_treated = c(25, 50, 75))
  result <- formatPercentages(df, percent_cols = "pct_treated", decimal_places = 1)
  expect_equal(result$pct_treated, c("25%", "50%", "75%"))
})

test_that("formatPercentages auto-detects percent/pct/prop columns", {
  df <- data.frame(cohort_percent = c(0.1, 0.2), not_a_pct = c(100, 200))
  result <- formatPercentages(df, decimal_places = 1)
  expect_match(result$cohort_percent[1], "%")
  expect_false(grepl("%", result$not_a_pct[1]))
})

test_that("formatPercentages omits symbol when add_symbol = FALSE", {
  df <- data.frame(prop_value = c(0.5, 0.25))
  result <- formatPercentages(df, percent_cols = "prop_value", decimal_places = 1, add_symbol = FALSE)
  expect_false(any(grepl("%", result$prop_value)))
})

test_that("formatPercentages returns data unchanged if no cols detected and none specified", {
  df <- data.frame(count = c(10, 20), label = c("a", "b"))
  result <- formatPercentages(df, decimal_places = 1)
  expect_equal(result, df)
})

# ---- formatFloats ----

test_that("formatFloats rounds numeric columns to specified decimal places", {
  df <- data.frame(value = c(1.2345, 2.5678))
  result <- formatFloats(df, float_cols = "value", decimal_places = 2)
  expect_equal(result$value, c("1.23", "2.57"))
})

test_that("formatFloats removes trailing zeros by default", {
  df <- data.frame(value = c(1.5000, 3.1200))
  result <- formatFloats(df, float_cols = "value", decimal_places = 2)
  expect_false(any(grepl("00$", result$value)))
})

test_that("formatFloats auto-detects float columns (non-integer numerics)", {
  df <- data.frame(int_col = c(1L, 2L, 3L), float_col = c(1.1, 2.2, 3.3))
  result <- formatFloats(df, decimal_places = 2)
  # float_col should be formatted to character
  expect_type(result$float_col, "character")
  # int_col should remain integer (not auto-detected as float)
  expect_type(result$int_col, "integer")
})

test_that("formatFloats errors on non-data-frame", {
  expect_error(formatFloats("not a df", decimal_places = 2))
})

# ---- standardizeDataTypes ----

test_that("standardizeDataTypes converts _id columns to integer", {
  df <- data.frame(cohort_id = c("1", "2", "3"), stringsAsFactors = FALSE)
  result <- standardizeDataTypes(df)
  expect_type(result$cohort_id, "integer")
})

test_that("standardizeDataTypes converts _count columns to integer", {
  df <- data.frame(subject_count = c("100", "200", "300"), stringsAsFactors = FALSE)
  result <- standardizeDataTypes(df)
  expect_type(result$subject_count, "integer")
})

test_that("standardizeDataTypes converts _date columns to Date", {
  df <- data.frame(cohort_start_date = c("2020-01-01", "2021-06-15"), stringsAsFactors = FALSE)
  result <- standardizeDataTypes(df)
  expect_s3_class(result$cohort_start_date, "Date")
})

test_that("standardizeDataTypes converts flag columns to logical", {
  df <- data.frame(is_flag = c("TRUE", "FALSE", "TRUE"), stringsAsFactors = FALSE)
  result <- standardizeDataTypes(df)
  expect_type(result$is_flag, "logical")
})

test_that("standardizeDataTypes applies custom type rules", {
  df <- data.frame(name_col = c(1, 2, 3))
  custom_rules <- list(character = c("name_col"))
  result <- standardizeDataTypes(df, type_rules = custom_rules)
  expect_type(result$name_col, "character")
})

test_that("standardizeDataTypes returns data unchanged when no patterns match", {
  df <- data.frame(label = c("a", "b"), category = c("x", "y"), stringsAsFactors = FALSE)
  result <- standardizeDataTypes(df)
  expect_equal(df, result)
})

test_that("standardizeDataTypes errors on non-data-frame", {
  expect_error(standardizeDataTypes("not a df"))
})

# ---- pivotForComparison ----

test_that("pivotForComparison pivots long data to wide by names_from column", {
  long_df <- data.frame(
    cohort_id = c(1, 1, 2, 2),
    database_id = c("db1", "db2", "db1", "db2"),
    count = c(100, 200, 300, 400)
  )
  result <- pivotForComparison(
    data = long_df,
    id_cols = "cohort_id",
    names_from = "database_id",
    values_from = "count"
  )
  expect_equal(nrow(result), 2)
  expect_true("db1" %in% colnames(result))
  expect_true("db2" %in% colnames(result))
})

test_that("pivotForComparison applies names_prefix", {
  long_df <- data.frame(
    cohort_id = c(1, 1),
    db = c("db1", "db2"),
    n = c(10, 20)
  )
  result <- pivotForComparison(
    data = long_df,
    id_cols = "cohort_id",
    names_from = "db",
    values_from = "n",
    names_prefix = "count_"
  )
  expect_true("count_db1" %in% colnames(result))
  expect_true("count_db2" %in% colnames(result))
})

test_that("pivotForComparison fills missing combos with values_fill", {
  long_df <- data.frame(
    cohort_id = c(1, 2),
    db = c("db1", "db2"),
    n = c(10, 20)
  )
  result <- pivotForComparison(
    data = long_df,
    id_cols = "cohort_id",
    names_from = "db",
    values_from = "n",
    values_fill = 0
  )
  expect_equal(result$db2[result$cohort_id == 1], 0)
})

test_that("pivotForComparison errors on non-data-frame", {
  expect_error(pivotForComparison("not a df", "a", "b", "c"))
})

# ---- prepareDisseminationData ----

test_that("prepareDisseminationData cleans column names", {
  df <- data.frame(CohortId = c("1", "2"), DatabaseName = c("db1", "db2"))
  result <- prepareDisseminationData(
    df,
    format_percentages = FALSE,
    format_floats = FALSE,
    standardize_types = FALSE
  )
  expect_true("cohort_id" %in% colnames(result))
  expect_true("database_name" %in% colnames(result))
})

test_that("prepareDisseminationData skips steps when flags are FALSE", {
  df <- data.frame(CohortId = c(1, 2), pct_treated = c(0.5, 0.25))
  result <- prepareDisseminationData(
    df,
    clean_names = FALSE,
    format_percentages = FALSE,
    format_floats = FALSE,
    standardize_types = FALSE
  )
  expect_true("CohortId" %in% colnames(result))
})
