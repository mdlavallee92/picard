#' @title Set Ulysses Contributor
#' @importFrom rlang "%||%"
#' @param name the name of the contributor as a character string
#' @param email the email of the contributor as a character string
#' @param role the role of the contirbutor as a character string
#' @returns A ContributorLine R6 class with the contributor info
#' @export
setContributor <- function(name, email, role) {
  ContributorLine$new(name = name, email = email, role = role)
}

#' @title Make Study Meta for Ulysses
#' @param studyTitle the title of the study as a character string
#' @param therapeuticArea the TA as a character string
#' @param studyType the study type (typically characterization)
#' @param studyLinks a list of study links
#' @param studyTags a list of study tags
#' @returns A StudyMeta R6 class with the study meta
#' @export
makeStudyMeta <- function(studyTitle,
                          therapeuticArea,
                          studyType,
                          contributors,
                          studyLinks = NULL,
                          studyTags = NULL) {
  StudyMeta$new(
    studyTitle = studyTitle,
    therapeuticArea = therapeuticArea,
    studyType = studyType,
    contributors = contributors,
    studyLinks = studyLinks,
    studyTags = studyTags
  )
}
#' @title set the config block for a database
#' @param configBlockName the name of the config block
#' @param cdmDatabaseSchema the cdmDatabaseSchema specified as a character string
#' @param cohortTable a character string specifying the way you want to name your cohort table
#' @param databaseName the name of the database, typically uses the db name and id. For example optum_dod_202501
#' @param databaseLabel the labelling name of the database, typically a common name for a db. For example Optum DOD
#' @returns A StudyMeta R6 class with the study meta
#' @export
setDbConfigBlock <- function(configBlockName,
                             cdmDatabaseSchema,
                             cohortTable,
                             databaseName = NULL,
                             databaseLabel = NULL) {
  DbConfigBlock$new(
    configBlockName = configBlockName,
    cdmDatabaseSchema = cdmDatabaseSchema,
    cohortTable = cohortTable,
    databaseName = databaseName,
    databaseLabel = databaseLabel
  )
}

#' @title set the execOptions as placeholder.
#' @description use this function if there is not a dbms connection for the study such as using a proprietary tool for the analysis
#' @returns A ExecOptions R6 class with the execOptions
#' @export
placeHolderExecOptions <- function() {
  ExecOptions$new()
}


#' @title Make ExecOptions for Ulysses
#' @param dbms specify the dbms used in the exec options
#' @param workDatabaseSchema the name of the workDatabaseSchema as a character string, location in DB where user has write access
#' @param tempEmulationSchema he name of the tempEmulationSchema as a character strings
#' @param dbConnectionBlocks a list of DbConfigBlock R6 classes specifying the dbs to connect
#' @returns A ExecOptions R6 class with the execOptions
#' @export
makeExecOptions <- function(dbms,
                            workDatabaseSchema,
                            tempEmulationSchema = NULL,
                            dbConnectionBlocks) {
  ExecOptions$new(
    dbms = dbms,
    workDatabaseSchema = workDatabaseSchema,
    tempEmulationSchema = tempEmulationSchema,
    dbConnectionBlocks = dbConnectionBlocks
  )
}


#' @title Make Ulysses Study Settings
#' @param repoName the name of repo as a character string
#' @param repoFolder the folder path where the repo is stored in local as a character string
#' @param studyMeta a StudyMeta R6 class with the details describing the study
#' @param execOptions a ExecOptions R6 class with the execution details needed for the study
#' @param gitRemote a remote url used to clone and set remote git
#' @param renvLock file path to a renvLock file
#' @returns A UlyssesStudy R6 class with the ulysses study details to make
#' @export
makeUlyssesStudySettings <- function(repoName,
                                     repoFolder,
                                     toolType = c("dbms", "external"),
                                     studyMeta,
                                     execOptions = NULL,
                                     gitRemote = NULL,
                                     renvLock = NULL) {
  UlyssesStudy$new(
    repoName = repoName,
    repoFolder = repoFolder,
    toolType = toolType,
    studyMeta = studyMeta,
    execOptions = execOptions,
    gitRemote = gitRemote,
    renvLock = renvLock
  )
}

# Users can call initUlyssesRepo directly on UlyssesStudy object:
# ulyssesStudySettings$initUlyssesRepo(verbose = TRUE, openProject = FALSE)


#' @title
#' Create an ExecutionSettings object and set its attributes
#'
#' @param connectionDetails A DatabaseConnector connectionDetails object (optional if connection is specified)
#' @param connection A DatabaseConnector connection object (optional if connectionDetails is specified)
#' @param cdmDatabaseSchema The schema of the OMOP CDM database
#' @param workDatabaseSchema The schema to which results will be written
#' @param tempEmulationSchema Some database platforms like Oracle and Snowflake do not truly support temp tables. To emulate temp tables, provide a schema with write privileges where temp tables can be created.
#' @param cohortTable The name of the table where the cohort(s) are stored
#' @param databaseName A human-readable name for the OMOP CDM database
#'
#' @return An ExecutionSettings object
#' @export
createExecutionSettings <- function(connectionDetails,
                                    connection = NULL,
                                    cdmDatabaseSchema,
                                    workDatabaseSchema,
                                    tempEmulationSchema,
                                    cohortTable,
                                    databaseName) {
  ExecutionSettings$new(
    connectionDetails = connectionDetails,
    connection = connection,
    cdmDatabaseSchema = cdmDatabaseSchema,
    workDatabaseSchema = workDatabaseSchema,
    tempEmulationSchema = tempEmulationSchema,
    cohortTable = cohortTable,
    databaseName = databaseName
  )
}

#' @title Create ExecutionSettings from Config Block
#' @description Load database connection details and execution parameters from a config.yml file
#'   and create both connectionDetails and ExecutionSettings objects. Supports multiple DBMS types
#'   including Snowflake with connectionString, PostgreSQL with server/port, and others.
#' @param configBlock Character. The name of the config block to load (e.g., "optum_dod")
#' @param configFilePath Character. Path to the config.yml file. If NULL, looks for config.yml in the current directory.
#' @param cdmDatabaseSchema Character. The schema containing the OMOP CDM (overrides config value if provided)
#' @param workDatabaseSchema Character. The schema for writing results (overrides config value if provided)
#' @param tempEmulationSchema Character. Schema for temp table emulation (overrides config value if provided)
#' @param cohortTable Character. The name of the cohort table (overrides config value if provided)
#' @param databaseName Character. Human-readable database name (overrides config value if provided)
#'
#' @details
#' The config.yml file supports multiple DBMS connection styles:
#'
#' For Snowflake (using connectionString):
#' \preformatted{
#' optum_dod:
#'   dbms: snowflake
#'   connectionString: !expr Sys.getenv('dbConnectionString')
#'   user: !expr Sys.getenv('dbUser')
#'   password: !expr Sys.getenv('dbPassword')
#'   cdmDatabaseSchema: my_schema
#'   workDatabaseSchema: results_schema
#'   tempEmulationSchema: temp_schema
#'   cohortTable: cohort
#'   databaseName: Optum DOD
#' }
#'
#' For PostgreSQL (using server/port):
#' \preformatted{
#' database1:
#'   dbms: postgresql
#'   server: localhost
#'   port: 5432
#'   user: dbuser
#'   password: dbpass
#'   cdmDatabaseSchema: public
#'   workDatabaseSchema: results
#'   cohortTable: cohort
#'   databaseName: My Database
#' }
#'
#' The config package automatically evaluates !expr blocks using Sys.getenv() for environment variables.
#'
#' @return An ExecutionSettings object with populated connectionDetails
#' @export
createExecutionSettingsFromConfig <- function(
    configBlock,
    configFilePath = here::here("config.yml"),
    cdmDatabaseSchema = NULL,
    workDatabaseSchema = NULL,
    tempEmulationSchema = NULL,
    cohortTable = NULL,
    databaseName = NULL) {

  if (!file.exists(configFilePath)) {
    stop("Config file not found: ", configFilePath)
  }

  # Get the config block
  blockConfig <- tryCatch(
    config::get(config = configBlock, file = configFilePath),
    error = function(e) {
      stop("Config block '", configBlock, "' not found in ", configFilePath, "\n",
           "Error: ", e$message)
    }
  )

  # Extract database connection parameters
  dbms <- blockConfig$dbms
  if (is.null(dbms)) {
    stop("'dbms' not found in config block '", configBlock, "'")
  }

  # Prepare connectionDetails based on DBMS type
  connDetailsArgs <- list(dbms = dbms)

  # Handle Snowflake-specific connection (uses connectionString)
  if (tolower(dbms) == "snowflake") {
    connectionString <- blockConfig$connectionString
    if (is.null(connectionString)) {
      stop("'connectionString' not found in Snowflake config block '", configBlock, "'")
    }
    connDetailsArgs$connectionString <- connectionString
  } else {
    # Handle other DBMS types (server/port style)
    server <- blockConfig$server %||% NA
    port <- blockConfig$port %||% NA

    if (!is.na(server)) {
      connDetailsArgs$server <- server
    }
    if (!is.na(port)) {
      connDetailsArgs$port <- port
    }
  }

  # Add credentials (common to all DBMS)
  user <- blockConfig$user %||% NA
  password <- blockConfig$password %||% NA

  if (!is.na(user)) {
    connDetailsArgs$user <- user
  }
  if (!is.na(password)) {
    connDetailsArgs$password <- password
  }

  # Add optional extra settings
  extraSettings <- blockConfig$extraSettings %||% NULL
  if (!is.null(extraSettings)) {
    connDetailsArgs$extraSettings <- extraSettings
  }

  # Create connectionDetails using DatabaseConnector
  connectionDetails <- tryCatch(
    do.call(DatabaseConnector::createConnectionDetails, connDetailsArgs),
    error = function(e) {
      stop("Failed to create connectionDetails for '", configBlock, "': ", e$message)
    }
  )

  # Override with explicit parameters if provided, otherwise use config values
  if (is.null(cdmDatabaseSchema)) {
    cdmDatabaseSchema <- blockConfig$cdmDatabaseSchema %||% NA
  }
  if (is.null(workDatabaseSchema)) {
    workDatabaseSchema <- blockConfig$workDatabaseSchema %||% NA
  }
  if (is.null(tempEmulationSchema)) {
    tempEmulationSchema <- blockConfig$tempEmulationSchema %||% NA
  }
  if (is.null(cohortTable)) {
    cohortTable <- blockConfig$cohortTable %||% NA
  }
  if (is.null(databaseName)) {
    databaseName <- blockConfig$databaseName %||% NA
  }

  # Validate required fields
  if (is.na(cdmDatabaseSchema)) {
    stop("'cdmDatabaseSchema' not specified in config or as parameter")
  }
  if (is.na(workDatabaseSchema)) {
    stop("'workDatabaseSchema' not specified in config or as parameter")
  }
  if (is.na(cohortTable)) {
    stop("'cohortTable' not specified in config or as parameter")
  }

  # Create and return ExecutionSettings
  ExecutionSettings$new(
    connectionDetails = connectionDetails,
    connection = NULL,
    cdmDatabaseSchema = cdmDatabaseSchema,
    workDatabaseSchema = workDatabaseSchema,
    tempEmulationSchema = if (is.na(tempEmulationSchema)) NULL else tempEmulationSchema,
    cohortTable = cohortTable,
    databaseName = databaseName
  )
}

#' @title Set Output Folder for Task
#' @description Create an output folder for a specific task within the results directory, organized by database name and pipelineVersion.
#' @param executionSettings An ExecutionSettings object containing the databaseName attribute
#' @param pipelineVersion A character string specifying the pipelineVersion of the analysis (e.g., "v1", "v2")
#' @param taskName The name of the task for which to create the output folder
#' @param execPath The base path for results (default is "exec/results" within the project)
#' @return The path to the created output folder
#' @export
setOutputFolder <- function(executionSettings, pipelineVersion, taskName, execPath = here::here("exec/results")) {
  dbNameSnake <- snakecase::to_snake_case(executionSettings$databaseName)
  outputFolder <- fs::path(execPath, dbNameSnake, pipelineVersion, taskName) |>
    fs::dir_create()
  return(outputFolder)
}

#' @title Function initializing an R file for an analysis task
#' @param nameOfTask The name of the analysis task script
#' @param author the name of the person authoring the file. Defaults to template text if NULL
#' @param description a description of the analysis task. Defaults to template text if NULL
#' @param projectPath the path to the project
#' @param openFile toggle on whether the file should be opened
#' @export
makeTaskFile <- function(
    nameOfTask,
    author = NULL,
    description = NULL,
    projectPath = here::here(),
    openFile = TRUE) {

  analysisFolderPath <- fs::path(projectPath, "analysis/tasks")
  dirF <- fs::dir_ls(path = analysisFolderPath, type = "file")
  nFiles <- length(dirF) + 1
  numLead <- stringr::str_pad(nFiles, width = 2, side = "left", pad = "0")
  nameOfTask <- snakecase::to_snake_case(nameOfTask)
  newName <- glue::glue("{numLead}_{nameOfTask}")


  # glue items
  taskName <- glue::glue("{newName}.R")
  studyName <- config::get("projectName", file = fs::path(projectPath, "config.yml"))
  if (is.null(author)) {
    author <- "ADD AUTHOR NAME HERE"
  }
  if (is.null(description)) {
    description <- "The purpose of this script is to....."
  }

  taskTemplate <- fs::path_package(
    package = "picard",
    "templates/task.R"
  ) |>
    readr::read_file() |>
    glue::glue(
      taskName = newName,
      author = author,
      description = description,
      studyName = studyName
    )


  txt <- glue::glue_col("Write {cyan {taskName}} to {yellow {analysisFolderPath}}")
  cli::cat_bullet(
    txt,
    bullet = "tick",
    bullet_col = "green"
  )

  # write the new file to analysis/task
  readr::write_file(
    x = taskTemplate,
    file = fs::path(analysisFolderPath, newName, ext = "R")
  )

  if (openFile) {
    rstudioapi::navigateToFile(file = fs::path(analysisFolderPath, newName, ext = "R"))
    cli::cat_bullet(
      "Navigating to new task file",
      bullet = "info",
      bullet_col = "blue"
    )
  }

  invisible(taskTemplate)

}
