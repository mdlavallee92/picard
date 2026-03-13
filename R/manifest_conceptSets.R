
#' Load Concept Set Manifest
#'
#' Loads or creates a concept set manifest from CIRCE JSON files located in the
#' inputs/conceptSets/json folder. The manifest is stored in an SQLite database
#' for efficient querying and metadata persistence.
#'
#' @param executionSettings ExecutionSettings object. Optional. Used for vocabulary access
#'   when working with concept sets.
#' @param conceptSetsFolderPath Character. Path to the conceptSets folder containing the manifest
#'   database. Defaults to "inputs/conceptSets".
#'
#' @return ConceptSetManifest object containing all loaded concept sets with metadata.
#'
#' @details
#' **Workflow:**
#' 1. Checks if conceptSetManifest.sqlite database exists
#' 2. If it exists, loads concept set entries from the json/ directory using cached metadata
#' 3. If not, scans the json/ directory for CIRCE JSON files
#' 4. Creates ConceptSetDef objects for each JSON file
#' 5. Enriches metadata from conceptSetsLoad.csv if available
#' 6. Returns a ConceptSetManifest object
#'
#' **Metadata CSV Format:**
#' The conceptSetsLoad.csv file (optional) should contain:
#' - `file_name`: Relative path to JSON file (e.g., "conceptSet1.json")
#' - `label`: Display name for the concept set
#' - `atlasId`: ATLAS concept set ID
#' - `domain`: OMOP domain classification
#' - `sourceCode`: Whether the concept set represents source codes
#'
#' **Post-Load:**
#' After loading, use manifest methods to query concept sets:
#' - `getConceptSetById(id)` - Get by database ID
#' - `getConceptSetsByTag(key, value)` - Get by metadata tag
#' - `grabConceptSetById(id)` - Get ConceptSetDef object
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Load concept set manifest
#'   settings <- createExecutionSettings(
#'     connectionString = "Server=localhost;Database=mydb"
#'   )
#'   manifest <- loadConceptSetManifest(settings)
#'
#'   # Query the manifest
#'   cs1 <- manifest$getConceptSetById(1)
#'   cs_by_tag <- manifest$getConceptSetsByTag("domain", "drug_exposure")
#' }
#'
#'
loadConceptSetManifest <- function(executionSettings = NULL,
                                   conceptSetsFolderPath = here::here("inputs/conceptSets")) {
  checkmate::assert_class(executionSettings, "ExecutionSettings", null.ok = TRUE)
  dbPath <- fs::path(conceptSetsFolderPath, "conceptSetManifest.sqlite")
  concept_set_entries <- list()

  # Check if database already exists and has entries
  if (file.exists(dbPath)) {
    conn <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
    on.exit(DBI::dbDisconnect(conn))

    # Query existing concept sets from database
    existing_concept_sets <- DBI::dbGetQuery(
      conn,
      "SELECT id, label, tags, sourceCode, domain, filePath, hash FROM concept_set_manifest"
    )

    # Only load from manifest if it has entries
    if (nrow(existing_concept_sets) > 0) {
      cli::cli_alert_info("Loading concept sets from existing manifest: {dbPath}")

      # Process each concept set from database
      for (i in seq_len(nrow(existing_concept_sets))) {
        record <- existing_concept_sets[i, ]
        label <- record$label
        source_code <- record$sourceCode
        domain <- record$domain
        file_path <- record$filePath
        stored_hash <- record$hash
        tags_string <- record$tags

        # Check if file still exists
        if (!file.exists(file_path)) {
          cli::cli_alert_danger("Concept set file not found: {record$label} ({file_path})")
          next
        }

        tryCatch({
          # Create ConceptSetDef from file (this computes current hash)
          concept_set_def <- ConceptSetDef$new(
            label = label,
            filePath = file_path,
            sourceCode = source_code,
            domain = domain
        )

          # Backfill tags from database
          if (!is.na(tags_string) && tags_string != "") {
            parsed_tags <- parseTagsString(tags_string)
            concept_set_def$tags <- parsed_tags
          }

          concept_set_entries[[length(concept_set_entries) + 1]] <- concept_set_def
        }, error = function(e) {
          cli::cli_alert_danger("Error loading concept set {record$label}: {e$message}")
        })
      }

      if (length(concept_set_entries) > 0) {
        cli::cli_alert_success("Loaded {length(concept_set_entries)} concept sets from manifest")
        # Successfully loaded from manifest, proceed to create and return
      } else {
        # Database had entries but none could be loaded, fall through to scan directories
        cli::cli_alert_warning("No valid concept sets could be loaded from manifest. Scanning directories...")
        concept_set_entries <- list()  # Reset to empty for directory scan
      }
    } else {
      # Manifest exists but is empty, scan directories
      cli::cli_alert_warning("Manifest exists but contains no concept set entries. Scanning directories...")
    }
  }

  # If no concept sets loaded from manifest (or manifest didn't exist), scan directories
  if (length(concept_set_entries) == 0) {
    cli::cli_alert_info("Scanning concept set directories...")

    # Define directory to search
    json_dir <- fs::path(conceptSetsFolderPath, "json")

    # Process JSON directory if it exists
    if (dir.exists(json_dir)) {
      json_files <- list.files(json_dir, pattern = "\\.json$", full.names = TRUE, recursive = TRUE)

      for (file_path in json_files) {
        label <- tools::file_path_sans_ext(basename(file_path))
        tryCatch({
          concept_set_def <- ConceptSetDef$new(
            label = label,
            filePath = file_path,
            domain = "temp"  # Default domain, will be updated if conceptSetsLoad.csv has info
        )
          concept_set_entries[[length(concept_set_entries) + 1]] <- concept_set_def
          cli::cli_alert_success("Loaded concept set: {label}")
        }, error = function(e) {
          cli::cli_alert_danger("Error loading concept set {label}: {e$message}")
        })
      }
    }

    if (length(concept_set_entries) == 0) {
      stop("No concept set files found in conceptSets/json directory")
    }

    cli::cli_alert_success("Found {length(concept_set_entries)} total concept sets")
  }

  # Check for conceptSetsLoad.csv file to enrich entries with tags and labels
  concept_sets_load_path <- fs::path(conceptSetsFolderPath, "conceptSetsLoad.csv")
  if (file.exists(concept_sets_load_path)) {
    cli::cli_alert_info("Found conceptSetsLoad.csv. Enriching entries with load metadata...")

    tryCatch({
      concept_sets_load <- readr::read_csv(concept_sets_load_path, show_col_types = FALSE)

      # Validate required columns (label is optional)
      required_cols <- c("file_name", "atlasId", "category","domain", "sourceCode")
      missing_cols <- setdiff(required_cols, names(concept_sets_load))

      if (length(missing_cols) == 0) {
        # Process each concept set entry to find matching load record
        tags_added <- 0
        labels_updated <- 0
        for (i in seq_along(concept_set_entries)) {
          entry <- concept_set_entries[[i]]
          entry_filepath_rel <- fs::path_rel(entry$getFilePath())

          # Find matching record in conceptSetsLoad by file_name
          matching_idx <- which(entry_filepath_rel == concept_sets_load$file_name)

          if (length(matching_idx) > 0) {
            load_record <- concept_sets_load[matching_idx[1], ]

            # Update label if provided in conceptSetsLoad.csv
            if ("label" %in% names(concept_sets_load) && !is.na(load_record$label)) {
              entry$label <- as.character(load_record$label)
              labels_updated <- labels_updated + 1
            }

            # Add tags from load record
            entry_tags <- list()
            if (!is.na(load_record$atlasId)) {
              entry_tags[["atlasId"]] <- as.character(load_record$atlasId)
            }
            if (!is.na(load_record$domain)) {
              entry_tags[["domain"]] <- as.character(load_record$domain)
            }
            if (!is.na(load_record$category)) {
              entry_tags[["category"]] <- as.character(load_record$category)
            }
            if (!is.na(load_record$sourceCode)) {
              entry_tags[["sourceCode"]] <- as.character(load_record$sourceCode)
            }

            if (length(entry_tags) > 0) {
              entry$tags <- entry_tags
              tags_added <- tags_added + 1
              cli::cli_alert_success("Added metadata to concept set: {entry$label}")
            }
          }
        }

        cli::cli_alert_success("Updated {labels_updated} labels and added tags to {tags_added} concept set entries from conceptSetsLoad.csv")
      } else {
        cli::cli_alert_warning("conceptSetsLoad.csv is missing required columns: {paste(missing_cols, collapse = ', ')}")
      }
    }, error = function(e) {
      cli::cli_alert_danger("Error reading conceptSetsLoad.csv: {e$message}")
    })
  }

  # Create and return the ConceptSetManifest
  manifest <- ConceptSetManifest$new(
    conceptSetEntries = concept_set_entries,
    executionSettings = executionSettings,
    dbPath = dbPath
  )

  return(manifest)
}


#' Reset Concept Set Manifest Database
#'
#' Deletes the conceptSetManifest.sqlite database file. Use this function when you need
#' to reset the manifest and rebuild it from the available concept set files.
#'
#' @param conceptSetsFolderPath Character. Path to the conceptSets folder containing the manifest
#'   database. Defaults to "inputs/conceptSets".
#'
#' @return Invisibly returns NULL. Deletes the manifest file and prints status messages.
#'
#' @details
#' This function is useful for:
#' - Starting fresh with a new set of concept sets
#' - Clearing cached manifest data
#' - Resolving manifest corruption issues
#'
#' After resetting, call [loadConceptSetManifest()] to rebuild the manifest from
#' the available concept set files in the json/ subdirectory.
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Reset the manifest
#'   resetConceptSetManifest()
#'
#'   # Rebuild it from concept set files
#'   settings <- ExecutionSettings$new(...)
#'   manifest <- loadConceptSetManifest(settings)
#' }
#'
resetConceptSetManifest <- function(conceptSetsFolderPath = here::here("inputs/conceptSets")) {
  dbPath <- fs::path(conceptSetsFolderPath, "conceptSetManifest.sqlite")

  if (file.exists(dbPath)) {
    file.remove(dbPath)
    cli::cli_alert_success("Concept set manifest database deleted: {fs::path_rel(dbPath)}")
    cli::cli_alert_info("To rebuild the manifest, call loadConceptSetManifest() with your ExecutionSettings")
  } else {
    cli::cli_alert_warning("Concept set manifest database not found at: {fs::path_rel(dbPath)}")
  }

  invisible(NULL)
}


#' Launch Interactive Concept Set Load Editor
#'
#' Opens an interactive Shiny application for creating, viewing and editing the concept
#' sets load metadata file (conceptSetsLoad.csv). This allows you to add, remove,
#' and modify concept set metadata including labels, tags, domain, and ATLAS IDs
#' without manually editing the CSV file.
#'
#'
#' @param conceptSetsFolderPath Character. Path to conceptSets folder where conceptSetsLoad.csv
#'   will be saved. Defaults to "inputs/conceptSets".
#'
#' @return Invisibly launches a Shiny app. Saves conceptSetsLoad.csv when the user user clicks "Save".
#'
#' @details
#' **Features:**
#' - View existing concept sets in a data table
#' - Edit cells directly in the table
#' - Add new concept sets rows with form inputs
#' - Delete selected rows
#' - Save to conceptSetsLoad.csv
#' - Input validation for required fields
#'
#' **Table Columns:**
#' - `atlasId`: ATLAS cohort definition ID (numeric)
#' - `label`: Cohort name/label (character) - editing updates file_name automatically
#' - `category`: Broad category (character)
#' - `subCategory`: Sub-category (character)
#' - `sourceCode`: Whether this concept set represents source codes (TRUE/FALSE)
#' - `domain`: OMOP domain (drug_exposure, condition_occurrence, measurement, procedure)
#' - `file_name`: Auto-generated as `json/{label}.json` (read-only)
#'
#' **Workflow:**
#' 1. Call this function to launch the editor app
#' 2. Add/edit concept sets as needed
#' 3. Click "Save Concept Set Load File" to save to inputs/conceptSets/conceptSetsLoad.csv
#' 4. Use [importAtlasConceptSets()] to import conceptSets from ATLAS
#' 5. Use [loadConceptSetManifest()] to load the imported conceptSets
#' @export
#'
#' @examples
#' \dontrun{
#'   # Launch the concept set load editor
#'   launchConceptSetsLoadEditor()
#' }
#'
launchConceptSetsLoadEditor <- function(conceptSetsFolderPath = here::here("inputs/conceptSets")) {
  # Check if Shiny is installed
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("The 'shiny' package is required to use this function. Install it with: install.packages('shiny')")
  }
  if (!requireNamespace("DT", quietly = TRUE)) {
    stop("The 'DT' package is required to use this function. Install it with: install.packages('DT')")
  }

  # Try to load existing conceptSetsLoad.csv
  existing_load <- NULL
  load_path <- fs::path(conceptSetsFolderPath, "conceptSetsLoad.csv")
  if (file.exists(load_path)) {
    existing_load <- readr::read_csv(load_path, show_col_types = FALSE)
    
    # Ensure file_name column exists; generate if missing
    if (!"file_name" %in% names(existing_load)) {
      existing_load$file_name <- fs::path("json", paste0(existing_load$label, ".json"))
    }
    
    # Ensure columns are in the correct order
    existing_load <- existing_load[, c("atlasId", "label", "category", "subCategory", "sourceCode", "domain", "file_name")]
  }

  # Create the Shiny app
  app <- shiny::shinyApp(
    ui = function() {
      shiny::fluidPage(
        shiny::titlePanel("Concept Set Load File Editor"),
        shiny::sidebarLayout(
          shiny::sidebarPanel(
            shiny::h4("Add New Concept Set"),
            shiny::numericInput("atlas_id", "ATLAS ID:", value = NA, min = 1),
            shiny::textInput("label", "Label:", ""),
            shiny::textInput("category", "Category:", ""),
            shiny::textInput("sub_category", "Sub-Category (optional):", ""),
            shiny::textInput("source_code", "Source Code (TRUE/FALSE):", ""),
            shiny::selectInput("domain", "Domain:", choices = c("","drug_exposure", "condition_occurrence", "measurement", "procedure")),
            shiny::actionButton("add_row", "Add Concept Set", class = "btn-primary"),
            shiny::hr(),
            shiny::h4("Actions"),
            shiny::actionButton("delete_rows", "Delete Selected Rows", class = "btn-danger"),
            shiny::hr(),
            shiny::actionButton("save_file", "Save Concept Set Load File", class = "btn-success"),
            shiny::actionButton("cancel", "Cancel", class = "btn-secondary")
          ),
          shiny::mainPanel(
            DT::DTOutput("concept_set_table"),
            shiny::br(),
            shiny::uiOutput("status_message")
          )
        )
      )
    },
    server = function(input, output, session) {
      # Reactive values to store the data
      rv <- shiny::reactiveValues(
        data = if (!is.null(existing_load)) existing_load else data.frame(
          atlasId = integer(),
          label = character(),
          category = character(),
          subCategory = character(),
          sourceCode = logical(),
          domain = character(),
          file_name = character(),
          stringsAsFactors = FALSE
        ),
        message = NULL,
        message_type = NULL
      )

      # Display the data table
      output$concept_set_table <- DT::renderDT({
        DT::datatable(
          rv$data,
          editable = list(target = "cell", disable = list(columns = 5)),
          selection = "multiple",
          rownames = FALSE,
          options = list(pageLength = 10)
        )
      })

      # Handle table edits
      shiny::observeEvent(input$concept_set_table_cell_edit, {
        info <- input$concept_set_table_cell_edit
        rv$data[info$row, info$col] <- info$value

        # Update file_name automatically if label (column 2) changed
        if (info$col == 2) {
          rv$data$file_name[info$row] <- fs::path("json", paste0(info$value, ".json"))
          rv$message <- "Label updated - file_name auto-generated"
          rv$message_type <- "info"
        }
      })

      # Add new concept set
      shiny::observeEvent(input$add_row, {
        # Validate inputs
        if (is.na(input$atlas_id) || input$atlas_id == "") {
          rv$message <- "ATLAS ID is required"
          rv$message_type <- "danger"
          return()
        }
        if (input$label == "") {
          rv$message <- "Label is required"
          rv$message_type <- "danger"
          return()
        }
        if (input$category == "") {
          rv$message <- "Category is required"
          rv$message_type <- "danger"
          return()
        }
        if (input$domain == "") {
          rv$message <- "Domain is required"
          rv$message_type <- "danger"
          return()
        }

        # Add row
        new_row <- data.frame(
          atlasId = as.integer(input$atlas_id),
          label = input$label,
          category = input$category,
          subCategory = if (input$sub_category == "") NA_character_ else input$sub_category,
          sourceCode = input$source_code, 
          domain = input$domain,
          file_name = fs::path("json", paste0(input$label, ".json")),
          stringsAsFactors = FALSE
        )

        rv$data <- rbind(rv$data, new_row)
        rv$message <- paste("Added concept set:", input$label)
        rv$message_type <- "success"

        # Clear inputs
        shiny::updateNumericInput(session, "atlas_id", value = NA)
        shiny::updateTextInput(session, "label", value = "")
        shiny::updateTextInput(session, "category", value = "")
        shiny::updateTextInput(session, "sub_category", value = "")
        shiny::updateTextInput(session, "source_code", value = "")
        shiny::updateSelectInput(session, "domain", selected = "")
      })

      # Delete selected rows
      shiny::observeEvent(input$delete_rows, {
        selected <- input$concept_set_table_rows_selected
        if (length(selected) == 0) {
          rv$message <- "No rows selected"
          rv$message_type <- "warning"
        } else {
          deleted_labels <- rv$data$label[selected]
          rv$data <- rv$data[-selected, ]
          rv$message <- paste("Deleted", length(selected), "concept set(s):", paste(deleted_labels, collapse = ", "))
          rv$message_type <- "info"
        }
      })

      # Save file
      shiny::observeEvent(input$save_file, {
        if (nrow(rv$data) == 0) {
          rv$message <- "Cannot save: No concept sets in table"
          rv$message_type <- "danger"
          return()
        }

        fs::dir_create(conceptSetsFolderPath)
        save_path <- fs::path(conceptSetsFolderPath, "conceptSetsLoad.csv")
        readr::write_csv(rv$data, file = save_path)

        rv$message <- paste("Concept Set Load file saved successfully!\nLocation:", fs::path_rel(save_path))
        rv$message_type <- "success"

        shiny::showNotification(
          paste("Saved", nrow(rv$data), "concept sets to conceptSetLoad.csv"),
          type = "message",
          duration = 3
        )
      })

      # Cancel
      shiny::observeEvent(input$cancel, {
        shiny::stopApp()
      })

      # Display status message
      output$status_message <- shiny::renderUI({
        if (!is.null(rv$message)) {
          class_name <- switch(rv$message_type,
            success = "alert alert-success",
            danger = "alert alert-danger",
            warning = "alert alert-warning",
            info = "alert alert-info"
          )
          shiny::div(class = class_name, HTML(gsub("\n", "<br/>", rv$message)))
        }
      })

      # Stop app on session end
      shiny::onSessionEnded(function() {
        shiny::stopApp()
      })
    }
  )

  shiny::runApp(app)
  invisible(NULL)

}


#' Import CIRCE Concept Sets from ATLAS
#'
#' Imports CIRCE JSON concept set definitions from an ATLAS WebAPI instance and
#' saves them to the inputs/conceptSets/json folder. This function reads a CSV file
#' containing concept set metadata and fetches the actual concept set definitions
#' from ATLAS.
#'
#' @description This function looks for a CSV file called conceptSetsLoad.csv
#'   containing concept set metadata. Must be located in or accessible from the
#'   inputs/conceptSets folder. The CSV must have the following columns:
#'   - `atlasId`: ATLAS concept set definition ID (integer)
#'   - `label`: Concept set name/label (character)
#'   - `domain`: OMOP domain (drug_exposure, condition_occurrence, measurement, procedure)
#'   - `sourceCode`: Whether the concept set represents source codes (logical)
#'
#' The function will read this CSV, fetch the concept set definitions from ATLAS
#' using the provided atlasConnection, extract the CIRCE JSON expressions, and
#' save them to the specified output folder with filenames based on the label.
#' Finally it updates the concept set load CSV with the relative file paths to
#' the saved JSON files.
#'
#' @param conceptSetsFolderPath Character. Path to conceptSets folder in the project.
#'
#' @param atlasConnection An ATLAS connection object (typically from ROhdsiWebApi
#'   package) with a method `getConceptSetDefinition(conceptSetId)` that returns
#'   a list containing an `expression` element with the CIRCE JSON string.
#'
#' @param outputFolder Character. Path to the output folder where concept set JSON
#'   files will be saved. Defaults to inputs/conceptSets/json. Files are saved as
#'   `{label}.json`.
#'
#' @return Invisibly returns the updated concept set load dataframe. Saves CIRCE
#'   JSON files to outputFolder and prints status messages via cli alerts.
#'
#' @details
#' **Workflow:**
#' 1. Reads the concept set load CSV file
#' 2. Validates that all required columns are present
#' 3. For each row with a valid atlasId:
#'    - Fetches the concept set definition from ATLAS WebAPI
#'    - Extracts the CIRCE JSON expression
#'    - Saves to `outputFolder/{label}.json`
#' 4. Skips rows with missing atlasId with a warning
#' 5. Catches and reports errors per concept set without stopping the entire import
#'
#' **Post-Import:**
#' After running this function, use [loadConceptSetManifest()] to load the saved
#' concept set JSON files and build the manifest with metadata.
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Assuming ATLAS connection is set up
#'   importAtlasConceptSets(
#'     conceptSetsFolderPath = here::here("inputs/conceptSets"),
#'     atlasConnection = setAtlasConnection()
#'   )
#'
#'   # Then load the manifest
#'   manifest <- loadConceptSetManifest(
#'     conceptSetsFolderPath = here::here("inputs/conceptSets")
#'   )
#' }
#'
importAtlasConceptSets <- function(conceptSetsFolderPath,
                                    atlasConnection) {
  conceptSetLoadPath <- fs::path(conceptSetsFolderPath, "conceptSetsLoad.csv")

  # Read concept set load CSV file
  if (!file.exists(conceptSetLoadPath)) {
    stop("Concept set load file not found: ", conceptSetLoadPath)
  }

  concept_set_load <- readr::read_csv(conceptSetLoadPath, show_col_types = FALSE)

  # Validate required columns
  required_cols <- c("atlasId", "label", "domain", "sourceCode")
  missing_cols <- setdiff(required_cols, names(concept_set_load))

  if (length(missing_cols) > 0) {
    stop("Concept set load is missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # Initialize file_name column
  concept_set_load$file_name <- NA_character_

  cli::cli_alert_info("Importing {nrow(concept_set_load)} concept sets from ATLAS...")

  # Process each concept set
  for (i in seq_len(nrow(concept_set_load))) {
    atlas_id <- concept_set_load$atlasId[i]
    label <- concept_set_load$label[i]
    domain <- concept_set_load$domain[i]
    source_code <- concept_set_load$sourceCode[i]

    # Skip rows with missing atlasId
    if (is.na(atlas_id)) {
      cli::cli_alert_warning("Row {i}: Skipping concept set with missing atlasId")
      next
    }

    tryCatch({
      # Get concept set definition from ATLAS
      cli::cli_alert_info("Fetching concept set {atlas_id}: {label}...")
      cs_def <- atlasConnection$getConceptSetDefinition(conceptSetId = atlas_id)

      # Extract expression
      cs_expression <- cs_def$expression[1]

      # Extract concept set name from definition (fallback to label if not available)
      cs_name <- ifelse(!is.null(cs_def$saveName[1]) && cs_def$saveName[1] != "",
        cs_def$saveName[1], label
      )

      # Ensure output folder exists
      outputFolder <- fs::path(conceptSetsFolderPath, "json")
      fs::dir_create(outputFolder)

      # Create file name from cs_name (make it file-system friendly)
      file_name <- fs::path(outputFolder, cs_name, ext = "json")

      # Write concept set JSON to file
      readr::write_file(cs_expression, file = file_name)

      # Store the relative file name in the data frame
      concept_set_load$file_name[i] <- fs::path_rel(file_name)

      cli::cli_alert_success(
        "Imported concept set {crayon::magenta(cs_name)} (ID: {atlas_id}) to {crayon::cyan(fs::path_rel(outputFolder))}"
      )
    }, error = function(e) {
      cli::cli_alert_danger(
        "Error importing concept set {label} (ID: {atlas_id}): {e$message}"
      )
    })
  }

  # Save the updated concept_set_load file with file_name column
  readr::write_csv(concept_set_load, file = conceptSetLoadPath)
  cli::cli_alert_success("Updated concept set load file saved to: {fs::path_rel(conceptSetLoadPath)}")

  cli::cli_alert_success("ATLAS concept set import complete")
  invisible(concept_set_load)
}