#' Import and Bind Results by Version and Task
#' @description Combines result files across multiple database runs for a specific version and task.
#'   Finds all CSV files in the task folder for each database and combines them into named results,
#'   then saves them to the export folder.
#' @param version Character. Pipeline version (e.g., "1.0.0")
#' @param taskName Character. Name of the task (e.g., "cohortCounts", "characterization")
#' @param dbIds Character vector of database configuration IDs from config.yml
#' @param resultsPath Character. Path to results root folder. Defaults to "exec/results"
#' @param exportPath Character. Path where combined results will be saved. 
#'   Defaults to "dissemination/export/merge"
#' @return Invisibly returns data frame of export summary with columns: fileName, rowCount, databaseCount
#' @details
#' Folder structure expected:
#' ```
#' exec/results/
#'   databaseName1/
#'     version/
#'       taskName/
#'         file1.csv
#'         file2.csv
#'   databaseName2/
#'     version/
#'       taskName/
#'         file1.csv
#'         file2.csv
#' ```
#'
#' All files with the same name from each database are combined with databaseId added and saved to exportPath.
#' @export
importAndBind <- function(version, taskName, dbIds, resultsPath = here::here("exec/results"),
                          exportPath = here::here("dissemination/export/merge")) {
  
  # Get database names from config
  databaseNames <- purrr::map_chr(dbIds, ~config::get("databaseName", config = .x))
  
  # Build task folder paths for each database
  taskFolders <- purrr::map_chr(
    databaseNames,
    ~fs::path(resultsPath, .x, version, taskName)
  )
  
  # Verify task folders exist for all databases
  missingFolders <- taskFolders[!fs::dir_exists(taskFolders)]
  if (length(missingFolders) > 0) {
    cli::cli_alert_warning("Task folder(s) not found:")
    cli::cli_bullets(setNames(fs::path_rel(missingFolders), "x"))
  }
  
  # Get all CSV files from the first database to identify files to combine
  firstValidFolder <- taskFolders[fs::dir_exists(taskFolders)][1]
  
  if (is.na(firstValidFolder)) {
    cli::cli_alert_danger("No valid task folders found for version {version}, task {taskName}")
    stop("Cannot find task results")
  }
  
  # Get all CSV files only - ignore other data file types
  allFiles <- fs::dir_ls(firstValidFolder, glob = "*.csv", type = "file")
  fileNames <- basename(allFiles)
  
  # Filter to ensure only CSV files are included
  fileNames <- fileNames[tolower(tools::file_ext(fileNames)) == "csv"]
  
  if (length(fileNames) == 0) {
    cli::cli_alert_warning("No CSV files found in task folder: {fs::path_rel(firstValidFolder)}")
    return(list())
  }
  
  cli::cli_alert_info("Found {length(fileNames)} CSV file(s) to combine")
  
  # For each CSV file, read from all databases and combine
  combinedResults <- list()
  exportSummary <- data.frame(
    fileName = character(),
    rowCount = integer(),
    databaseCount = integer(),
    stringsAsFactors = FALSE
  )
  
  for (fileName in fileNames) {
    tryCatch({
      # Only process CSV files - skip any other file types
      if (tolower(tools::file_ext(fileName)) != "csv") {
        cli::cli_alert_warning("Skipping non-CSV file: {fileName}")
        next
      }
      
      fileData <- list()
      successCount <- 0
      
      for (i in seq_along(databaseNames)) {
        filePath <- fs::path(taskFolders[i], fileName)
        
        if (fs::file_exists(filePath)) {
          fileData[[i]] <- readr::read_csv(filePath, show_col_types = FALSE) |>
            dplyr::mutate(
              databaseId = databaseNames[i],
              .before = 1
            )
          successCount <- successCount + 1
        }
      }
      
      if (successCount > 0) {
        # Combine all data frames, keeping only those that were successfully read
        combined <- do.call('rbind', fileData[!sapply(fileData, is.null)]) |>
          tibble::as_tibble()
        
        # Save to export path
        fs::dir_create(exportPath, recurse = TRUE)
        exportFile <- fs::path(exportPath, fileName)
        readr::write_csv(combined, exportFile)
        
        labelName <- tools::file_path_sans_ext(fileName)
        combinedResults[[labelName]] <- combined
        
        cli::cli_alert_success("Combined {fileName}: {nrow(combined)} rows from {successCount} database(s)")
        cli::cli_alert_success("Saved to: {fs::path_rel(exportFile)}")
        
        # Add to summary
        exportSummary <- rbind(
          exportSummary,
          data.frame(
            fileName = fileName,
            rowCount = nrow(combined),
            databaseCount = successCount,
            stringsAsFactors = FALSE
          )
        )
      } else {
        cli::cli_alert_warning("Could not find {fileName} in any database folder")
      }
    }, error = function(e) {
      cli::cli_alert_danger("Error combining {fileName}: {e$message}")
    })
  }
  
  # Return summary invisibly
  if (length(combinedResults) == 0) {
    cli::cli_alert_warning("No files were successfully combined")
  } else {
    cli::cli_alert_success("Export complete: {nrow(exportSummary)} file(s) saved to {fs::path_rel(exportPath)}")
  }
  
  invisible(exportSummary)
}

#' Validate Required Columns in Results
#' @description Checks that a results data frame has the required columns: databaseId, cohortId, cohortLabel
#' @param resultsData Data frame to validate
#' @param stepName Character. Name of the post-processing step (for error messages)
#' @return Logical. TRUE if valid, stops with error if not
#' @keywords internal
validateResultsColumns <- function(resultsData, stepName) {
  requiredCols <- c("databaseId", "cohortId", "cohortLabel")
  missingCols <- setdiff(requiredCols, names(resultsData))
  
  if (length(missingCols) > 0) {
    cli::cli_alert_danger("Results from {stepName} missing required columns:")
    cli::cli_bullets(setNames(missingCols, "x"))
    stop(paste("Missing columns in", stepName))
  }
  
  invisible(TRUE)
}

#' Execute Post-Processing Pipeline
#' @description Orchestrates running a series of post-processing steps after pipeline execution
#' @param dbIds Character vector of database identifiers from config.yml
#' @param executionSettings ExecutionSettings object for cohort manifest loading
#' @param postProcessFiles Character vector of CSV file names to consolidate from results
#' @param outputFolder Character. Path where consolidated results will be saved. 
#'   Defaults to exec/results/consolidated
#' @param resultsPath Character. Path to pipeline results folder. 
#'   Defaults to exec/results
#' @return Invisibly returns list of consolidated data frames
#' @details
#' This function:
#' 1. Loads cohort metadata from the manifest
#' 2. Creates results path data frame for each database
#' 3. Imports and consolidates post-processing files from all databases
#' 4. Adds cohortLabel to each result set
#' 5. Saves consolidated results to CSV files
#' 6. Validates all required columns are present (databaseId, cohortId, cohortLabel)
#' @export
executePostProcessing <- function(dbIds,
                                  executionSettings,
                                  postProcessFiles,
                                  outputFolder = here::here("dissemination/export/pretty"),
                                  resultsPath = here::here("exec/results")) {
  
  cli::cli_rule("Execute Post-Processing Pipeline")
  
  tryCatch({
    # Step 1: Load cohort metadata
    cli::cli_alert_info("Loading cohort metadata...")
    cohortMetadata <- loadCohortMetadata(executionSettings)
    cli::cli_alert_success("Loaded {nrow(cohortMetadata)} cohort definitions")
    
    # Step 2: Create results path data frame
    cli::cli_alert_info("Mapping database result paths...")
    resultsPathDat <- getResultsPathDat(dbIds, resultsPath)
    cli::cli_alert_success("Found results for {nrow(resultsPathDat)} database(s)")
    
    # Step 3: Consolidate post-processing results
    consolidatedResults <- consolidatePostResults(
      resultsPathDat,
      postProcessFiles,
      cohortMetadata
    )
    
    # Step 4: Save consolidated results
    cli::cli_alert_info("Saving consolidated results...")
    fs::dir_create(outputFolder, recurse = TRUE)
    
    for (fileName in names(consolidatedResults)) {
      outputPath <- fs::path(outputFolder, fileName)
      readr::write_csv(consolidatedResults[[fileName]], outputPath)
      cli::cli_alert_success("Saved: {fs::path_rel(outputPath)}")
    }
    
    cli::cli_alert_success("Post-processing complete!")
    
    invisible(consolidatedResults)
  }, error = function(e) {
    cli::cli_alert_danger("Post-processing failed: {e$message}")
    stop("Post-processing pipeline error")
  })
}

#' Review Export File Schema
#' @description Examines all CSV files in the export folder and extracts schema information
#'   (column names and data types). Useful for identifying ETL requirements before dissemination.
#' @param exportPath Character. Path to the export folder containing merged results.
#'   Defaults to "dissemination/export/merge"
#' @return Data frame with columns:
#'   - fileName: Name of the CSV file
#'   - columnName: Name of the column
#'   - dataType: R data type as detected by readr (character, numeric, logical, etc.)
#'   - rowCount: Number of rows in the file
#' @details
#' This function helps identify:
#' - Column naming inconsistencies across files
#' - Unexpected data types that may need transformation
#' - Columns that should be renamed or restructured
#' - Data quality issues (e.g., columns with mostly NAs)
#'
#' The data frame can be sorted/filtered to understand transformation requirements.
#' @export
#' @examples
#' \dontrun{
#'   schema <- reviewExportSchema()
#'   
#'   # View all columns and types
#'   print(schema)
#'   
#'   # Check for character columns that should be numeric
#'   schema[schema$dataType == "character", ]
#'   
#'   # Get distinct data types per file
#'   schema |>
#'     dplyr::group_by(fileName) |>
#'     dplyr::summarise(colCount = dplyr::n(), .groups = "drop")
#' }
reviewExportSchema <- function(exportPath = here::here("dissemination/export/merge")) {
  
  cli::cli_rule("Review Export File Schema")
  
  # Check if export path exists
  if (!dir.exists(exportPath)) {
    cli::cli_alert_danger("Export path does not exist: {fs::path_rel(exportPath)}")
    stop("Export folder not found")
  }
  
  # Get all CSV files except schema_review files
  csvFiles <- fs::dir_ls(exportPath, glob = "*.csv", type = "file")
  # exclude any files that are schema reviews (to avoid self-inclusion)
  csvFiles <- csvFiles[!grepl("schema_review", basename(csvFiles))]
  
  if (length(csvFiles) == 0) {
    cli::cli_alert_info("No CSV files found in export path")
    return(data.frame(
      fileName = character(),
      columnName = character(),
      dataType = character(),
      rowCount = integer(),
      stringsAsFactors = FALSE
    ))
  }
  
  cli::cli_alert_info("Reviewing {length(csvFiles)} export file(s)...")
  
  # Extract schema information from each file
  schemaList <- list()
  
  for (filePath in csvFiles) {
    fileName <- basename(filePath)
    
    tryCatch({
      # Read the file to get column information
      # Use spec_csv to get data types without reading all rows
      spec <- readr::spec_csv(filePath)
      
      # Get row count
      rowCount <- length(readr::read_lines(filePath)[-1])   # Count lines minus header
      
      # Extract column specs
      for (colName in names(spec$cols)) {
        colClass <- class(spec$cols[[colName]])[1]
        
        # Simplify class name (e.g., "collector_character" -> "character")
        dataType <- gsub("collector_", "", colClass)
        
        schemaList[[paste0(fileName, "_", colName)]] <- data.frame(
          fileName = fileName,
          columnName = colName,
          dataType = dataType,
          rowCount = rowCount,
          stringsAsFactors = FALSE
        )
      }
      
      cli::cli_alert_success("Reviewed {fileName}: {length(spec$cols)} columns, {rowCount} rows")
    }, error = function(e) {
      cli::cli_alert_danger("Error reviewing {fileName}: {e$message}")
    })
  }
  
  # Combine all schema information
  if (length(schemaList) == 0) {
    return(data.frame(
      fileName = character(),
      columnName = character(),
      dataType = character(),
      rowCount = integer(),
      stringsAsFactors = FALSE
    ))
  }
  
  schema <- do.call('rbind', schemaList) |>
    tibble::as_tibble() |>
    dplyr::arrange(fileName)
  
  rownames(schema) <- NULL
  
  # Print summary
  cli::cli_alert_success("Schema review complete!")
  cli::cli_bullets(c(
    "v" = "{length(unique(schema$fileName))} file(s) reviewed",
    "v" = "{nrow(schema)} total columns"
  ))
  
  return(schema)
}

#' Merge Pipeline Results for All Tasks
#' @description Orchestrates merging of results across all tasks for a specified pipeline version.
#'   Discovers all task folders for the version, calls importAndBind for each task, and tracks
#'   the consolidated results.
#' @param pipelineVersion Character. Pipeline version (e.g., "1.0.0")
#' @param dbIds Character vector of database configuration IDs from config.yml
#' @param resultsPath Character. Path to results root folder. Defaults to "exec/results"
#' @param exportPath Character. Path where combined results will be saved.
#'   Defaults to "dissemination/export/merge"
#' @param executionSettings ExecutionSettings object for cohort manifest loading (optional).
#'   If provided, generates a cohortKey reference file with id, label, and tags.
#' @return Data frame summarizing all merged tasks with columns:
#'   - taskName: Name of the task
#'   - fileCount: Number of result files found for that task
#'   - totalRows: Total rows across all result files
#'   - filesExported: Comma-separated list of exported file names
#' @details
#' The function:
#' 1. Scans the first database's version folder to discover available tasks
#' 2. For each task found, calls importAndBind() to merge across databases
#' 3. Tracks which files were successfully merged
#' 4. Returns a summary data frame of the merge operation
#'
#' Expected folder structure:
#' ```
#' exec/results/
#'   databaseName1/
#'     version/
#'       task1/
#'         results.csv
#'       task2/
#'         results.csv
#'   databaseName2/
#'     version/
#'       task1/
#'         results.csv
#'       task2/
#'         results.csv
#' ```
#' @export
mergePipelineResults <- function(pipelineVersion, dbIds, resultsPath = here::here("exec/results"),
                                 exportPath = here::here("dissemination/export/merge"),
                                 executionSettings = NULL) {
  
  cli::cli_rule("Merge Pipeline Results for Version {pipelineVersion}")
  
  # Get database names and labels from config
  databaseNames <- purrr::map_chr(dbIds, ~config::get("databaseName", config = .x))
  databaseLabels <- purrr::map_chr(dbIds, ~config::get("databaseLabel", config = .x, default = .x))
  cohortTableNames <- purrr::map_chr(dbIds, ~config::get("cohortTable", config = .x, default = "cohort"))
  
  # Create database info reference file
  databaseInfo <- data.frame(
    databaseId = dbIds,
    databaseName = databaseNames,
    databaseLabel = databaseLabels,
    cohortTable = cohortTableNames,
    stringsAsFactors = FALSE
  )
  
  # Build path to first database's version folder
  firstDbVersionPath <- fs::path(resultsPath, databaseNames[1], pipelineVersion)
  
  if (!dir.exists(firstDbVersionPath)) {
    cli::cli_alert_danger("Version folder not found: {fs::path_rel(firstDbVersionPath)}")
    stop("Cannot find results for version {pipelineVersion}")
  }
  
  # Create version-specific export path
  versionExportPath <- fs::path(exportPath, glue::glue("v{pipelineVersion}"))
  fs::dir_create(versionExportPath, recurse = TRUE)
  cli::cli_alert_info("Export path: {fs::path_rel(versionExportPath)}")
  
  # Discover all task folders for this version
  taskFolders <- fs::dir_ls(firstDbVersionPath, type = "directory")
  
  if (length(taskFolders) == 0) {
    cli::cli_alert_info("No task folders found for version {pipelineVersion}")
    return(data.frame(
      taskName = character(),
      fileCount = integer(),
      totalRows = integer(),
      filesExported = character(),
      stringsAsFactors = FALSE
    ))
  }
  
  taskNames <- basename(taskFolders)
  
  cli::cli_alert_info("Found {length(taskNames)} task(s) for version {pipelineVersion}")
  cli::cli_bullets(setNames(taskNames, "•"))
  
  # Process each task
  mergeSummary <- data.frame(
    taskName = character(),
    fileCount = integer(),
    totalRows = integer(),
    filesExported = character(),
    stringsAsFactors = FALSE
  )
  
  for (taskName in taskNames) {
    cli::cli_h3("Processing task: {taskName}")
    
    tryCatch({
      # Call importAndBind for this task
      exportSummary <- importAndBind(
        version = pipelineVersion,
        taskName = taskName,
        dbIds = dbIds,
        resultsPath = resultsPath,
        exportPath = versionExportPath
      )
      
      if (nrow(exportSummary) > 0) {
        # Calculate merged statistics
        fileCount <- nrow(exportSummary)
        totalRows <- sum(exportSummary$rowCount, na.rm = TRUE)
        filesExported <- paste(exportSummary$fileName, collapse = ", ")
        
        # Add to summary
        mergeSummary <- rbind(
          mergeSummary,
          data.frame(
            taskName = taskName,
            fileCount = fileCount,
            totalRows = totalRows,
            filesExported = filesExported,
            stringsAsFactors = FALSE
          )
        )
      } else {
        cli::cli_alert_warning("No files merged for task {taskName}")
      }
    }, error = function(e) {
      cli::cli_alert_danger("Error processing task {taskName}: {e$message}")
    })
  }
  
  # Print final summary
  if (nrow(mergeSummary) > 0) {
    cli::cli_alert_success("Pipeline merge complete for version {pipelineVersion}")
    cli::cli_bullets(c(
      "v" = "{nrow(mergeSummary)} task(s) processed",
      "v" = "{sum(mergeSummary$fileCount)} total files exported",
      "v" = "{sum(mergeSummary$totalRows)} total rows merged"
    ))
  } else {
    cli::cli_alert_warning("No tasks were successfully processed")
  }
  
  # Review the export schema
  cli::cli_text("")
  schema <- reviewExportSchema(exportPath = versionExportPath)
  
  # Save schema review results to export folder
  schemaFilePath <- fs::path(versionExportPath, "schema_review.csv")
  
  tryCatch({
    readr::write_csv(schema, schemaFilePath)
    cli::cli_alert_success("Schema review results saved to {fs::path_rel(schemaFilePath)}")
  }, error = function(e) {
    cli::cli_alert_danger("Error saving schema review: {e$message}")
  })
  
  # Save database info reference file
  tryCatch({
    databaseInfoPath <- fs::path(versionExportPath, "databaseInfo.csv")
    readr::write_csv(databaseInfo, databaseInfoPath)
    cli::cli_alert_success("Database info saved to {fs::path_rel(databaseInfoPath)}: {nrow(databaseInfo)} database(s)")
  }, error = function(e) {
    cli::cli_alert_danger("Error saving database info: {e$message}")
  })
  
  # Create cohortKey reference file if executionSettings provided
  if (!is.null(executionSettings)) {
    tryCatch({
      cli::cli_text("")
      cli::cli_alert_info("Creating cohort key reference file...")
      
      # Load cohort metadata
      cohortMetadata <- loadCohortMetadata(executionSettings, verbose = FALSE)
      
      # Extract id, label, and tags columns
      cohortKey <- cohortMetadata |>
        dplyr::select(cohortId, cohortLabel, cohortTags) |>
        dplyr::distinct()
      
      # Save cohortKey to export folder
      cohortKeyPath <- fs::path(versionExportPath, "cohortKey.csv")
      readr::write_csv(cohortKey, cohortKeyPath)
      
      cli::cli_alert_success("Cohort key saved to {fs::path_rel(cohortKeyPath)}: {nrow(cohortKey)} cohort(s)")
    }, error = function(e) {
      cli::cli_alert_danger("Error creating cohort key: {e$message}")
    })
  }
  
  # Convert to tibble and return invisibly
  mergeSummary <- tibble::as_tibble(mergeSummary)
  invisible(mergeSummary)
}
