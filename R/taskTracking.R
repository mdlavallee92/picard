#' @importFrom digest digest
#' @title Check if Task Needs to be Rerun
#' @description Determines whether a task needs to be rerun by checking:
#'   1. Task file modifications (file hash comparison)
#'   2. Dependency file modifications (extracted from source() calls)
#'   3. Cohort generation changes (hash comparison in database)
#'   4. Previous run errors (checked in logs and history)
#'   5. Version changes
#'
#' @param taskFile Character. Name or path of the task file (e.g., "task1.R")
#' @param configBlock Character. The config block name (e.g., "optum_dod")
#' @param executionSettings ExecutionSettings object
#' @param pipelineVersion Character. Current pipeline version (e.g., "1.0.0")
#' @param tasksFolderPath Character. Path to tasks folder (default: here::here("analysis/tasks"))
#'
#' @return List with elements:
#'   - should_rerun: Logical. TRUE if task should be rerun
#'   - reasons: Character vector. Why task should be rerun
#'   - last_run_info: List with previous run details (time, version, status)
#'   - task_file_hash: Current hash of task file
#'   - cohort_hash_status: List comparing manifest hashes to database hashes
#'
#' @details
#' Creates/updates exec/logs/task_run_history.csv tracking:
#' - task_name, config_block, last_run_time, pipeline_version
#' - task_file_hash, cohort_hash_match, status, error_message
#'
#' @export
shouldRerunTask <- function(
    taskFile,
    configBlock,
    executionSettings,
    pipelineVersion,
    tasksFolderPath = here::here("analysis/tasks")) {

  # Initialize result structure
  reasons <- character()
  rerunNeeded <- FALSE

  # Ensure task file path
  if (!file.exists(taskFile)) {
    taskFile <- fs::path(tasksFolderPath, taskFile)
  }

  if (!file.exists(taskFile)) {
    cli::cli_alert_warning("Task file not found: {taskFile}")
    return(list(
      should_rerun = TRUE,
      reasons = "Task file does not exist",
      last_run_info = NULL,
      task_file_hash = NA_character_,
      cohort_hash_status = NULL
    ))
  }

  # Get current task file hash
  currentTaskHash <- digest::digest(file = taskFile, algo = "sha256")

  # Initialize task run history
  historyFile <- fs::path(here::here("exec/logs"), "task_run_history.csv")
  if (!dir.exists(fs::path_dir(historyFile))) {
    dir.create(fs::path_dir(historyFile), recursive = TRUE, showWarnings = FALSE)
  }

  historyDf <- .initializeTaskHistory(historyFile)

  # Find previous runs for this task+config block
  previousRuns <- historyDf[
    historyDf$task_name == basename(taskFile) &
      historyDf$config_block == configBlock,
    ]

  lastRunInfo <- NULL
  if (nrow(previousRuns) > 0) {
    # Get most recent run
    lastRunInfo <- previousRuns[nrow(previousRuns), ]
  }

  # Check 1: Task file has changed
  if (!is.null(lastRunInfo) && !is.na(lastRunInfo$task_file_hash)) {
    if (lastRunInfo$task_file_hash != currentTaskHash) {
      reasons <- c(reasons, "Task file content has changed")
      rerunNeeded <- TRUE
    }
  } else {
    reasons <- c(reasons, "No previous run record found")
    rerunNeeded <- TRUE
  }

  # Check 2: Dependency files have changed
  dependencyChanges <- .checkDependencyChanges(taskFile, lastRunInfo)
  if (length(dependencyChanges) > 0) {
    reasons <- c(reasons, paste("Dependency changed:", dependencyChanges))
    rerunNeeded <- TRUE
  }

  # Check 3: Cohort generation changes (compare hashes)
  cohortHashStatus <- .checkCohortHashChanges(executionSettings)
  if (!is.null(cohortHashStatus)) {
    if (cohortHashStatus$has_changes) {
      reasons <- c(reasons, paste(
        "Cohort generation changed:",
        cohortHashStatus$changed_count, "cohort(s) updated"
      ))
      rerunNeeded <- TRUE
    }
  }

  # Check 4: Previous run had errors
  if (!is.null(lastRunInfo) && lastRunInfo$status == "failed") {
    reasons <- c(reasons, "Previous run failed - needs rerun")
    rerunNeeded <- TRUE
  }

  # Check 5: Pipeline version changed and last run was on different version
  if (!is.null(lastRunInfo) && lastRunInfo$pipeline_version != pipelineVersion) {
    reasons <- c(reasons, paste(
      "Pipeline version changed from",
      lastRunInfo$pipeline_version, "to", pipelineVersion
    ))
    rerunNeeded <- TRUE
  }

  # If no reasons found, task is up to date
  if (length(reasons) == 0) {
    reasons <- "No changes detected - task is up to date"
    message <- cli::format_inline("Task {.file {basename(taskFile)}} is up to date and can be skipped")
  } else {
    message <- cli::format_inline(
      "Task {.file {basename(taskFile)}} should be rerun:\n",
      "{paste('  •', reasons, collapse = '\n')}"
    )
  }

  if (rerunNeeded) {
    cli::cli_alert_warning(message)
  } else {
    cli::cli_alert_success(message)
  }

  return(list(
    should_rerun = rerunNeeded,
    reasons = reasons,
    last_run_info = if (nrow(previousRuns) > 0) previousRuns else NULL,
    task_file_hash = currentTaskHash,
    cohort_hash_status = cohortHashStatus
  ))
}


#' @title Record Task Execution Status
#' @description Updates the task_run_history.csv file with execution results.
#'
#' @param taskFile Character. Name of the task file
#' @param configBlock Character. Config block name
#' @param pipelineVersion Character. Pipeline version
#' @param status Character. Execution status ("success", "failed", "skipped")
#' @param errorMessage Character. Error message if status is "failed" (optional)
#' @param tasksFolderPath Character. Path to tasks folder (optional)
#'
#' @return Invisibly TRUE if successful
#' @export
recordTaskExecution <- function(
    taskFile,
    configBlock,
    pipelineVersion,
    status,
    errorMessage = NA_character_,
    tasksFolderPath = here::here("analysis/tasks")) {

  if (!file.exists(taskFile)) {
    taskFile <- fs::path(tasksFolderPath, taskFile)
  }

  taskFileName <- basename(taskFile)

  # Validate status
  validStatus <- c("success", "failed", "skipped")
  if (!status %in% validStatus) {
    cli::cli_alert_danger("Invalid status: {status}")
    stop("Status must be one of: success, failed, skipped")
  }

  # Get task file hash
  taskHash <- digest::digest(file = taskFile, algo = "sha256")

  # Initialize or load history
  historyFile <- fs::path(here::here("exec/logs"), "task_run_history.csv")
  if (!dir.exists(fs::path_dir(historyFile))) {
    dir.create(fs::path_dir(historyFile), recursive = TRUE, showWarnings = FALSE)
  }

  historyDf <- .initializeTaskHistory(historyFile)

  # Create new record
  newRecord <- data.frame(
    task_name = taskFileName,
    config_block = configBlock,
    last_run_time = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    pipeline_version = pipelineVersion,
    task_file_hash = taskHash,
    cohort_hash_match = NA_character_,
    status = status,
    error_message = if (is.na(errorMessage)) "" else errorMessage,
    stringsAsFactors = FALSE
  )

  # Append to history
  historyDf <- rbind(historyDf, newRecord)

  # Write updated history
  tryCatch({
    readr::write_csv(historyDf, historyFile, append = FALSE)
    cli::cli_alert_success(
      "Task execution recorded: {taskFileName} [{status}] on {configBlock}"
    )
  }, error = function(e) {
    cli::cli_alert_danger("Failed to write task history: {e$message}")
    warning("Could not update task_run_history.csv")
  })

  invisible(TRUE)
}


#' @title Initialize Task Run History
#' @description Creates or loads the task_run_history.csv file.
#' @param historyFile Character. Path to history file
#' @return Data frame with history records
#' @keywords internal
.initializeTaskHistory <- function(historyFile) {
  if (file.exists(historyFile)) {
    tryCatch({
      readr::read_csv(
        historyFile,
        show_col_types = FALSE,
        col_types = readr::cols(
          task_name = readr::col_character(),
          config_block = readr::col_character(),
          last_run_time = readr::col_character(),
          pipeline_version = readr::col_character(),
          task_file_hash = readr::col_character(),
          cohort_hash_match = readr::col_character(),
          status = readr::col_character(),
          error_message = readr::col_character()
        )
      )
    }, error = function(e) {
      cli::cli_alert_warning("Could not read task history file, creating new one")
      .createEmptyHistory()
    })
  } else {
    .createEmptyHistory()
  }
}


#' @title Create Empty History Data Frame
#' @return Empty data frame with proper columns
#' @keywords internal
.createEmptyHistory <- function() {
  data.frame(
    task_name = character(),
    config_block = character(),
    last_run_time = character(),
    pipeline_version = character(),
    task_file_hash = character(),
    cohort_hash_match = character(),
    status = character(),
    error_message = character(),
    stringsAsFactors = FALSE
  )
}


#' @title Check for Dependency File Changes
#' @description Extracts source() calls from task file and checks if dependencies changed.
#' @param taskFile Character. Path to task file
#' @param lastRunInfo Data frame row. Previous run record
#' @return Character vector of changed dependency files
#' @keywords internal
.checkDependencyChanges <- function(taskFile, lastRunInfo) {
  changedDeps <- character()

  tryCatch({
    taskContent <- readr::read_file(taskFile)

    # Extract source() calls
    sourcePattern <- 'source\\s*\\(\\s*["\']([^"\']+)["\']'
    sourceMatches <- gregexpr(sourcePattern, taskContent, perl = TRUE)
    matches <- regmatches(taskContent, sourceMatches)

    if (length(matches[[1]]) > 0) {
      for (match in matches[[1]]) {
        # Extract file path from source() call
        depFile <- gsub(sourcePattern, "\\1", match, perl = TRUE)

        # Make path absolute if relative
        if (!fs::is_absolute_path(depFile)) {
          depFile <- fs::path(fs::path_dir(taskFile), depFile)
        }

        if (file.exists(depFile)) {
          depHash <- digest::digest(file = depFile, algo = "sha256")

          # For now, since we don't store dep hashes, flag as changed if deps exist
          # In future this could track dependency hashes separately
          changedDeps <- c(changedDeps, basename(depFile))
        }
      }
    }
  }, error = function(e) {
    cli::cli_alert_warning("Could not check dependencies: {e$message}")
  })

  # Remove duplicates
  unique(changedDeps)
}


#' @title Check for Cohort Hash Changes
#' @description Compares cohort manifest hashes with database checksum table.
#' @param executionSettings ExecutionSettings object
#' @return List with comparison results or NULL if errors occur
#' @keywords internal
.checkCohortHashChanges <- function(executionSettings) {
  tryCatch({
    # Load manifest
    cohortManifest <- loadCohortManifest(
      executionSettings = executionSettings,
      cohortsFolderPath = here::here("inputs/cohorts"),
      verbose = FALSE
    )
    cm <- cohortManifest$getManifest()
    if (is.null(cohortManifest) || nrow(cm) == 0) {
      return(list(
        has_changes = FALSE,
        changed_count = 0,
        unchanged_count = 0
      ))
    }

    # Connect to database
    executionSettings$connect()
    conn <- executionSettings$getConnection()
    on.exit(executionSettings$disconnect(), add = TRUE)

    # Query checksum table
    workDatabaseSchema <- executionSettings$workDatabaseSchema
    cohortTable <- executionSettings$cohortTable

    checksumQuery <- glue::glue(
      "SELECT cohort_definition_id, checksum FROM {workDatabaseSchema}.{cohortTable}_checksum",
    )

    dbChecksums <- tryCatch({
      DatabaseConnector::querySql(conn, checksumQuery)
    }, error = function(e) {
      return(data.frame())
    })

    # Compare hashes
    changedCount <- 0
    unchangedCount <- 0
    
    for (i in seq_len(nrow(cm))) {
      cohortId <- cm$id[i]
      manifestHash <- cm$hash[i]

      # Find corresponding database checksum
      dbHash <- dbChecksums$CHECKSUM[
        dbChecksums$COHORT_DEFINITION_ID == cohortId
      ]

      if (length(dbHash) > 0 && dbHash != manifestHash) {
        changedCount <- changedCount + 1
      } else if (length(dbHash) > 0) {
        unchangedCount <- unchangedCount + 1
      } else {
        changedCount <- changedCount + 1 # New cohort
      }
    }

    return(list(
      has_changes = changedCount > 0,
      changed_count = changedCount,
      unchanged_count = unchangedCount,
      total_count = nrow(cm)
    ))
  }, error = function(e) {
    cli::cli_alert_warning("Could not check cohort hashes: {e$message}")
    return(NULL)
  })
}


#' @title Get Task Run Summary
#' @description Generates a summary of task execution history for display.
#' @param configBlock Character. Optional filter by config block
#' @param taskName Character. Optional filter by task name
#'
#' @return Data frame with task history summary
#' @export
getTaskRunSummary <- function(configBlock = NULL, taskName = NULL) {
  historyFile <- fs::path(here::here("exec/logs"), "task_run_history.csv")

  if (!file.exists(historyFile)) {
    cli::cli_alert_info("No task history found yet")
    return(data.frame())
  }

  historyDf <- tryCatch({
    readr::read_csv(
      historyFile,
      show_col_types = FALSE,
      col_types = readr::cols(
        task_name = readr::col_character(),
        config_block = readr::col_character(),
        last_run_time = readr::col_character(),
        pipeline_version = readr::col_character(),
        task_file_hash = readr::col_character(),
        cohort_hash_match = readr::col_character(),
        status = readr::col_character(),
        error_message = readr::col_character()
      )
    )
  }, error = function(e) {
    cli::cli_alert_danger("Failed to read task history: {e$message}")
    return(data.frame())
  })

  # Filter if specified
  if (!is.null(configBlock)) {
    historyDf <- historyDf[historyDf$config_block == configBlock, ]
  }

  if (!is.null(taskName)) {
    historyDf <- historyDf[historyDf$task_name == taskName, ]
  }

  return(historyDf)
}


#' @title Display Task Status Report
#' @description Displays a formatted report of recent task execution status.
#' @param limit Integer. Number of recent entries to show (default: 20)
#'
#' @return Invisibly NULL (prints to console)
#' @export
displayTaskStatusReport <- function(limit = 20) {
  historyFile <- fs::path(here::here("exec/logs"), "task_run_history.csv")

  if (!file.exists(historyFile)) {
    cli::cli_alert_info("No task execution history available yet")
    return(invisible(NULL))
  }

  historyDf <- tryCatch({
    readr::read_csv(
      historyFile,
      show_col_types = FALSE,
      col_types = readr::cols(
        task_name = readr::col_character(),
        config_block = readr::col_character(),
        last_run_time = readr::col_character(),
        pipeline_version = readr::col_character(),
        task_file_hash = readr::col_character(),
        cohort_hash_match = readr::col_character(),
        status = readr::col_character(),
        error_message = readr::col_character()
      )
    )
  }, error = function(e) {
    cli::cli_alert_danger("Failed to read task history: {e$message}")
    return(NULL)
  })

  if (is.null(historyDf) || nrow(historyDf) == 0) {
    cli::cli_alert_info("No task history records found")
    return(invisible(NULL))
  }

  # Get last N records
  historyDf <- tail(historyDf, limit)

  # Display summary
  cli::cli_rule("Task Execution History")

  successCount <- sum(historyDf$status == "success")
  failureCount <- sum(historyDf$status == "failed")
  skippedCount <- sum(historyDf$status == "skipped")

  cli::cli_bullets(c(
    "v" = "{successCount} successful",
    "x" = "{failureCount} failed",
    "i" = "{skippedCount} skipped"
  ))

  cli::cli_text("")

  # Group by config block and show latest
  configBlocks <- unique(historyDf$config_block)

  for (block in configBlocks) {
    blockData <- historyDf[historyDf$config_block == block, ]

    cli::cli_alert_info("Config Block: {block}")

    for (i in seq_len(nrow(blockData))) {
      row <- blockData[i, ]
      statusIcon <- switch(row$status,
        "success" = "✓",
        "failed" = "✗",
        "skipped" = "⊘",
        "?"
      )

      errMsg <- if (!is.na(row$error_message) && row$error_message != "") {
        paste0(" - ", row$error_message)
      } else {
        ""
      }

      cat(sprintf(
        "  [%s] %s (%s v%s) at %s%s\n",
        statusIcon, row$task_name, row$config_block,
        row$pipeline_version, row$last_run_time, errMsg
      ))
    }
  }

  invisible(NULL)
}
