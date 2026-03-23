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