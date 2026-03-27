#' Build a Subset Cohort Definition (Temporal)
#'
#' @description
#' Creates a SQL file and metadata for a subset cohort based on temporal filtering
#' between two cohorts. Returns a CohortDef object ready to add to a CohortManifest.
#'
#' @param label Character. User-friendly name for the subset (e.g., "CKD with T2D prior")
#' @param baseCohortId Integer. The cohort ID to subset.
#' @param filterCohortId Integer. The cohort ID to use for temporal filtering.
#' @param temporalOperator Character. One of 'during', 'before', 'after', 'overlapping'. Default: 'during'
#' @param temporalStartOffset Integer. Window start relative to base cohort (negative = before). Default: 0
#' @param temporalEndOffset Integer. Window end relative to base cohort. Default: 0
#' @param cohortsDirectory Character. Path to inputs/cohorts/. Uses study hierarchy if not provided.
#' @param manifest CohortManifest object (optional). If provided, validates that base cohorts exist.
#'   Recommended to ensure referential integrity. If NULL, a warning is issued.
#'
#' @details
#' Creates three files:
#' - SQL file: `inputs/cohorts/derived/subset/subset_cohort_{baseCohortId}_cohort_{filterCohortId}.sql`
#' - Metadata JSON: Same path with `.json` extension (parameters for execution)
#' - Context file: `.metadata` with rule description
#'
#' @return A CohortDef object with cohortType='subset' and dependencies set.
#'
#' @export
buildSubsetCohortTemporal <- function(
    label,
    baseCohortId,
    filterCohortId,
    temporalOperator = "during",
    temporalStartOffset = 0L,
    temporalEndOffset = 0L,
    cohortsDirectory = NULL,
    manifest = NULL) {

  # Validation
  checkmate::assert_string(x = label, min.chars = 1)
  checkmate::assert_integerish(x = baseCohortId, len = 1, lower = 1)
  checkmate::assert_integerish(x = filterCohortId, len = 1, lower = 1)
  checkmate::assert_choice(x = temporalOperator, choices = c("during", "before", "after", "overlapping"))
  checkmate::assert_integerish(x = temporalStartOffset, len = 1)
  checkmate::assert_integerish(x = temporalEndOffset, len = 1)
  checkmate::assert_class(x = manifest, classes = "CohortManifest", null.ok = TRUE)

  # Warn if manifest not provided
  if (is.null(manifest)) {
    cli::cli_alert_warning(
      "manifest parameter not provided. It is STRONGLY RECOMMENDED to pass the manifest \\
      to validate that base cohorts ({baseCohortId}, {filterCohortId}) exist. \\
      Proceeding without validation may create broken dependencies."
    )
  } else {
    # Validate base cohorts exist in manifest
    manifest_ids <- manifest$tabulateManifest()$id
    if (!baseCohortId %in% manifest_ids) {
      cli::cli_abort("Base cohort ID {baseCohortId} not found in manifest")
    }
    if (!filterCohortId %in% manifest_ids) {
      cli::cli_abort("Filter cohort ID {filterCohortId} not found in manifest")
    }
  }

  # Set default cohorts directory
  if (is.null(cohortsDirectory)) {
    cohortsDirectory <- file.path(getwd(), "inputs", "cohorts")
  }

  # Create derived/subset directory if it doesn't exist
  subset_dir <- file.path(cohortsDirectory, "derived", "subset")
  if (!dir.exists(subset_dir)) {
    dir.create(subset_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Generate file names
  file_name <- sprintf("subset_cohort_%d_cohort_%d", baseCohortId, filterCohortId)
  sql_path <- file.path(subset_dir, paste0(file_name, ".sql"))
  metadata_path <- file.path(subset_dir, paste0(file_name, ".json"))

  # Load SQL template
  template_path <- system.file(
    "sql",
    "createSubsetCohort_Cohort.sql",
    package = "picard"
  )
  template_sql <- readr::read_file(template_path)

  # Prepare metadata
  metadata <- list(
    type = "subset_temporal",
    label = label,
    baseCohortId = baseCohortId,
    filterCohortId = filterCohortId,
    temporalOperator = temporalOperator,
    temporalStartOffset = temporalStartOffset,
    temporalEndOffset = temporalEndOffset,
    createdAt = Sys.time(),
    dependsOnCohortIds = c(baseCohortId, filterCohortId)
  )

  # Write SQL template to file (will be rendered at execution time)
  writeLines(template_sql, con = sql_path)

  # Write metadata JSON
  jsonlite::write_json(metadata, path = metadata_path, pretty = TRUE, auto_unbox = TRUE)

  cli::cli_alert_success("Created subset cohort SQL: {fs::path_rel(sql_path)}")
  cli::cli_alert_success("Created metadata file: {fs::path_rel(metadata_path)}")

  # Create and return CohortDef object
  cohort_def <- CohortDef$new(
    label = label,
    tags = list(
      type = "subset",
      baseCohortId = as.character(baseCohortId),
      filterCohortId = as.character(filterCohortId),
      temporalOperator = temporalOperator
    ),
    filePath = sql_path
  )

  # Set dependent cohort metadata
  cohort_def$setCohortType("subset")
  cohort_def$setDependencies(
    dependsOnCohortIds = c(baseCohortId, filterCohortId),
    dependencyRule = list(
      type = "temporal",
      operator = temporalOperator,
      startOffset = temporalStartOffset,
      endOffset = temporalEndOffset
    )
  )

  return(cohort_def)
}


#' Build a Subset Cohort Definition (Demographic)
#'
#' @description
#' Creates a SQL file and metadata for a subset cohort based on person-level demographics.
#' Returns a CohortDef object ready to add to a CohortManifest.
#'
#' @param label Character. User-friendly name for the subset (e.g., "CKD - Males 40-75")
#' @param baseCohortId Integer. The cohort ID to subset.
#' @param minAge Integer. Minimum age at cohort start. NULL = no minimum. Default: NULL
#' @param maxAge Integer. Maximum age at cohort start. NULL = no maximum. Default: NULL
#' @param genderConceptIds Numeric vector. Gender concept IDs to include. NULL = all. Default: NULL
#' @param raceConceptIds Numeric vector. Race concept IDs to include. NULL = all. Default: NULL
#' @param ethnicityConceptIds Numeric vector. Ethnicity concept IDs to include. NULL = all. Default: NULL
#' @param cohortsDirectory Character. Path to inputs/cohorts/. Uses study hierarchy if not provided.
#' @param manifest CohortManifest object (optional). If provided, validates that base cohort exists.
#'   Recommended to ensure referential integrity. If NULL, a warning is issued.
#'
#' @details
#' Creates three files:
#' - SQL file: `inputs/cohorts/derived/subset_demo/subset_demo_cohort_{baseCohortId}.sql`
#' - Metadata JSON: Same path with `.json` extension
#' - Context file: `.metadata` with filter description
#'
#' @return A CohortDef object with cohortType='subset' and dependencies set.
#'
#' @export
buildSubsetCohortDemographic <- function(
    label,
    baseCohortId,
    minAge = NULL,
    maxAge = NULL,
    genderConceptIds = NULL,
    raceConceptIds = NULL,
    ethnicityConceptIds = NULL,
    cohortsDirectory = NULL,
    manifest = NULL) {

  # Validation
  checkmate::assert_string(x = label, min.chars = 1)
  checkmate::assert_integerish(x = baseCohortId, len = 1, lower = 1)
  checkmate::assert_integerish(x = minAge, len = 1, lower = 0, null.ok = TRUE)
  checkmate::assert_integerish(x = maxAge, len = 1, lower = 0, null.ok = TRUE)
  checkmate::assert_vector(x = genderConceptIds, null.ok = TRUE)
  checkmate::assert_vector(x = raceConceptIds, null.ok = TRUE)
  checkmate::assert_vector(x = ethnicityConceptIds, null.ok = TRUE)
  checkmate::assert_class(x = manifest, classes = "CohortManifest", null.ok = TRUE)

  # Warn if manifest not provided
  if (is.null(manifest)) {
    cli::cli_alert_warning(
      "manifest parameter not provided. It is STRONGLY RECOMMENDED to pass the manifest \\
      to validate that base cohort {baseCohortId} exists. \\
      Proceeding without validation may create broken dependencies."
    )
  } else {
    # Validate base cohort exists in manifest
    manifest_ids <- manifest$tabulateManifest()$id
    if (!baseCohortId %in% manifest_ids) {
      cli::cli_abort("Base cohort ID {baseCohortId} not found in manifest")
    }
  }

  # Set default cohorts directory
  if (is.null(cohortsDirectory)) {
    cohortsDirectory <- file.path(getwd(), "inputs", "cohorts")
  }

  # Create derived/subset_demo directory if it doesn't exist
  subset_dir <- file.path(cohortsDirectory, "derived", "subset_demo")
  if (!dir.exists(subset_dir)) {
    dir.create(subset_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Generate unique hash from demographic parameters
  params_for_hash <- list(
    minAge = minAge,
    maxAge = maxAge,
    genderConceptIds = genderConceptIds,
    raceConceptIds = raceConceptIds,
    ethnicityConceptIds = ethnicityConceptIds
  )
  params_json <- jsonlite::toJSON(params_for_hash, auto_unbox = TRUE)
  params_hash <- substr(rlang::hash(params_json), 1, 8)

  # Generate file names with hash to ensure uniqueness
  file_name <- sprintf("subset_demo_cohort_%d_%s", baseCohortId, params_hash)
  sql_path <- file.path(subset_dir, paste0(file_name, ".sql"))
  metadata_path <- file.path(subset_dir, paste0(file_name, ".json"))

  # Load SQL template
  template_path <- system.file(
    "sql",
    "createSubsetCohort_Person.sql",
    package = "picard"
  )
  template_sql <- readr::read_file(template_path)

  # Prepare metadata - convert NULLs to empty strings for SqlRender template conditions
  # SqlRender checks {@param != ''} so empty strings will work correctly
  metadata <- list(
    type = "subset_demographic",
    label = label,
    baseCohortId = baseCohortId,
    minAge = ifelse(is.null(minAge), "", minAge),
    maxAge = ifelse(is.null(maxAge), "", maxAge),
    genderConceptIds = ifelse(is.null(genderConceptIds) || length(genderConceptIds) == 0, "", ifelse(length(genderConceptIds) == 1, as.character(genderConceptIds[1]), paste(genderConceptIds, collapse = ","))),
    raceConceptIds = ifelse(is.null(raceConceptIds) || length(raceConceptIds) == 0, "", ifelse(length(raceConceptIds) == 1, as.character(raceConceptIds[1]), paste(raceConceptIds, collapse = ","))),
    ethnicityConceptIds = ifelse(is.null(ethnicityConceptIds) || length(ethnicityConceptIds) == 0, "", ifelse(length(ethnicityConceptIds) == 1, as.character(ethnicityConceptIds[1]), paste(ethnicityConceptIds, collapse = ","))),
    createdAt = Sys.time(),
    dependsOnCohortIds = c(baseCohortId)
  )

  # Write SQL template to file
  writeLines(template_sql, con = sql_path)

  # Write metadata JSON
  jsonlite::write_json(metadata, path = metadata_path, pretty = TRUE, auto_unbox = TRUE)

  cli::cli_alert_success("Created demographic subset SQL: {fs::path_rel(sql_path)}")
  cli::cli_alert_success("Created metadata file: {fs::path_rel(metadata_path)}")

  # Create and return CohortDef object
  cohort_def <- CohortDef$new(
    label = label,
    tags = list(
      type = "subset_demographic",
      baseCohortId = as.character(baseCohortId),
      minAge = ifelse(!is.null(minAge), as.character(minAge), "NA"),
      maxAge = ifelse(!is.null(maxAge), as.character(maxAge), "NA")
    ),
    filePath = sql_path
  )

  # Set dependent cohort metadata
  cohort_def$setCohortType("subset")
  cohort_def$setDependencies(
    dependsOnCohortIds = c(baseCohortId),
    dependencyRule = list(
      type = "demographic",
      minAge = minAge,
      maxAge = maxAge,
      genderConceptIds = genderConceptIds,
      raceConceptIds = raceConceptIds,
      ethnicityConceptIds = ethnicityConceptIds
    )
  )

  return(cohort_def)
}

#' Build a Union Cohort Definition
#'
#' @description
#' Creates a SQL file and metadata for a union cohort that combines multiple input cohorts.
#' Returns a CohortDef object ready to add to a CohortManifest.
#'
#' @param label Character. User-friendly name for the union (e.g., "Chronic Kidney Disease Phenotypes")
#' @param cohortIds Numeric vector (minimum 2). Cohort IDs to union.
#' @param unionRule Character. One of 'any', 'all', 'at_least_n'. Default: 'any'
#'   - 'any': subjects appearing in ANY input cohort
#'   - 'all': subjects appearing in ALL input cohorts
#'   - 'at_least_n': subjects appearing in at least N cohorts
#' @param atLeastN Integer. Number of cohorts required (only if unionRule='at_least_n'). Default: 2
#' @param cohortsDirectory Character. Path to inputs/cohorts/. Uses study hierarchy if not provided.
#' @param manifest CohortManifest object (optional). If provided, validates that all input cohorts exist.
#'   Recommended to ensure referential integrity. If NULL, a warning is issued.
#'
#' @details
#' Creates three files:
#' - SQL file: `inputs/cohorts/derived/union/union_cohorts_{cohort_id_list}.sql`
#' - Metadata JSON: Same path with `.json` extension
#' - Context file: `.metadata` with rule description
#'
#' @return A CohortDef object with cohortType='union' and dependencies set.
#'
#' @export
buildUnionCohort <- function(
    label,
    cohortIds,
    unionRule = "any",
    atLeastN = 2L,
    cohortsDirectory = NULL,
    manifest = NULL) {

  # Validation
  checkmate::assert_string(x = label, min.chars = 1)
  checkmate::assert_integerish(x = cohortIds, min.len = 2, unique = TRUE, lower = 1)
  checkmate::assert_choice(x = unionRule, choices = c("any", "all", "at_least_n"))
  checkmate::assert_integerish(x = atLeastN, len = 1, lower = 1)
  checkmate::assert_class(x = manifest, classes = "CohortManifest", null.ok = TRUE)

  # Warn if manifest not provided
  if (is.null(manifest)) {
    cli::cli_alert_warning(
      "manifest parameter not provided. It is STRONGLY RECOMMENDED to pass the manifest \\
      to validate that all input cohorts ({paste(cohortIds, collapse = ', ')}) exist. \\
      Proceeding without validation may create broken dependencies."
    )
  } else {
    # Validate all input cohorts exist in manifest
    manifest_ids <- manifest$tabulateManifest()$id
    missing_ids <- setdiff(cohortIds, manifest_ids)
    if (length(missing_ids) > 0) {
      cli::cli_abort("Input cohort {if (length(missing_ids) == 1) 'ID' else 'IDs'} {paste(missing_ids, collapse = ', ')} not found in manifest")
    }
  }

  # Set default cohorts directory
  if (is.null(cohortsDirectory)) {
    cohortsDirectory <- file.path(getwd(), "inputs", "cohorts")
  }

  # Create derived/union directory if it doesn't exist
  union_dir <- file.path(cohortsDirectory, "derived", "union")
  if (!dir.exists(union_dir)) {
    dir.create(union_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Generate file names
  cohort_ids_str <- paste(cohortIds, collapse = "_")
  file_name <- sprintf("union_cohorts_%s_%s", cohort_ids_str, unionRule)
  sql_path <- file.path(union_dir, paste0(file_name, ".sql"))
  metadata_path <- file.path(union_dir, paste0(file_name, ".json"))

  # Load SQL template
  template_path <- system.file(
    "sql",
    "createUnionCohort.sql",
    package = "picard"
  )
  template_sql <- readr::read_file(template_path)

  # Prepare metadata
  metadata <- list(
    type = "union",
    label = label,
    cohortIds = as.list(as.integer(cohortIds)),
    unionRule = unionRule,
    atLeastN = atLeastN,
    createdAt = Sys.time(),
    dependsOnCohortIds = as.integer(cohortIds)
  )

  # Write SQL template to file
  writeLines(template_sql, con = sql_path)

  # Write metadata JSON
  jsonlite::write_json(metadata, path = metadata_path, pretty = TRUE, auto_unbox = TRUE)

  cli::cli_alert_success("Created union cohort SQL: {fs::path_rel(sql_path)}")
  cli::cli_alert_success("Created metadata file: {fs::path_rel(metadata_path)}")

  # Create and return CohortDef object
  cohort_def <- CohortDef$new(
    label = label,
    tags = list(
      type = "union",
      cohortCount = as.character(length(cohortIds)),
      unionRule = unionRule
    ),
    filePath = sql_path
  )

  # Set dependent cohort metadata
  cohort_def$setCohortType("union")
  cohort_def$setDependencies(
    dependsOnCohortIds = as.integer(cohortIds),
    dependencyRule = list(
      type = "union",
      rule = unionRule,
      atLeastN = atLeastN
    )
  )

  return(cohort_def)
}


#' Build a Complement Cohort Definition
#'
#' @description
#' Creates a SQL file and metadata for a complement cohort that excludes subjects
#' from a population cohort based on other cohorts.
#' Returns a CohortDef object ready to add to a CohortManifest.
#'
#' @param label Character. User-friendly name for the complement (e.g., "Females without Pregnancy")
#' @param populationCohortId Integer. The population/base cohort ID.
#' @param excludeCohortIds Numeric vector (minimum 1). Cohort IDs to exclude.
#' @param complementType Character. One of 'exclude_any', 'exclude_all'. Default: 'exclude_any'
#'   - 'exclude_any': remove subjects in ANY exclude cohort
#'   - 'exclude_all': remove subjects only if in ALL exclude cohorts
#' @param cohortsDirectory Character. Path to inputs/cohorts/. Uses study hierarchy if not provided.
#' @param manifest CohortManifest object (optional). If provided, validates that population and exclude cohorts exist.
#'   Recommended to ensure referential integrity. If NULL, a warning is issued.
#'
#' @details
#' Creates three files:
#' - SQL file: `inputs/cohorts/derived/complement/complement_cohort_{popId}_exclude_{excludeIds}.sql`
#' - Metadata JSON: Same path with `.json` extension
#' - Context file: `.metadata` with rule description
#'
#' @return A CohortDef object with cohortType='complement' and dependencies set.
#'
#' @export
buildComplementCohort <- function(
    label,
    populationCohortId,
    excludeCohortIds,
    complementType = "exclude_any",
    cohortsDirectory = NULL,
    manifest = NULL) {

  # Validation
  checkmate::assert_string(x = label, min.chars = 1)
  checkmate::assert_integerish(x = populationCohortId, len = 1, lower = 1)
  checkmate::assert_integerish(x = excludeCohortIds, min.len = 1, unique = TRUE, lower = 1)
  checkmate::assert_choice(x = complementType, choices = c("exclude_any", "exclude_all"))
  checkmate::assert_class(x = manifest, classes = "CohortManifest", null.ok = TRUE)

  # Ensure populationCohortId not in excludeCohortIds
  if (populationCohortId %in% excludeCohortIds) {
    cli::cli_abort("Population cohort ID {populationCohortId} cannot be in exclude list")
  }

  # Warn if manifest not provided
  if (is.null(manifest)) {
    cli::cli_alert_warning(
      "manifest parameter not provided. It is STRONGLY RECOMMENDED to pass the manifest \\
      to validate that population cohort {populationCohortId} and exclude cohorts ({paste(excludeCohortIds, collapse = ', ')}) exist. \\
      Proceeding without validation may create broken dependencies."
    )
  } else {
    # Validate population and exclude cohorts exist in manifest
    manifest_ids <- manifest$tabulateManifest()$id
    
    if (!populationCohortId %in% manifest_ids) {
      cli::cli_abort("Population cohort ID {populationCohortId} not found in manifest")
    }
    
    missing_ids <- setdiff(excludeCohortIds, manifest_ids)
    if (length(missing_ids) > 0) {
      cli::cli_abort("Exclude cohort {if (length(missing_ids) == 1) 'ID' else 'IDs'} {paste(missing_ids, collapse = ', ')} not found in manifest")
    }
  }

  # Set default cohorts directory
  if (is.null(cohortsDirectory)) {
    cohortsDirectory <- file.path(getwd(), "inputs", "cohorts")
  }

  # Create derived/complement directory if it doesn't exist
  complement_dir <- file.path(cohortsDirectory, "derived", "complement")
  if (!dir.exists(complement_dir)) {
    dir.create(complement_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Generate file names
  exclude_ids_str <- paste(excludeCohortIds, collapse = "_")
  file_name <- sprintf("complement_cohort_%d_exclude_%s_%s", populationCohortId, exclude_ids_str, complementType)
  sql_path <- file.path(complement_dir, paste0(file_name, ".sql"))
  metadata_path <- file.path(complement_dir, paste0(file_name, ".json"))

  # Load SQL template
  template_path <- system.file(
    "sql",
    "createComplementCohort.sql",
    package = "picard"
  )
  template_sql <- readr::read_file(template_path)

  # Prepare metadata
  metadata <- list(
    type = "complement",
    label = label,
    populationCohortId = populationCohortId,
    excludeCohortIds = as.list(as.integer(excludeCohortIds)),
    complementType = complementType,
    createdAt = Sys.time(),
    dependsOnCohortIds = c(populationCohortId, as.integer(excludeCohortIds))
  )

  # Write SQL template to file
  writeLines(template_sql, con = sql_path)

  # Write metadata JSON
  jsonlite::write_json(metadata, path = metadata_path, pretty = TRUE, auto_unbox = TRUE)

  cli::cli_alert_success("Created complement cohort SQL: {fs::path_rel(sql_path)}")
  cli::cli_alert_success("Created metadata file: {fs::path_rel(metadata_path)}")

  # Create and return CohortDef object
  all_deps <- c(populationCohortId, as.integer(excludeCohortIds))
  
  cohort_def <- CohortDef$new(
    label = label,
    tags = list(
      type = "complement",
      populationCohortId = as.character(populationCohortId),
      excludeCount = as.character(length(excludeCohortIds)),
      complementType = complementType
    ),
    filePath = sql_path
  )

  # Set dependent cohort metadata
  cohort_def$setCohortType("complement")
  cohort_def$setDependencies(
    dependsOnCohortIds = all_deps,
    dependencyRule = list(
      type = "complement",
      populationCohortId = populationCohortId,
      excludeCohortIds = as.integer(excludeCohortIds),
      rule = complementType
    )
  )

  return(cohort_def)
}
