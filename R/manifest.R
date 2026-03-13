#' Load Cohort Manifest from Database or Cohort Files
#'
#' Loads a CohortManifest R6 object by either reading from an existing
#' cohortManifest.sqlite database or by scanning the inputs/cohorts directories.
#'
#' @param executionSettings An ExecutionSettings object containing database configuration
#'   for cohort generation.
#' @param cohortsFolderPath Character. Path to the cohorts folder containing the manifest
#'   database and cohort definition files. Defaults to "inputs/cohorts". The function
#'   will look for:
#'   - `cohortManifest.sqlite` in this folder for existing manifest data
#'   - `json/` subfolder for CIRCE JSON cohort definitions
#'   - `sql/` subfolder for SQL cohort definitions
#'
#' @return A CohortManifest R6 object initialized with all cohorts found.
#'
#' @details
#' **If database exists:**
#' Loads cohort paths and metadata from the cohortManifest.sqlite database,
#' verifies files still exist, and checks if any files have changed by comparing
#' the stored hash with the current file hash.
#'
#' **If database doesn't exist:**
#' Scans `cohortsFolderPath/json` and `cohortsFolderPath/sql` directories to find cohort
#' definition files and creates a new CohortDef for each file with:
#' - label: The basename of the file without extension
#' - tags: Empty list
#' - filePath: The full path to the cohort file
#'
#' **Metadata Enrichment (optional):**
#' If a `cohortsLoad.csv` file exists in `cohortsFolderPath`, the function will
#' automatically enrich CohortDef objects with tags by matching the `file_name`
#' column from the load file with the `filePath` of each entry. For matching entries,
#' tags are added from the following columns:
#' - `atlasId`: Added as an "atlasId" tag
#' - `category`: Added as a "category" tag
#' - `subCategory`: Added as a "subCategory" tag
#'
#' Hash comparison alerts:
#' - **✓ Unchanged**: Hash matches stored value
#' - **⚠ Changed**: Hash differs from stored value (file was modified)
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   settings <- ExecutionSettings$new(
#'     databaseName = "mydb",
#'     dbms = "postgresql",
#'     connectionDetails = list(...)
#'   )
#'   manifest <- loadCohortManifest(settings, cohortsFolderPath = "path/to/cohorts")
#' }
#'
loadCohortManifest <- function(executionSettings, cohortsFolderPath = here::here("inputs/cohorts")) {
  dbPath <- fs::path(cohortsFolderPath, "cohortManifest.sqlite")
  cohort_entries <- list()

  # Check if database already exists and has entries
  if (file.exists(dbPath)) {
    conn <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
    on.exit(DBI::dbDisconnect(conn))

    # Query existing cohorts from database
    existing_cohorts <- DBI::dbGetQuery(
      conn,
      "SELECT id, label, tags, filePath, hash FROM cohort_manifest"
    )

    # Only load from manifest if it has entries
    if (nrow(existing_cohorts) > 0) {
      cli::cli_alert_info("Loading cohorts from existing manifest: {dbPath}")

      # Process each cohort from database
      for (i in seq_len(nrow(existing_cohorts))) {
        record <- existing_cohorts[i, ]
        file_path <- record$filePath
        stored_hash <- record$hash
        tags_string <- record$tags

        # Check if file still exists
        if (!file.exists(file_path)) {
          cli::cli_alert_danger("Cohort file not found: {record$label} ({file_path})")
          next
        }

        tryCatch({
          # Create CohortDef from file (this computes current hash)
          cohort_entry <- CohortDef$new(
            label = record$label,
            tags = list(),
            filePath = file_path
          )

          # Backfill tags from database
          if (!is.na(tags_string) && tags_string != "") {
            parsed_tags <- parseTagsString(tags_string)
            cohort_entry$tags <- parsed_tags
          }

          cohort_entries[[length(cohort_entries) + 1]] <- cohort_entry
        }, error = function(e) {
          cli::cli_alert_danger("Error loading cohort {record$label}: {e$message}")
        })
      }

      if (length(cohort_entries) > 0) {
        cli::cli_alert_success("Loaded {length(cohort_entries)} cohorts from manifest")
        # Successfully loaded from manifest, proceed to create and return
      } else {
        # Database had entries but none could be loaded, fall through to scan directories
        cli::cli_alert_warning("No valid cohorts could be loaded from manifest. Scanning directories...")
        cohort_entries <- list()  # Reset to empty for directory scan
      }
    } else {
      # Manifest exists but is empty, scan directories
      cli::cli_alert_warning("Manifest exists but contains no cohort entries. Scanning directories...")
    }
  }

  # If no cohorts loaded from manifest (or manifest didn't exist), scan directories
  if (length(cohort_entries) == 0) {
    cli::cli_alert_info("Scanning cohort directories...")

    # Define directories to search
    json_dir <- fs::path(cohortsFolderPath, "json")
    sql_dir <- fs::path(cohortsFolderPath, "sql")

    # Process JSON directory if it exists
    if (dir.exists(json_dir)) {
      json_files <- list.files(json_dir, pattern = "\\.json$", full.names = TRUE, recursive = TRUE)

      for (file_path in json_files) {
        label <- tools::file_path_sans_ext(basename(file_path))
        tryCatch({
          cohort_entry <- CohortDef$new(
            label = label,
            tags = list(),
            filePath = file_path
          )
          cohort_entries[[length(cohort_entries) + 1]] <- cohort_entry
          cli::cli_alert_success("Loaded JSON cohort: {label}")
        }, error = function(e) {
          cli::cli_alert_danger("Error loading JSON cohort {label}: {e$message}")
        })
      }
    }

    # Process SQL directory if it exists
    if (dir.exists(sql_dir)) {
      sql_files <- list.files(sql_dir, pattern = "\\.sql$", full.names = TRUE, recursive = TRUE)

      for (file_path in sql_files) {
        label <- tools::file_path_sans_ext(basename(file_path))
        tryCatch({
          cohort_entry <- CohortDef$new(
            label = label,
            tags = list(),
            filePath = file_path
          )
          cohort_entries[[length(cohort_entries) + 1]] <- cohort_entry
          cli::cli_alert_success("Loaded SQL cohort: {label}")
        }, error = function(e) {
          cli::cli_alert_danger("Error loading SQL cohort {label}: {e$message}")
        })
      }
    }

    if (length(cohort_entries) == 0) {
      stop("No cohort files found in cohorts/json or cohorts/sql directories")
    }

    cli::cli_alert_success("Found {length(cohort_entries)} total cohorts")
  }

  # Check for cohortsLoad.csv file to enrich entries with tags and labels
  cohorts_load_path <- fs::path(cohortsFolderPath, "cohortsLoad.csv")
  if (file.exists(cohorts_load_path)) {
    cli::cli_alert_info("Found cohortsLoad.csv. Enriching entries with load metadata...")

    tryCatch({
      cohorts_load <- readr::read_csv(cohorts_load_path, show_col_types = FALSE)

      # Validate required columns (label is optional)
      required_cols <- c("file_name", "atlasId", "category", "subCategory")
      missing_cols <- setdiff(required_cols, names(cohorts_load))

      if (length(missing_cols) == 0) {
        # Process each cohort entry to find matching load record
        tags_added <- 0
        labels_updated <- 0
        for (i in seq_along(cohort_entries)) {
          entry <- cohort_entries[[i]]
          entry_filepath_rel <- fs::path_rel(entry$getFilePath())

          # Find matching record in cohortsLoad by file_name
          matching_idx <- which(entry_filepath_rel == cohorts_load$file_name)

          if (length(matching_idx) > 0) {
            load_record <- cohorts_load[matching_idx[1], ]

            # Update label if provided in cohortsLoad.csv
            if ("label" %in% names(cohorts_load) && !is.na(load_record$label)) {
              entry$label <- as.character(load_record$label)
              labels_updated <- labels_updated + 1
            }

            # Add tags from load record
            entry_tags <- list()
            if (!is.na(load_record$atlasId)) {
              entry_tags[["atlasId"]] <- as.character(load_record$atlasId)
            }
            if (!is.na(load_record$category)) {
              entry_tags[["category"]] <- as.character(load_record$category)
            }
            if (!is.na(load_record$subCategory)) {
              entry_tags[["subCategory"]] <- as.character(load_record$subCategory)
            }

            if (length(entry_tags) > 0) {
              entry$tags <- entry_tags
              tags_added <- tags_added + 1
              cli::cli_alert_success("Added metadata to cohort: {entry$label}")
            }
          }
        }

        cli::cli_alert_success("Updated {labels_updated} labels and added tags to {tags_added} cohort entries from cohortsLoad.csv")
      } else {
        cli::cli_alert_warning("cohortsLoad.csv is missing required columns: {paste(missing_cols, collapse = ', ')}")
      }
    }, error = function(e) {
      cli::cli_alert_danger("Error reading cohortsLoad.csv: {e$message}")
    })
  }

  # Create and return the CohortManifest
  manifest <- CohortManifest$new(
    cohortEntries = cohort_entries,
    executionSettings = executionSettings,
    dbPath = dbPath
  )

  return(manifest)
}

#' Reset Cohort Manifest Database
#'
#' Deletes the cohortManifest.sqlite database file. Use this function when you need
#' to reset the manifest and rebuild it from the available cohort files.
#'
#' @param cohortsFolderPath Character. Path to the cohorts folder containing the manifest
#'   database. Defaults to "inputs/cohorts".
#'
#' @return Invisibly returns NULL. Deletes the manifest file and prints status messages.
#'
#' @details
#' This function is useful for:
#' - Starting fresh with a new set of cohorts
#' - Clearing cached manifest data
#' - Resolving manifest corruption issues
#'
#' After resetting, call [loadCohortManifest()] to rebuild the manifest from
#' the available cohort files in the json/ and sql/ subdirectories.
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Reset the manifest
#'   resetCohortManifest()
#'
#'   # Rebuild it from cohort files
#'   settings <- ExecutionSettings$new(...)
#'   manifest <- loadCohortManifest(settings)
#' }
#'
resetCohortManifest <- function(cohortsFolderPath = here::here("inputs/cohorts")) {
  dbPath <- fs::path(cohortsFolderPath, "cohortManifest.sqlite")

  if (file.exists(dbPath)) {
    file.remove(dbPath)
    cli::cli_alert_success("Cohort manifest database deleted: {fs::path_rel(dbPath)}")
    cli::cli_alert_info("To rebuild the manifest, call loadCohortManifest() with your ExecutionSettings")
  } else {
    cli::cli_alert_warning("Cohort manifest database not found at: {fs::path_rel(dbPath)}")
  }

  invisible(NULL)
}

#' Interactively Create Cohort Load File
#'
#' Guides the user through an interactive process to create a cohortsLoad.csv file.
#' The file contains metadata about cohorts to be imported from ATLAS and is used by
#' [importAtlasCohorts()] to fetch and save cohort definitions.
#'
#' @param cohortsFolderPath Character. Path to the cohorts folder where cohortsLoad.csv
#'   will be saved. Defaults to "inputs/cohorts".
#'
#' @return Invisibly returns a data frame containing the cohort load metadata.
#'   Saves the file to `cohortsFolderPath/cohortsLoad.csv`.
#'
#' @details
#' The function prompts the user to enter information for each cohort:
#' - **atlasId**: ATLAS cohort definition ID (numeric)
#' - **label**: Human-readable name for the cohort (character)
#' - **category**: Broad category/classification (character)
#' - **subCategory**: More specific sub-category (character)
#'
#' After each cohort entry, the user is asked whether to add another cohort.
#' When complete, the data is saved to `cohortsLoad.csv` in the cohorts folder.
#'
#' **Workflow:**
#' 1. Call this function to interactively create the load file
#' 2. Use [importAtlasCohorts()] to import cohorts from ATLAS using this file
#' 3. Use [loadCohortManifest()] to load the imported cohorts and build the manifest
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Create the load file interactively
#'   createCohortsLoadFile()
#'
#'   # Then import cohorts from ATLAS
#'   importAtlasCohorts(
#'     cohortLoadPath = "inputs/cohorts/cohortsLoad.csv",
#'     atlasConnection = atlas_conn
#'   )
#' }
#'
createCohortsLoadFile <- function(cohortsFolderPath = here::here("inputs/cohorts")) {
  cli::cli_h1("Create Cohort Load File")
  cli::cli_text("Enter cohort information to be imported from ATLAS.")
  cli::cli_text("You will be prompted for each cohort field. Press Enter to continue.")
  cli::cli_text("")

  # Initialize data frame
  cohort_load <- data.frame(
    atlasId = integer(),
    label = character(),
    category = character(),
    subCategory = character(),
    file_name = character(),
    stringsAsFactors = FALSE
  )

  # Interactive loop to add cohorts
  continue_adding <- TRUE
  cohort_count <- 0

  while (continue_adding) {
    cohort_count <- cohort_count + 1
    cli::cli_h2("Cohort {cohort_count}")

    # Get atlasId
    while (TRUE) {
      atlas_id_input <- readline("Enter ATLAS Cohort ID (numeric): ")
      if (atlas_id_input == "") {
        cli::cli_alert_warning("ATLAS ID cannot be empty. Please try again.")
        next
      }
      atlas_id <- tryCatch(as.integer(atlas_id_input), warning = function(w) NA)
      if (is.na(atlas_id)) {
        cli::cli_alert_warning("ATLAS ID must be a number. Please try again.")
        next
      }
      break
    }

    # Get label
    while (TRUE) {
      label <- readline("Enter Cohort Label/Name: ")
      if (label == "") {
        cli::cli_alert_warning("Label cannot be empty. Please try again.")
        next
      }
      break
    }

    # Get category
    while (TRUE) {
      category <- readline("Enter Category: ")
      if (category == "") {
        cli::cli_alert_warning("Category cannot be empty. Please try again.")
        next
      }
      break
    }

    # Get subCategory
    sub_category <- readline("Enter Sub-Category (optional, press Enter to skip): ")
    if (sub_category == "") {
      sub_category <- NA_character_
    }

    # Generate file name
    file_name <- fs::path("json", paste0(label, ".json"))

    # Add to data frame
    cohort_load <- rbind(cohort_load, data.frame(
      atlasId = atlas_id,
      label = label,
      category = category,
      subCategory = sub_category,
      file_name = file_name,
      stringsAsFactors = FALSE
    ))

    cli::cli_alert_success("Added cohort: {label}")
    cli::cli_text("")

    # Ask if user wants to add another cohort
    add_another <- readline("Add another cohort? (yes/no): ")
    continue_adding <- tolower(trimws(add_another)) %in% c("yes", "y")
  }

  # Save to file
  if (nrow(cohort_load) > 0) {
    fs::dir_create(cohortsFolderPath)
    save_path <- fs::path(cohortsFolderPath, "cohortsLoad.csv")

    readr::write_csv(cohort_load, file = save_path)
    cli::cli_alert_success("Cohort load file saved: {fs::path_rel(save_path)}")
    cli::cli_alert_info("Total cohorts to import: {nrow(cohort_load)}")
    cli::cli_text("")
    cli::cli_alert_info("Next step: Call importAtlasCohorts() to import these cohorts from ATLAS")
  } else {
    cli::cli_alert_warning("No cohorts were added. File not saved.")
  }

  invisible(cohort_load)
}

#' Launch Interactive Cohort Load File Editor
#'
#' Opens an interactive Shiny application for creating and editing the cohortsLoad.csv file.
#' The app allows viewing, editing, adding, and deleting cohort entries in a tabular format.
#'
#' @param cohortsFolderPath Character. Path to the cohorts folder where cohortsLoad.csv
#'   will be saved. Defaults to "inputs/cohorts".
#'
#' @return Invisibly launches a Shiny app. Saves cohortsLoad.csv when the user submits.
#'
#' @details
#' **Features:**
#' - View existing cohorts in a data table
#' - Edit cells directly in the table
#' - Add new cohort rows with form inputs
#' - Delete selected rows
#' - Save to cohortsLoad.csv
#' - Input validation for required fields
#'
#' **Table Columns:**
#' - `atlasId`: ATLAS cohort definition ID (numeric)
#' - `label`: Cohort name/label (character) - editing updates file_name automatically
#' - `category`: Broad category (character)
#' - `subCategory`: Sub-category (character)
#' - `file_name`: Auto-generated as `json/{label}.json` (read-only)
#'
#' **Workflow:**
#' 1. Call this function to launch the editor app
#' 2. Add/edit cohorts as needed
#' 3. Click "Save Cohort Load File" to save to inputs/cohorts/cohortsLoad.csv
#' 4. Use [importAtlasCohorts()] to import cohorts from ATLAS
#' 5. Use [loadCohortManifest()] to load the imported cohorts
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Launch the editor app
#'   launchCohortsLoadEditor()
#' }
#'
launchCohortsLoadEditor <- function(cohortsFolderPath = here::here("inputs/cohorts")) {
  # Check if Shiny is installed
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("The 'shiny' package is required to use this function. Install it with: install.packages('shiny')")
  }
  if (!requireNamespace("DT", quietly = TRUE)) {
    stop("The 'DT' package is required to use this function. Install it with: install.packages('DT')")
  }

  # Try to load existing cohortsLoad.csv
  existing_load <- NULL
  load_path <- fs::path(cohortsFolderPath, "cohortsLoad.csv")
  if (file.exists(load_path)) {
    existing_load <- readr::read_csv(load_path, show_col_types = FALSE)
    
    # Ensure file_name column exists; generate if missing
    if (!"file_name" %in% names(existing_load)) {
      existing_load$file_name <- fs::path("json", paste0(existing_load$label, ".json"))
    }
    
    # Ensure columns are in the correct order
    existing_load <- existing_load[, c("atlasId", "label", "category", "subCategory", "file_name")]
  }

  # Create the Shiny app
  app <- shiny::shinyApp(
    ui = function() {
      shiny::fluidPage(
        shiny::titlePanel("Cohort Load File Editor"),
        shiny::sidebarLayout(
          shiny::sidebarPanel(
            shiny::h4("Add New Cohort"),
            shiny::numericInput("atlas_id", "ATLAS ID:", value = NA, min = 1),
            shiny::textInput("label", "Label:", ""),
            shiny::textInput("category", "Category:", ""),
            shiny::textInput("sub_category", "Sub-Category (optional):", ""),
            shiny::actionButton("add_row", "Add Cohort", class = "btn-primary"),
            shiny::hr(),
            shiny::h4("Actions"),
            shiny::actionButton("delete_rows", "Delete Selected Rows", class = "btn-danger"),
            shiny::hr(),
            shiny::actionButton("save_file", "Save Cohort Load File", class = "btn-success"),
            shiny::actionButton("cancel", "Cancel", class = "btn-secondary")
          ),
          shiny::mainPanel(
            DT::DTOutput("cohort_table"),
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
          file_name = character(),
          stringsAsFactors = FALSE
        ),
        message = NULL,
        message_type = NULL
      )

      # Display the data table
      output$cohort_table <- DT::renderDT({
        DT::datatable(
          rv$data,
          editable = list(target = "cell", disable = list(columns = 5)),
          selection = "multiple",
          rownames = FALSE,
          options = list(pageLength = 10)
        )
      })

      # Handle table edits
      shiny::observeEvent(input$cohort_table_cell_edit, {
        info <- input$cohort_table_cell_edit
        rv$data[info$row, info$col] <- info$value

        # Update file_name automatically if label (column 2) changed
        if (info$col == 2) {
          rv$data$file_name[info$row] <- fs::path("json", paste0(info$value, ".json"))
          rv$message <- "Label updated - file_name auto-generated"
          rv$message_type <- "info"
        }
      })

      # Add new cohort
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

        # Add row
        new_row <- data.frame(
          atlasId = as.integer(input$atlas_id),
          label = input$label,
          category = input$category,
          subCategory = if (input$sub_category == "") NA_character_ else input$sub_category,
          file_name = fs::path("json", paste0(input$label, ".json")),
          stringsAsFactors = FALSE
        )

        rv$data <- rbind(rv$data, new_row)
        rv$message <- paste("Added cohort:", input$label)
        rv$message_type <- "success"

        # Clear inputs
        shiny::updateNumericInput(session, "atlas_id", value = NA)
        shiny::updateTextInput(session, "label", value = "")
        shiny::updateTextInput(session, "category", value = "")
        shiny::updateTextInput(session, "sub_category", value = "")
      })

      # Delete selected rows
      shiny::observeEvent(input$delete_rows, {
        selected <- input$cohort_table_rows_selected
        if (length(selected) == 0) {
          rv$message <- "No rows selected"
          rv$message_type <- "warning"
        } else {
          deleted_labels <- rv$data$label[selected]
          rv$data <- rv$data[-selected, ]
          rv$message <- paste("Deleted", length(selected), "cohort(s):", paste(deleted_labels, collapse = ", "))
          rv$message_type <- "info"
        }
      })

      # Save file
      shiny::observeEvent(input$save_file, {
        if (nrow(rv$data) == 0) {
          rv$message <- "Cannot save: No cohorts in table"
          rv$message_type <- "danger"
          return()
        }

        fs::dir_create(cohortsFolderPath)
        save_path <- fs::path(cohortsFolderPath, "cohortsLoad.csv")
        readr::write_csv(rv$data, file = save_path)

        rv$message <- paste("Cohort load file saved successfully!\nLocation:", fs::path_rel(save_path))
        rv$message_type <- "success"

        shiny::showNotification(
          paste("Saved", nrow(rv$data), "cohorts to cohortsLoad.csv"),
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


#' Function to parse tags string from database into a named list
#' @keywords internal
#'
#' @param tags_str Character. Tags string in format "name: value | name: value"
#'
#' @return List. Named list of tags
#'
parseTagsString <- function(tags_str) {
  if (is.na(tags_str) || tags_str == "") {
    return(list())
  }

  # Split by pipe separator
  tag_pairs <- strsplit(tags_str, " \\| ")[[1]]

  # Parse each pair
  tags_list <- list()
  for (pair in tag_pairs) {
    parts <- strsplit(pair, ":\\s*")[[1]]
    if (length(parts) == 2) {
      tag_name <- trimws(parts[1])
      tag_value <- trimws(parts[2])
      tags_list[[tag_name]] <- tag_value
    }
  }

  return(tags_list)
}



importAtlasConceptSetsFromManifest <- function(
    conceptSetManifest,
    atlasConnection,
    outputFolder = here::here("inputs/conceptSets/json")
) {

  for (i in 1:nrow(conceptSetManifest)) {
    if (is.na(conceptSetManifest$atlasId[i])) {
      next
    }
    concept_set <- atlasConnection$getConceptSetDefinition(conceptSetId = conceptSetManifest$atlasId[i])
    conceptSetManifest$name[i] <- concept_set$saveName[1]
    conceptSetManifest$expression[i] <- concept_set$expression[1]
  }

  for (j in 1:nrow(conceptSetManifest)) {
    if (is.na(conceptSetManifest$atlasId[i])) {
      next
    }
    csCategory <- snakecase::to_snake_case(conceptSetManifest$category[j])
    csSubCategory <- ifelse(is.na(conceptSetManifest$subCategory[j]), "", snakecase::to_snake_case(conceptSetManifest$subCategory[j]))
    subDirs<- fs::path(csCategory, csSubCategory)
    savePath <- outputFolder |>
      fs::dir_create(subDirs)
    savePathRel <- fs::path_rel(savePath)

    # Save concept set expression to json folder
    saveNameTmp <- conceptSetManifest$name[j]
    fileNameTmp <- fs::path(savePath, saveNameTmp, ext = "json")
    csExpTmp <- conceptSetManifest$expression[j]
    readr::write_file(csExpTmp, file = fileNameTmp)
      cli::cat_bullet(
        glue::glue("Circe ConceptSet Json {crayon::magenta(saveNameTmp)} saved to: {crayon::cyan(savePath)}"),
        bullet = "pointer",
        bullet_col = "yellow"
      )
    conceptSetManifest$path[j] <- fs::path(savePathRel, saveNameTmp, ext = "json")
  }

  conceptSetManifest <- conceptSetManifest |>
    dplyr::select(-expression)

  invisible(conceptSetManifest)
}

#' Import CIRCE Cohort Definitions from ATLAS
#'
#' Imports CIRCE JSON cohort definitions from an ATLAS WebAPI instance and saves
#' them to the inputs/cohorts/json folder. This function reads a CSV file containing
#' cohort metadata and fetches the actual cohort definitions from ATLAS.
#' 
#' @description this function looks for a CSV file called cohortsLoad.csv containing cohort metadata.
#'   Must be located in or accessible from the inputs/cohorts folder.
#'   The CSV must have the following columns:
#'   - `atlasId`: ATLAS cohort definition ID (integer)
#'   - `label`: Cohort name/label (character)
#'   - `category`: Broad category for the cohort (character)
#'   - `subCategory`: Sub-category for the cohort (character)
#' The function will read this CSV, fetch the cohort definitions from ATLAS using the provided atlasConnection,
#' extract the CIRCE JSON expressions, and save them to the specified output folder with filenames based on the label.
#' Finally it updates the cohort load CSV with the relative file paths to the saved JSON files.
#'
#' @param cohortsFolderPath Character. Path to cohorts folder in Ulysses repo. 
#'
#' @param atlasConnection An ATLAS connection object (typically from ROhdsiWebApi package)
#'   with a method `getCohortDefinition(cohortId)` that returns a list containing
#'   an `expression` element with the CIRCE JSON string.
#'
#' @param outputFolder Character. Path to the output folder where cohort JSON files
#'   will be saved. Defaults to "inputs/cohorts/json". Files are saved as
#'   `{label}.json`.
#'
#' @return Invisibly returns NULL. Saves CIRCE JSON files to outputFolder and
#'   prints status messages via cli alerts.
#'
#' @details
#' **Workflow:**
#' 1. Reads the cohort load CSV file
#' 2. Validates that all required columns are present
#' 3. For each row with a valid atlasId:
#'    - Fetches the cohort definition from ATLAS WebAPI
#'    - Extracts the CIRCE JSON expression
#'    - Saves to `outputFolder/{label}.json`
#' 4. Skips rows with missing atlasId with a warning
#' 5. Catches and reports errors per cohort without stopping the entire import
#'
#' **Post-Import:**
#' After running this function, use [loadCohortManifest()] to load the saved
#' cohort JSON files and build the manifest with metadata.
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Assuming ATLAS connection is set up
#'   importAtlasCohorts(
#'     cohortFolderPath = here::here("inputs/cohorts"),
#'     atlasConnection = setAtlasConnection()
#'   )
#'
#'   # Then load the manifest
#'   settings <- createExecutionSettings(...)
#'   manifest <- loadCohortManifest(settings)
#' }
#'
importAtlasCohorts <- function(cohortsFolderPath,
                               atlasConnection) {
  cohortLoadPath <- fs::path(cohortsFolderPath, "cohortsLoad.csv")                              
  # Read cohort manifest CSV file
  if (!file.exists(cohortLoadPath)) {
    stop("Cohort load file not found: ", cohortLoadPath)
  }

  cohort_load <- readr::read_csv(cohortLoadPath, show_col_types = FALSE)

  # Validate required columns
  required_cols <- c("atlasId", "label", "category", "subCategory")
  missing_cols <- setdiff(required_cols, names(cohort_load))

  if (length(missing_cols) > 0) {
    stop("Cohort load is missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # Initialize file_name column
  cohort_load$file_name <- NA_character_

  cli::cli_alert_info("Importing {nrow(cohort_load)} cohorts from ATLAS...")

  # Process each cohort
  for (i in seq_len(nrow(cohort_load))) {
    atlas_id <- cohort_load$atlasId[i]
    label <- cohort_load$label[i]
    category <- cohort_load$category[i]
    sub_category <- cohort_load$subCategory[i]

    # Skip rows with missing atlasId
    if (is.na(atlas_id)) {
      cli::cli_alert_warning("Row {i}: Skipping cohort with missing atlasId")
      next
    }

    tryCatch({
      # Get cohort definition from ATLAS
      cli::cli_alert_info("Fetching cohort {atlas_id}: {label}...")
      cohort_def <- atlasConnection$getCohortDefinition(cohortId = atlas_id)

      # Extract expression
      cohort_expression <- cohort_def$expression[1]
      # extract cohort name from definition to use as file name (fallback to label if not available)
      cohort_name <- ifelse(!is.null(cohort_def$saveName[1]) && cohort_def$saveName[1] != "", cohort_def$saveName[1], label)
      # Ensure output folder exists
      outputFolder <- fs::path(cohortsFolderPath, "json")
      fs::dir_create(outputFolder)
      save_path_rel <- fs::path_rel(outputFolder)

      # Create file name from cohort_name (make it file-system friendly)
      file_name <- fs::path(outputFolder, cohort_name, ext = "json")

      # Write cohort JSON to file
      readr::write_file(cohort_expression, file = file_name)

      # Store the relative file name in the data frame
      cohort_load$file_name[i] <- fs::path_rel(file_name)

      cli::cli_alert_success(
        "Imported cohort {crayon::magenta(cohort_name)} (ID: {atlas_id}) to {crayon::cyan(save_path_rel)}"
      )
    }, error = function(e) {
      cli::cli_alert_danger(
        "Error importing cohort {cohort_name} (ID: {atlas_id}): {e$message}"
      )
    })
  }

  # Save the updated cohort_load file with file_name column to inputs/cohorts
  # Generate save path from original file path, keeping the original filename
  readr::write_csv(cohort_load, file = cohortLoadPath)
  cli::cli_alert_success("Updated cohort load file saved to: {fs::path_rel(cohortLoadPath)}")

  cli::cli_alert_success("ATLAS cohort import complete")
  invisible(cohort_load)
}
