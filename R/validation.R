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

#' @importFrom yaml read_yaml
#' @title Validate config.yml File Structure
#' @description Validates that a config.yml file has the correct structure, required fields,
#'   and that sensitive credentials (user, password, connectionString) use !expr instead of
#'   plain text values. Checks each config block for consistency and DBMS-specific requirements.
#' @param configFilePath Character. Path to the config.yml file. If NULL, looks for config.yml
#'   in the current working directory.
#' @return Logical. Returns TRUE if valid. Stops with informative error messages if validation fails.
#' @details
#' A valid config.yml must have:
#' - Top-level version field (e.g., "version: 1.0.0")
#' - Top-level projectName field (character)
#' - One or more config blocks with required fields:
#'   - dbms: Database management system type (snowflake, postgresql, sql server, etc.)
#'   - user: !expr expression for credentials
#'   - password: !expr expression for credentials
#'   - cdmDatabaseSchema: OMOP CDM schema name
#'   - workDatabaseSchema: Schema for writing results
#'   - cohortTable: Name of cohort table
#'   - databaseName: Human-readable database name
#'
#' DBMS-specific requirements:
#' - Snowflake: Must have connectionString (!expr)
#' - PostgreSQL/SQL Server: Must have server and port
#'
#' Security check:
#' - user, password, connectionString fields MUST use !expr (not plain values)
#'
#' @export
validateConfigYaml <- function(configFilePath = NULL) {
  
  if (is.null(configFilePath)) {
    configFilePath <- "config.yml"
  }
  
  # Check file exists
  if (!file.exists(configFilePath)) {
    cli::cli_alert_danger("Config file not found: {fs::path_rel(configFilePath)}")
    stop("config.yml does not exist")
  }
  
  cli::cli_alert_info("Validating config file: {fs::path_rel(configFilePath)}")
  
  # Read raw file content for text-based validation (to check for !expr)
  tryCatch({
    rawContent <- readr::read_file(configFilePath)
  }, error = function(e) {
    cli::cli_alert_danger("Failed to read config file: {e$message}")
    stop("Error reading config.yml")
  })
  
  # Parse YAML
  configList <- tryCatch({
    yaml::read_yaml(configFilePath)
  }, error = function(e) {
    cli::cli_alert_danger("Failed to parse YAML: {e$message}")
    stop("config.yml is not valid YAML")
  })
  
  # Check for top-level required fields
  topLevelRequired <- c("version", "projectName")
  missingTopLevel <- setdiff(topLevelRequired, names(configList))
  
  if (length(missingTopLevel) > 0) {
    cli::cli_alert_danger("Missing top-level fields in config.yml:")
    cli::cli_bullets(setNames(missingTopLevel, "x"))
    stop("config.yml is missing required top-level fields")
  }
  
  # Validate version format (MAJOR.MINOR.PATCH)
  version <- configList$version
  if (!grepl("^\\d+\\.\\d+\\.\\d+$", as.character(version))) {
    cli::cli_alert_danger("Invalid version format: {version}")
    cli::cli_bullets(c(i = "Use semantic versioning format: MAJOR.MINOR.PATCH (e.g., 1.0.0)"))
    stop("Invalid version format in config.yml")
  }
  
  # Check that projectName is a string
  if (!is.character(configList$projectName)) {
    cli::cli_alert_danger("projectName must be a character string")
    stop("Invalid projectName type")
  }
  
  # Identify config blocks (any top-level key that's a list and not a reserved field)
  reservedFields <- c("version", "projectName", "default")
  configBlockNames <- setdiff(names(configList), reservedFields)
  
  if (length(configBlockNames) == 0) {
    cli::cli_alert_danger("No database config blocks found in config.yml")
    cli::cli_bullets(c(i = "Define at least one config block (e.g., database1:, optum_dod:, etc.)"))
    stop("config.yml has no database configuration blocks")
  }
  
  # Check for !expr usage in raw file (text-based check)
  credentialFields <- c("user", "password", "connectionString")
  
  # Pattern to find credential assignments
  credentialPattern <- paste0("(", paste(credentialFields, collapse = "|"), ")\\s*:\\s*([^\\n]+)")
  credMatches <- gregexpr(credentialPattern, rawContent, perl = TRUE)
  
  if (length(unlist(credMatches)) > 0) {
    # Extract matched lines
    credentialLines <- regmatches(rawContent, credMatches)
    
    for (line in credentialLines) {
      if (!grepl("!expr", line, fixed = TRUE)) {
        cli::cli_alert_warning("Found credential field without !expr:")
        cli::cli_bullets(c(
          x = line,
          i = "Credentials must use !expr (e.g., {.code user: !expr Sys.getenv('dbUser')})"
        ))
        stop("Credential fields must use !expr expressions")
      }
    }
  }
  
  # Validate each config block
  blockErrors <- list()
  
  for (blockName in configBlockNames) {
    blockConfig <- configList[[blockName]]
    
    # Ensure it's a list
    if (!is.list(blockConfig)) {
      blockErrors[[blockName]] <- "Config block must be a YAML object/dictionary"
      next
    }
    
    # Check required block fields
    blockRequired <- c("dbms", "user", "password", "cdmDatabaseSchema", 
                       "workDatabaseSchema", "cohortTable", "databaseName")
    missingFields <- setdiff(blockRequired, names(blockConfig))
    
    if (length(missingFields) > 0) {
      blockErrors[[blockName]] <- paste(
        "Missing required fields:",
        paste(missingFields, collapse = ", ")
      )
      next
    }
    
    # Validate DBMS type
    dbms <- tolower(as.character(blockConfig$dbms))
    validDbms <- c("snowflake", "postgresql", "sql server", "mysql", "redshift", "oracle")
    
    if (!dbms %in% validDbms) {
      blockErrors[[blockName]] <- paste(
        "Unknown DBMS type: '", blockConfig$dbms, "'.",
        "Valid options:", paste(validDbms, collapse = ", ")
      )
      next
    }
    
    # DBMS-specific validation
    if (dbms == "snowflake") {
      if (is.null(blockConfig$connectionString)) {
        blockErrors[[blockName]] <- "Snowflake config must include 'connectionString' field"
        next
      }
    } else {
      # PostgreSQL, SQL Server, etc. require server and port
      if (is.null(blockConfig$server)) {
        blockErrors[[blockName]] <- paste(
          dbms, "config must include 'server' field"
        )
        next
      }
      if (is.null(blockConfig$port)) {
        blockErrors[[blockName]] <- paste(
          dbms, "config must include 'port' field"
        )
        next
      }
    }
    
    # Validate that schema names are non-empty strings
    schemaFields <- c("cdmDatabaseSchema", "workDatabaseSchema", "tempEmulationSchema")
    for (schemaField in schemaFields[schemaFields %in% names(blockConfig)]) {
      schemaValue <- blockConfig[[schemaField]]
      if (!is.character(schemaValue) || schemaValue == "") {
        blockErrors[[blockName]] <- paste(schemaField, "must be a non-empty string")
        next
      }
    }
    
    # Validate cohortTable and databaseName are non-empty strings
    if (!is.character(blockConfig$cohortTable) || blockConfig$cohortTable == "") {
      blockErrors[[blockName]] <- "cohortTable must be a non-empty string"
      next
    }
    
    if (!is.character(blockConfig$databaseName) || blockConfig$databaseName == "") {
      blockErrors[[blockName]] <- "databaseName must be a non-empty string"
      next
    }
  }
  
  # Report any block errors
  if (length(blockErrors) > 0) {
    cli::cli_alert_danger("Validation failed for {length(blockErrors)} config block(s):")
    for (blockName in names(blockErrors)) {
      cli::cli_alert_danger("Block '{blockName}': {blockErrors[[blockName]]}")
    }
    stop("config.yml has validation errors")
  }
  
  cli::cli_alert_success("Config validation successful!")
  cli::cli_bullets(c(
    "v" = "{length(configBlockNames)} config block(s) validated",
    "v" = "All required fields present",
    "v" = "Credentials properly use !expr",
    "v" = "DBMS types valid and properly configured"
  ))
  
  invisible(TRUE)
}
