#' @title Function to update the study version
#' @param versionNumber the semantive version number to set as the new project version: 1.0.0
#' @param projectPath the path of the project, defaults to the directory of the active Ulysses project
#' @export
updateStudyVersion <- function(versionNumber, projectPath = here::here()) {

  if (check_git_status()) {
    msg <- "There are uncommited changes!!! Please add and commit changes prior to updatng the project version"
    stop(msg)
  }

  # read in yml file
  configYml <- readr::read_lines(fs::path(here::here(), "config.yml"))
  # find the line where the version is
  versionLine <- which(grepl("  version: ", configYml))
  # replace the line with the new version number
  configYml[versionLine] <- glue::glue("  version: {versionNumber}")

  cli::cat_bullet(
    glue::glue_col("Update Study Version to: {yellow {versionNumber}}"),
    bullet = "info",
    bullet_col = "blue"
  )
  cli::cat_bullet(
    glue::glue_col("Overwrite {cyan config.yml} with update!"),
    bullet = "info",
    bullet_col = "blue"
  )

  # update and overwrite the yml file with the new version
  readr::write_lines(x = configYml, file = fs::path(here::here(), "config.yml"))
  updateNews(versionNumber = versionNumber, projectPath = projectPath)
  invisible(versionNumber)
}


#' @title Zip and Archive results from a study execution
#' @param input the type of files to zip and archive. There are three options exportMerge, exportPretty and site. exportMerge is the merged results in long format. The exportPretty are xlsx files with formatted output from the study. The site is the html files of the studyHub
#' @returns invisible return. Stores the input as a zip file in the exec/archive folder
#' @export
zipAndArchive <- function(input) {
  #ensure input is one of three options
  checkmate::assert_choice(x = input, choices = c("exportMerge", "exportPretty", "site"))

  # make the archive folder in exec
  if (!dir.exists("exec/archive")) {
    archivePathRoot <- fs::dir_create("exec/archive")
    usethis::use_git_ignore(archivePathRoot)
  }

  # get time stamp of archive
  timeStamp <- lubridate::now() |> as.character() |> snakecase::to_snake_case()

  # pull version number from config
  repoVersion <- config::get(value = "version")

  # if input is exportMerge grab results and prep for archive
  if (input == "exportMerge") {
    files2zip <- fs::dir_ls("dissemination/export/merge", type = "file")
    zipFileName <- glue::glue("exec/archive/export_merge_{repoVersion}_{timeStamp}")
  }

  # if input is exportPretty grab results and prep for archive
  if (input == "exportPretty") {
    files2zip <- fs::dir_ls("dissemination/export/pretty", type = "file")
    zipFileName <- glue::glue("exec/archive/export_pretty_{repoVersion}_{timeStamp}")
  }

  # if input is site grab files and prep for archive
  if (input == "exportMerge") {
    files2zip <- fs::dir_ls("dissemination/quarto/_site", type = "any")
    zipFileName <- glue::glue("exec/archive/quarto_site_{repoVersion}_{timeStamp}")
  }

  # zip results and place in archive
  utils::zip(zipfile = zipFileName, files = files2zip)
  cli::cat_bullet(
    glue::glue("Archived {input} to {zipFileName}."),
    bullet = "tick",
    bullet_col = "green"
  )

  invisible(zipFileName)

}


#' @title Generate Cohorts for Pipeline Execution
#' @description Loads the cohort manifest, displays the cohorts to be generated,
#'   optionally prompts for user confirmation, and then generates the cohorts
#'   and retrieves their counts. This function serves as the foundational step
#'   for all subsequent analytical tasks in the pipeline.
#' @param executionSettings An ExecutionSettings object containing database configuration
#'   for cohort generation.
#' @param pipelineVersion Character. The pipeline version used to organize the output folder structure.
#'   Output will be saved to exec/results/{databaseName}/{pipelineVersion}/00_buildCohorts/
#' @param override Logical. If TRUE, skips the user confirmation prompt and proceeds
#'   directly with cohort generation. Defaults to FALSE.
#' @return Invisibly returns the cohort counts data frame (id, label, tags, 
#'   cohort_entries, cohort_subjects). Also saves counts to cohortCounts.csv in the 
#'   output folder.
#' @export
generateCohorts <- function(executionSettings, pipelineVersion, override = FALSE) {
  
  # Check if cohortManifest exists
  cohortsFolderPath <- here::here("inputs/cohorts")
  dbPath <- fs::path(cohortsFolderPath, "cohortManifest.sqlite")
  
  if (!file.exists(dbPath)) {
    cli::cli_alert_danger("Cohort Manifest not found!")
    cli::cli_alert_info("Expected location: {fs::path_rel(dbPath)}")
    cli::cli_rule("How to create a Cohort Manifest")
    cli::cli_h2("Option 1: Use launchCohortsLoadEditor to create metadata file")
    cli::cli_code("launchCohortsLoadEditor()")
    cli::cli_h2("Option 2: Import cohorts from ATLAS")
    cli::cli_code("importAtlasCohorts(atlasIds = c(123, 456, 789))")
    cli::cli_h2("Option 3: Place cohort files and reload")
    cli::cli_bullets(c(
      "Place JSON or SQL files in {.path {cohortsFolderPath}/json} or {.path {cohortsFolderPath}/sql}",
      "Then call: {.code loadCohortManifest(executionSettings)}"
    ))
    cli::cli_rule()
    stop("Cannot proceed without a cohort manifest. Please create one using one of the options above.")
  }
  
  # Load the cohort manifest
  tryCatch({
    cm <- loadCohortManifest(executionSettings = executionSettings)
  }, error = function(e) {
    cli::cli_alert_danger("Failed to load cohort manifest: {e$message}")
    stop("Error loading cohort manifest")
  })
  
  # Get the manifest summary
  cmSummary <- cm$getManifest()
  
  if (is.null(cmSummary) || nrow(cmSummary) == 0) {
    cli::cli_alert_danger("Cohort manifest is empty!")
    stop("No cohorts found in manifest. Please add cohorts before generating.")
  }
  
  # Display the cohorts that will be generated
  cli::cli_rule("Cohorts to Generate")
  cli::cli_alert_info("Found {nrow(cmSummary)} cohort(s) in manifest")
  
  # Format and display the cohorts
  for (i in seq_len(nrow(cmSummary))) {
    row <- cmSummary[i, ]
    cohort_id <- row$id
    cohort_label <- row$label
    cohort_tags <- row$tags
    
    # Display basic info
    cli::cli_alert_success("Cohort {cohort_id}: {cohort_label}")
    
    # Display tags if available
    if (!is.na(cohort_tags) && cohort_tags != "" && cohort_tags != "NULL") {
      cli::cli_bullets(c(i = "Tags: {cohort_tags}"))
    }
  }
  cli::cli_rule()
  
  # Ask for user confirmation unless override is TRUE
  if (!override) {
    cli::cli_alert_warning("Generate these {nrow(cmSummary)} cohort(s)?")
    response <- readline(prompt = "Continue? (yes/no): ")
    response <- tolower(trimws(response))
    
    if (!(response %in% c("yes", "y"))) {
      cli::cli_alert_info("Cohort generation cancelled by user.")
      cli::cli_bullets(c(
        i = "To modify cohorts, use {.code launchCohortsLoadEditor()}",
        i = "To import new cohorts from ATLAS, use {.code importAtlasCohorts()}"
      ))
      return(invisible(NULL))
    }
  }
  
  # Generate cohorts
  cli::cli_alert_info("Starting cohort generation...")
  
  tryCatch({
    cm$createCohortTables()
    cm$generateCohorts()
    counts <- cm$retrieveCohortCounts()
    
    cli::cli_alert_success("Cohort generation completed successfully!")
    cli::cli_rule("Cohort Counts")
    print(counts)
    cli::cli_rule()
    
    # Save cohort counts to output folder
    databaseName <- executionSettings$databaseName
    dbNameSnake <- snakecase::to_snake_case(databaseName)
    
    outputFolder <- fs::path(
      here::here("exec/results"),
      dbNameSnake,
      pipelineVersion,
      "00_buildCohorts"
    )
    
    # Create output folder if it doesn't exist
    if (!dir.exists(outputFolder)) {
      dir.create(outputFolder, recursive = TRUE, showWarnings = FALSE)
      cli::cli_alert_success("Created output folder: {fs::path_rel(outputFolder)}")
    }
    
    # Save cohort counts to CSV
    outputFile <- fs::path(outputFolder, "cohortCounts.csv")
    readr::write_csv(counts, file = outputFile)
    cli::cli_alert_success("Saved cohort counts to: {fs::path_rel(outputFile)}")
    
    return(invisible(counts))
  }, error = function(e) {
    cli::cli_alert_danger("Error during cohort generation: {e$message}")
    stop("Cohort generation failed")
  })
}

#' @title Validate Study Task Script
#' @description Validates that a study task R script has all required components to work
#'   in the pipeline. Checks for required sections, template variables, executionSettings
#'   creation, output folder setup, and non-empty script section.
#' @param taskFilePath Character. The full path to the task R script to validate.
#' @return Logical. Returns TRUE if valid. Stops with an error message if validation fails.
#' @details
#' A valid study task must contain:
#' - Section headers: A. Meta, B. Dependencies, C. Connection Settings, D. Task Settings, E. Script
#' - Template variables: !||configBlock||! and !||pipelineVersion||!
#' - ExecutionSettings creation (assignment to executionSettings object)
#' - Output folder creation (assignment to outputFolder object)
#' - Non-empty E. Script section (more than just the template comment)
#' @export
validateStudyTask <- function(taskFilePath) {
  
  # Verify file exists
  if (!file.exists(taskFilePath)) {
    cli::cli_alert_danger("Task file not found: {fs::path_rel(taskFilePath)}")
    stop("Task file does not exist")
  }
  
  # Read the file
  tryCatch({
    fileContent <- readr::read_file(taskFilePath)
  }, error = function(e) {
    cli::cli_alert_danger("Failed to read task file: {e$message}")
    stop("Error reading task file")
  })
  
  # Split into lines for section checking
  fileLines <- readr::read_lines(taskFilePath)
  
  # List of required sections
  requiredSections <- c(
    "A. Meta",
    "B. Dependencies",
    "C. Connection Settings",
    "D. Task Settings",
    "E. Script"
  )
  
  # Check for required sections
  missingSections <- character()
  for (section in requiredSections) {
    if (!any(grepl(section, fileLines, fixed = TRUE))) {
      missingSections <- c(missingSections, section)
    }
  }
  
  if (length(missingSections) > 0) {
    cli::cli_alert_danger("Missing required sections in task file:")
    cli::cli_bullets(setNames(missingSections, "x"))
    stop("Task is missing required sections")
  }
  
  # Check for required template variables
  requiredVars <- c("!||configBlock||!", "!||pipelineVersion||!")
  missingVars <- character()
  
  for (var in requiredVars) {
    if (!grepl(var, fileContent, fixed = TRUE)) {
      missingVars <- c(missingVars, var)
    }
  }
  
  if (length(missingVars) > 0) {
    cli::cli_alert_danger("Missing required template variables:")
    cli::cli_bullets(setNames(missingVars, "x"))
    stop("Task is missing required configuration variables")
  }
  
  # Check for executionSettings creation
  if (!grepl("executionSettings\\s*(<-|=)", fileContent)) {
    cli::cli_alert_danger("Task must create an executionSettings object")
    cli::cli_bullets(c(
      i = "Add: {.code executionSettings <- createExecutionSettingsFromConfig(configBlock = configBlock)}"
    ))
    stop("executionSettings object not created")
  }
  
  # Check for outputFolder creation
  if (!grepl("outputFolder\\s*(<-|=)", fileContent)) {
    cli::cli_alert_danger("Task must create an outputFolder object")
    cli::cli_bullets(c(
      i = "Add: {.code outputFolder <- setOutputFolder(executionSettings = executionSettings, ...)} in section D"
    ))
    stop("outputFolder object not created")
  }
  
  # Check that E. Script section has actual code (not just template comment)
  eScriptIndex <- which(grepl("E. Script", fileLines, fixed = TRUE))
  
  if (length(eScriptIndex) > 0) {
    # Get lines after E. Script section
    scriptLinesStart <- eScriptIndex[1] + 1
    scriptLines <- fileLines[scriptLinesStart:length(fileLines)]
    
    # Remove empty lines and comment lines that are just the template notes
    codeLines <- scriptLines[
      scriptLines != "" & 
      !grepl("^\\s*#.*Note: Add code", scriptLines)
    ]
    
    # Check if there's any actual code (not just comments)
    actualCode <- codeLines[!grepl("^\\s*#", codeLines)]
    
    if (length(actualCode) == 0 || all(trimws(actualCode) == "")) {
      cli::cli_alert_danger("E. Script section is empty!")
      cli::cli_bullets(c(
        i = "Add analysis or processing code under the 'E. Script' section"
      ))
      stop("Task has no implementation code in E. Script section")
    }
  }
  
  cli::cli_alert_success("Task validation successful: {fs::path_rel(taskFilePath)}")
  invisible(TRUE)
}

#' @title Function to execute a study task in Ulysses
#' @param taskFile the name of the taskFile. Only use the base name
#' @param configBlock the name of the configBlock to use in the execution
#' @param pipelineVersion the version of the pipeline to use in the execution. This is used to set the output folder for the task results.
#' @param generateCohorts Logical. If TRUE, generates cohorts before executing the task. Defaults to FALSE.
#' @param executionSettings An ExecutionSettings object (required if generateCohorts = TRUE).
#'   Contains database configuration for cohort generation.
#' @param env the execution environment
#' @export
execStudyTask <- function(taskFile, configBlock, pipelineVersion, 
                          generateCohorts = FALSE, executionSettings = NULL,
                          env = rlang::caller_env()) {

  cli::cat_rule(glue::glue_col("Run Task: {yellow {taskFile}}"))
  cli::cat_bullet(
    glue::glue_col("Using config: {green {configBlock}}"),
    bullet = "info",
    bullet_col = "blue"
  )

  # Generate cohorts if requested
  if (generateCohorts) {
    if (is.null(executionSettings)) {
      cli::cli_alert_danger("executionSettings required when generateCohorts = TRUE")
      stop("executionSettings must be provided to generate cohorts")
    }
    
    cli::cli_alert_info("Generating cohorts before executing task...")
    tryCatch({
      generateCohorts(executionSettings, pipelineVersion = pipelineVersion)
    }, error = function(e) {
      cli::cli_alert_danger("Cohort generation failed: {e$message}")
      stop("Cannot proceed without cohorts")
    })
  }

  fullTaskFilePath <- fs::path("analysis/tasks", taskFile) |>
    fs::path_expand()

  # Verify task file exists
  if (!file.exists(fullTaskFilePath)) {
    cli::cli_alert_danger("Task file not found: {fs::path_rel(fullTaskFilePath)}")
    stop("Task file does not exist")
  }

  # Validate study task structure
  tryCatch({
    validateStudyTask(fullTaskFilePath)
  }, error = function(e) {
    cli::cli_alert_danger("Task validation failed: {e$message}")
    stop("Invalid task structure - cannot execute")
  })

  # Read and process the task file
  tryCatch({
    rLines <- readr::read_file(fullTaskFilePath) |>
      glue::glue(.open = "!||", .close = "||!")
  }, error = function(e) {
    cli::cli_alert_danger("Failed to read task file: {e$message}")
    stop("Error reading task file")
  })

  # Parse the expressions
  tryCatch({
    exprs <- rlang::parse_exprs(rLines)
  }, error = function(e) {
    cli::cli_alert_danger("Failed to parse task file: {e$message}")
    stop("Error parsing task expressions")
  })

  # Execute each expression with error handling
  res <- NULL
  for (ex in seq_along(exprs)) {
    tryCatch({
      res <- eval(exprs[[ex]], env)
    }, error = function(e) {
      cli::cli_alert_danger("Error executing expression {ex} in task {taskFile}:")
      cli::cli_alert_danger("{e$message}")
      stop(glue::glue("Task execution failed at expression {ex}"))
    })
  }

  cli::cli_alert_success("Task {taskFile} completed successfully")
  invisible(res)
}

#' @title Function to execute all study task in analysis folder on set of configBlock
#' @param configBlock name of one or multiple configBlock to use in the execution
#' @param pipelineVersion the version of the pipeline to use in the execution. This is used to set the output folder for the task results.
#' @param env the execution environment
#' @export
execStudyPipeline <- function(configBlock, pipelineVersion, env = rlang::caller_env()) {

  taskFilesToRun <- fs::dir_ls("analysis/tasks", type = "file") |>
    basename()

  for (db in seq_along(configBlock)) {
    for (task in seq_along(taskFilesToRun)) {
      execStudyTask(
        taskFile = taskFilesToRun[task],
        configBlock = configBlock[db],
        env = env
      )
    }
  }

  invisible(taskFilesToRun)

}


addMainFile <- function(repoName, repoFolder, toolType, configBlocks, studyName) {
  repoPath <- fs::path(repoFolder, repoName) |>
    fs::path_expand()

  if (toolType == "dbms") {
    configBlocks <- paste0(configBlocks, collapse = "\", \"")

    mainR <- fs::path_package("picard", "templates/main.R") |>
      readr::read_file() |>
      glue::glue()

  }

  if (toolType == "external") {
    mainR <- fs::path_package("picard", "templates/main_simple.R") |>
      readr::read_file() |>
      glue::glue()
  }

  actionItem(glue::glue_col("Initialize Main Exec File: {green {fs::path(repoPath, 'main.R')}}"))
  readr::write_file(
    x = mainR,
    file = fs::path(repoPath, "main.R")
  )
  invisible(mainR)

}
