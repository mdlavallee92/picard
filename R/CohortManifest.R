#' CohortEntry R6 Class
#'
#' An R6 class that stores key information about CIRCE cohorts that need to be
#' generated for a study.
#'
#' @details
#' The CohortEntry class manages cohort metadata and SQL generation.
#' Upon initialization, it loads and validates cohort definitions from either
#' JSON (CIRCE format) or SQL files, and creates a hash to uniquely identify
#' the generated SQL.
#'
#' @export
CohortEntry <- R6::R6Class(
  classname = "CohortEntry",
  private = list(
    .label = NULL,
    .tags = NULL,
    .filePath = NULL,
    .sql = NULL,
    .hash = NULL,
    .id = NULL,

    # Load SQL from file
    load_sql_from_file = function(filePath) {
      if (!file.exists(filePath)) {
        stop("File does not exist: ", filePath)
      }

      file_ext <- tolower(tools::file_ext(filePath))

      if (file_ext == "sql") {
        # Load SQL file directly
        private$.sql <- readChar(filePath, file.info(filePath)$size)
      } else if (file_ext == "json") {
        # Load and validate JSON as CIRCE cohort
        json_content <- readr::read_file(filePath)
        # Validate JSON is valid CIRCE using CirceR
        tryCatch(
          CirceR::cohortExpressionFromJson(json_content),
          error = function(e) {
            stop("JSON file is not valid CIRCE format: ", filePath, "\nError: ", e$message)
          }
        )

        # Render JSON to SQL
        private$.sql <- CirceR::buildCohortQuery(json_content, options = CirceR::createGenerateOptions(generateStats = TRUE))
      } else {
        stop("File must be either .sql or .json, got: .", file_ext)
      }

      # Create hash of SQL string
      private$.hash <- rlang::hash(private$.sql)
    }
  ),

  public = list(
    #' Initialize a new CohortEntry
    #'
    #' @param label Character. The common name of the cohort.
    #' @param tags List. A named list of tags that give metadata about the cohort.
    #' @param filePath Character. Path to the cohort file in inputs/cohorts folder
    #'   (can be .json or .sql).
    initialize = function(label, tags = list(), filePath) {
      checkmate::assert_string(x = label, min.chars = 1)
      checkmate::assert_list(x = tags, names = "named")
      checkmate::assert_file_exists(x = filePath)

      private$.label <- label
      private$.tags <- tags
      private$.filePath <- filePath

      # Load SQL and generate hash
      private$load_sql_from_file(filePath)

      # Cohort ID will be assigned later when listed within the CohortManifest
      private$.id <- NA_integer_
    },

    #' Get the file path
    #'
    #' @return Character. The file path.
    getFilePath = function() {
      fs::path_rel(private$.filePath)
    },

    #' Get the generated SQL
    #'
    #' @return Character. The SQL string.
    getSql = function() {
      private$.sql
    },

    #' Get the SQL hash
    #'
    #' @return Character. The hash of the SQL string.
    getHash = function() {
      private$.hash
    },

    #' Get the SQL hash
    #'
    #' @return integer. The integer identifying the cohort in the cohort table.
    getId = function() {
      private$.id
    },

    #' Set the cohort ID (internal use)
    #'
    #' @param id Integer. The ID to set.
    setId = function(id) {
      checkmate::assert_int(x = id)
      private$.id <- id
    },

    #' Format tags as string
    #'
    #' @return Character. Tags formatted as "name1: value1 | name2: value2"
    formatTagsAsString = function() {
      if (length(private$.tags) == 0) {
        return("")
      }
      tags_str <- mapply(
        function(name, value) {
          paste0(name, ": ", value)
        },
        names(private$.tags),
        private$.tags,
        SIMPLIFY = TRUE
      )
      paste(tags_str, collapse = " | ")
    }
  ),

  active = list(
    #' @field label Get or set the cohort label (active binding)
    label = function(value) {
      if (missing(value)) {
        private[[".label"]]
      } else {
        checkmate::assert_string(x = value, min.chars = 1)
        private[[".label"]] <- value
      }
    },

    #' @field tags Get or set the cohort tags (active binding)
    tags = function(value) {
      if (missing(value)) {
        private[[".tags"]]
      } else {
        checkmate::assert_list(x = value)
        private[[".tags"]] <- value
      }
    }
  )
)

#' CohortManifest R6 Class
#'
#' An R6 class that manages a collection of CohortEntry objects and maintains
#' metadata in a SQLite database.
#'
#' @details
#' The CohortManifest class manages multiple cohort entries and stores their
#' metadata in a SQLite database located at inputs/cohorts/cohortManifest.sqlite.
#' Each CohortEntry is assigned a sequential ID based on its position in the manifest.
#'
#' @export
CohortManifest <- R6::R6Class(
  classname = "CohortManifest",
  private = list(
    .manifest = NULL,
    .dbPath = NULL,
    .executionSettings = NULL,

    # Initialize the SQLite database
    init_manifest = function(dbPath) {
      # Create inputs/cohorts directory if it doesn't exist
      dbDir <- dirname(dbPath)
      if (!dir.exists(dbDir)) {
        dir.create(dbDir, recursive = TRUE, showWarnings = FALSE)
      }

      # Check if database file already exists
      db_exists <- file.exists(dbPath)

      # Create cohort table only if manifest is new
      if (!db_exists) {
        # Connect to manifest (creates if doesn't exist)
        cli::cat_bullet(
            glue::glue("Initializing manifest at {dbPath}."), 
            bullet = "info",
            bullet_col = "blue"
        )
        conn <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
        DBI::dbExecute(
          conn,
          "CREATE TABLE IF NOT EXISTS cohort_manifest (
            id INTEGER PRIMARY KEY,
            label TEXT NOT NULL,
            tags TEXT,
            filePath TEXT NOT NULL,
            hash TEXT NOT NULL,
            timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
          )"
        )
        DBI::dbDisconnect(conn)
      } else {
        cli::cat_bullet(
            glue::glue("Manifest already exists at {dbPath}."), 
            bullet = "warning",
            bullet_col = "yellow"
        )
      }
    },

    # Populate the manifest with manifest entries
    # If the cohort_manifest table is empty, inserts all cohort entries with timestamps.
    # If the table already has entries, checks each cohort's hash against the database
    # and updates the timestamp for any entries where the hash has changed.
    populate_manifest = function(manifest) {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      # Check if table is empty
      existing_count <- DBI::dbGetQuery(
        conn,
        "SELECT COUNT(*) as count FROM cohort_manifest"
      )$count

      if (existing_count == 0) {
        # Table is empty, insert all cohort entries
        cli::cli_alert_info("Cohort manifest table is empty. Inserting {length(manifest)} cohort entries...")
        
        for (i in seq_along(manifest)) {
          cohort <- manifest[[i]]

          DBI::dbExecute(
            conn,
            "INSERT INTO cohort_manifest (id, label, tags, filePath, hash, timestamp) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)",
            list(
              cohort$getId(),
              cohort$label,
              cohort$formatTagsAsString(),
              cohort$getFilePath(),
              cohort$getHash()
            )
          )
          
          cli::cli_alert_success("Inserted cohort {cohort$getId()}: {cohort$label}")
        }
        
        cli::cli_alert_success("Successfully loaded {length(manifest)} cohorts into manifest")
      } else {
        # Table has existing entries, check for hash changes
        cli::cli_alert_info("Checking {length(manifest)} cohorts against existing manifest ({existing_count} entries)...")
        
        updated_count <- 0
        new_count <- 0
        unchanged_count <- 0
        
        for (i in seq_along(manifest)) {
          cohort <- manifest[[i]]
          cohort_id <- cohort$getId()
          new_hash <- cohort$getHash()

          # Get existing hash from database
          existing_record <- DBI::dbGetQuery(
            conn,
            "SELECT hash FROM cohort_manifest WHERE id = ?",
            list(cohort_id)
          )

          if (nrow(existing_record) == 0) {
            # New cohort entry, insert it
            DBI::dbExecute(
              conn,
              "INSERT INTO cohort_manifest (id, label, tags, filePath, hash, timestamp) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)",
              list(
                cohort_id,
                cohort$label,
                cohort$formatTagsAsString(),
                cohort$getFilePath(),
                new_hash
              )
            )
            
            cli::cli_alert_info("New cohort {cohort_id}: {cohort$label}")
            new_count <- new_count + 1
          } else if (existing_record$hash[1] != new_hash) {
            # Hash has changed, update the record and timestamp
            DBI::dbExecute(
              conn,
              "UPDATE cohort_manifest SET label = ?, tags = ?, filePath = ?, hash = ?, timestamp = CURRENT_TIMESTAMP WHERE id = ?",
              list(
                cohort$label,
                cohort$formatTagsAsString(),
                cohort$getFilePath(),
                new_hash,
                cohort_id
              )
            )
            
            cli::cli_alert_warning("Updated cohort {cohort_id}: {cohort$label} (SQL hash changed)")
            updated_count <- updated_count + 1
          } else {
            # Hash hasn't changed
            cli::cli_alert_success("Unchanged cohort {cohort_id}: {cohort$label}")
            unchanged_count <- unchanged_count + 1
          }
        }
        
        cli::cli_rule("Manifest Update Summary")
        cli::cli_alert_success("Updated: {updated_count} | New: {new_count} | Unchanged: {unchanged_count}")
      }
    }
  ),

  public = list(
    #' Initialize a new CohortManifest
    #'
    #' @param cohortEntries List. A list of CohortEntry objects.
    #' @param executionSettings Object. Execution settings for DBMS cohort generation.
    #'   Can be any object type containing configuration for how cohorts should be executed
    #'   on the target database.
    #' @param dbPath Character. Path to the SQLite database. Defaults to
    #'   "inputs/cohorts/cohortManifest.sqlite"
    initialize = function(cohortEntries, executionSettings, dbPath = "inputs/cohorts/cohortManifest.sqlite") {
      # Validate input is a list
      checkmate::assert_list(x = cohortEntries, min.len = 1)

      # Validate all elements are CohortEntry objects
      valid_entries <- all(sapply(cohortEntries, function(x) {
        inherits(x, "CohortEntry")
      }))

      if (!valid_entries) {
        stop("All elements in cohortEntries must be CohortEntry objects")
      }

      # Assign IDs to each cohort entry
      for (i in seq_along(cohortEntries)) {
        cohortEntries[[i]]$setId(as.integer(i))
      }

      private$.manifest <- cohortEntries
      private$.dbPath <- dbPath

      checkmate::assert_class(x = executionSettings, classes = "ExecutionSettings")
      private$.executionSettings <- executionSettings

      # Initialize and populate manifest
      private$init_manifest(dbPath)
      private$populate_manifest(cohortEntries)
    },

    #' Get the manifest as a data frame
    #'
    #' @return Data frame. The manifest with id, label, tags, filePath, hash, and timestamp columns.
    getManifest = function() {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))
      man <- DBI::dbGetQuery(
          conn, "SELECT id, label, tags, filePath, hash, timestamp FROM cohort_manifest ORDER BY id"
      ) 
      return(man)
    },

    #' Get the manifest path
    #'
    #' @return Character. The path to the SQLite database.
    getDbPath = function() {
      private$.dbPath
    },

    #' Get the execution settings
    #'
    #' @return Object. The execution settings object for DBMS cohort generation, or NULL if not set.
    getExecutionSettings = function() {
      private$.executionSettings
    },

    #' Set the execution settings
    #'
    #' @param executionSettings Object. Execution settings for DBMS cohort generation.
    setExecutionSettings = function(executionSettings) {
      private$.executionSettings <- executionSettings
    },

    #' Get a specific cohort by ID
    #'
    #' @param id Integer. The cohort ID.
    #'
    #' @return Data frame. A subset of the manifest with columns id, label, tags, filePath, hash, timestamp for the requested cohort.
    getCohortById = function(id) {
      checkmate::assert_int(x = id)

      cohort_obj <- NULL
      for (cohort in private$.manifest) {
        if (cohort$getId() == id) {
          cohort_obj <- cohort
          break
        }
      }

      if (is.null(cohort_obj)) {
        stop("Cohort with ID ", id, " not found")
      }

      # Get timestamp from database
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      timestamp_record <- DBI::dbGetQuery(
        conn,
        "SELECT timestamp FROM cohort_manifest WHERE id = ?",
        list(id)
      )

      timestamp <- if (nrow(timestamp_record) > 0) {
        timestamp_record$timestamp[1]
      } else {
        NA_character_
      }

      # Return as data frame
      data.frame(
        id = cohort_obj$getId(),
        label = cohort_obj$label,
        tags = cohort_obj$formatTagsAsString(),
        filePath = cohort_obj$getFilePath(),
        hash = cohort_obj$getHash(),
        timestamp = timestamp,
        stringsAsFactors = FALSE
      )
    },

    #' Get cohorts by tag
    #'
    #' @param tagString Character. A tag in the format "name: value" (e.g., "category: primary").
    #'
    #' @return Data frame. A subset of the manifest with columns id, label, tags, filePath, hash, timestamp for matching cohorts, or NULL if none found.
    getCohortsByTag = function(tagString) {
      checkmate::assert_string(x = tagString, min.chars = 1)

      # Parse the tag string to extract name and value
      tag_parts <- strsplit(tagString, ":\\s*")[[1]]
      if (length(tag_parts) != 2) {
        stop("Tag must be in the format 'name: value'")
      }

      tag_name <- trimws(tag_parts[1])
      tag_value <- trimws(tag_parts[2])

      matching_cohorts <- list()

      # Search through manifest for matching tags
      for (cohort in private$.manifest) {
        cohort_tags <- cohort$tags
        if (!is.null(cohort_tags) && tag_name %in% names(cohort_tags)) {
          if (cohort_tags[[tag_name]] == tag_value) {
            matching_cohorts[[length(matching_cohorts) + 1]] <- cohort
          }
        }
      }

      if (length(matching_cohorts) == 0) {
        cli::cli_alert_warning("No cohorts found with tag '{tag_name}: {tag_value}'")
        return(NULL)
      }

      # Convert matching cohorts to data frame
      manifest_df <- data.frame(
        id = integer(),
        label = character(),
        tags = character(),
        filePath = character(),
        hash = character(),
        timestamp = character(),
        stringsAsFactors = FALSE
      )

      for (cohort in matching_cohorts) {
        manifest_df <- rbind(manifest_df, data.frame(
          id = cohort$getId(),
          label = cohort$label,
          tags = cohort$formatTagsAsString(),
          filePath = cohort$getFilePath(),
          hash = cohort$getHash(),
          timestamp = NA_character_,
          stringsAsFactors = FALSE
        ))
      }

      # Get timestamps from database
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      for (i in seq_len(nrow(manifest_df))) {
        cohort_id <- manifest_df$id[i]
        timestamp_record <- DBI::dbGetQuery(
          conn,
          "SELECT timestamp FROM cohort_manifest WHERE id = ?",
          list(cohort_id)
        )
        if (nrow(timestamp_record) > 0) {
          manifest_df$timestamp[i] <- timestamp_record$timestamp[1]
        }
      }

      return(manifest_df)
    },

    #' Get cohorts by label
    #'
    #' @param label Character. The label to search for.
    #' @param matchType Character. Either "exact" for exact match or "pattern" for pattern matching.
    #'   Defaults to "exact".
    #'
    #' @return Data frame. A subset of the manifest with columns id, label, tags, filePath, hash, timestamp for matching cohorts, or NULL if none found.
    getCohortsByLabel = function(label, matchType = c("exact", "pattern")) {
      checkmate::assert_string(x = label, min.chars = 1)
      matchType <- match.arg(matchType)

      matching_cohorts <- list()

      # Search through manifest for matching labels
      for (cohort in private$.manifest) {
        cohort_label <- cohort$label
        
        if (matchType == "exact") {
          if (cohort_label == label) {
            matching_cohorts[[length(matching_cohorts) + 1]] <- cohort
          }
        } else if (matchType == "pattern") {
          # Use grepl for pattern matching (case-insensitive)
          if (grepl(label, cohort_label, ignore.case = TRUE)) {
            matching_cohorts[[length(matching_cohorts) + 1]] <- cohort
          }
        }
      }

      if (length(matching_cohorts) == 0) {
        cli::cli_alert_warning("No cohorts found with {matchType} label match '{label}'")
        return(NULL)
      }

      # Convert matching cohorts to data frame
      manifest_df <- data.frame(
        id = integer(),
        label = character(),
        tags = character(),
        filePath = character(),
        hash = character(),
        timestamp = character(),
        stringsAsFactors = FALSE
      )

      for (cohort in matching_cohorts) {
        manifest_df <- rbind(manifest_df, data.frame(
          id = cohort$getId(),
          label = cohort$label,
          tags = cohort$formatTagsAsString(),
          filePath = cohort$getFilePath(),
          hash = cohort$getHash(),
          timestamp = NA_character_,
          stringsAsFactors = FALSE
        ))
      }

      # Get timestamps from database
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      for (i in seq_len(nrow(manifest_df))) {
        cohort_id <- manifest_df$id[i]
        timestamp_record <- DBI::dbGetQuery(
          conn,
          "SELECT timestamp FROM cohort_manifest WHERE id = ?",
          list(cohort_id)
        )
        if (nrow(timestamp_record) > 0) {
          manifest_df$timestamp[i] <- timestamp_record$timestamp[1]
        }
      }

      return(manifest_df)
    },

    #' Get number of cohorts in manifest
    #'
    #' @return Integer. The number of cohorts.
    nCohorts = function() {
      length(private$.manifest)
    },

    #' Create cohort tables in the database
    #'
    #' @description
    #' Creates the necessary cohort tables in the target database using the execution settings.
    #' First checks if tables already exist before attempting creation.
    #'
    #' @details
    #' Requires that executionSettings has been set and includes:
    #' - A database connection (via getConnection())
    #' - workDatabaseSchema for the target schema
    #' - cohortTable with the desired table name
    #' - tempEmulationSchema if needed for the database platform
    #'
    #' @return Invisible NULL. Creates tables in the database and prints status messages.
    createCohortTables = function() {
      # Validate execution settings
      settings <- private$.executionSettings
      if (is.null(settings)) {
        stop("Execution settings must be set before creating cohort tables")
      }

      # Get execution parameters
      conn <- settings$getConnection()
      if (is.null(conn)) {
        settings$connect()
        conn <- settings$getConnection()
      }
      on.exit(settings$disconnect())
      
      schema <- settings$workDatabaseSchema
      if (is.null(schema) || is.na(schema)) {
        stop("workDatabaseSchema must be set in execution settings")
      }

      cohort_table <- settings$cohortTable
      if (is.null(cohort_table) || is.na(cohort_table)) {
        stop("cohortTable must be set in execution settings")
      }

      temp_schema <- settings$tempEmulationSchema
      dbms <- settings$getDbms()

      # Get cohort table names
      table_names <- getCohortTableNames(
        cohortTable = cohort_table,
        cohortSampleTable = cohort_table,
        cohortInclusionTable = paste0(cohort_table, "_inclusion"),
        cohortInclusionResultTable = paste0(cohort_table, "_inclusion_result"),
        cohortInclusionStatsTable = paste0(cohort_table, "_inclusion_stats"),
        cohortSummaryStatsTable = paste0(cohort_table, "_summary_stats")
      )

      cli::cli_rule("Creating Cohort Tables")
      cli::cli_alert_info("Database: {settings$databaseName}")
      cli::cli_alert_info("Schema: {schema}")
      cli::cli_alert_info("Main table: {cohort_table}")

      tables_to_create <- list(
        main = list(name = cohort_table, type = "main"),
        inclusion = list(name = table_names$cohortInclusionTable, type = "inclusion"),
        inclusion_result = list(name = table_names$cohortInclusionResultTable, type = "inclusion_result"),
        inclusion_stats = list(name = table_names$cohortInclusionStatsTable, type = "inclusion_stats"),
        summary_stats = list(name = table_names$cohortSummaryStatsTable, type = "summary_stats"),
        checksum = list(name = table_names$cohortChecksumTable, type = "checksum")
      )

      # Check for existing tables and create missing ones
      for (table_info in tables_to_create) {
        table_name <- table_info$name
        table_type <- table_info$type

        # Check if table exists
        if (tableExists(conn, schema, table_name, dbms)) {
          cli::cli_alert_warning("{table_type} table already exists: {table_name}")
        } else {
          # Create the table
          if (table_type == "main") {
            sql <- createMainCohortTableSql(schema, table_name, dbms, temp_schema)
          } else if (table_type == "inclusion") {
            sql <- createInclusionTableSql(schema, table_name, dbms)
          } else if (table_type == "inclusion_result") {
            sql <- createInclusionResultTableSql(schema, table_name, dbms)
          } else if (table_type == "inclusion_stats") {
            sql <- createInclusionStatsTableSql(schema, table_name, dbms)
          } else if (table_type == "summary_stats") {
            sql <- createSummaryStatsTableSql(schema, table_name, dbms)
          } else if (table_type == "checksum") {
            sql <- createChecksumTableSql(schema, table_name, dbms)
          }

          tryCatch({
            DatabaseConnector::executeSql(conn, sql, progressBar = FALSE, reportOverallTime = FALSE)
            cli::cli_alert_success("Created {table_type} table: {table_name}")
          }, error = function(e) {
            cli::cli_alert_danger("Failed to create {table_type} table {table_name}: {e$message}")
          })
        }
      }

      cli::cli_rule()
      cli::cli_alert_success("Cohort tables setup complete")

      invisible(NULL)
    },

    #' Generate cohorts in the database
    #'
    #' @description
    #' Generates cohorts in the manifest in the target database using the execution settings.
    #' Checks the hash of each cohort definition and skips generation if the hash matches what's
    #' already stored in the cohort_checksum table. If hashes differ or the cohort is not yet in
    #' the checksum table, regenerates and updates the hash.
    #'
    #' @details
    #' Requires that executionSettings has been set and includes:
    #' - A database connection (via getConnection())
    #' - cdmDatabaseSchema (where the OMOP CDM data resides)
    #' - workDatabaseSchema (where cohort results are written)
    #' - cohortTable (destination table name)
    #' - tempEmulationSchema if needed for the database platform
    #'
    #' @return Data frame with execution results including cohort_id, label, execution_time_ms, and status
    generateCohorts = function() {
      # Validate execution settings
      settings <- private$.executionSettings
      if (is.null(settings)) {
        stop("Execution settings must be set before generating cohorts")
      }

      # Get connection
      conn <- settings$getConnection()
      if (is.null(conn)) {
        settings$connect()
        conn <- settings$getConnection()
      }
      on.exit(settings$disconnect())

      # Get execution parameters
      cdm_schema <- settings$cdmDatabaseSchema
      if (is.null(cdm_schema) || is.na(cdm_schema)) {
        stop("cdmDatabaseSchema must be set in execution settings")
      }

      cohort_schema <- settings$workDatabaseSchema
      if (is.null(cohort_schema) || is.na(cohort_schema)) {
        stop("workDatabaseSchema must be set in execution settings")
      }

      cohort_table <- settings$cohortTable
      if (is.null(cohort_table) || is.na(cohort_table)) {
        stop("cohortTable must be set in execution settings")
      }

      temp_schema <- settings$tempEmulationSchema
      dbms <- settings$getDbms()

      # Get checksum table name
      table_names <- getCohortTableNames(cohortTable = cohort_table)
      checksum_table <- table_names$cohortChecksumTable

      cli::cli_rule("Generating Cohorts")
      cli::cli_alert_info("Database: {settings$databaseName}")
      cli::cli_alert_info("CDM Schema: {cdm_schema}")
      cli::cli_alert_info("Cohort Schema: {cohort_schema}")
      cli::cli_alert_info("Cohort Table: {cohort_table}")
      cli::cli_alert_info("Generating {length(private$.manifest)} cohorts...\n")

      # Initialize results data frame
      results_df <- data.frame(
        cohort_id = integer(),
        label = character(),
        execution_time_ms = numeric(),
        status = character(),
        stringsAsFactors = FALSE
      )

      # Check if checksum table is empty
      checksum_query <- paste0("SELECT COUNT(*) as count FROM ", cohort_schema, ".", checksum_table)
      checksum_count_result <- try(DatabaseConnector::querySql(conn, checksum_query), silent = TRUE)
      is_checksum_empty <- inherits(checksum_count_result, "try-error") || 
                           (nrow(checksum_count_result) > 0 && checksum_count_result$COUNT[1] == 0)

      # Generate each cohort
      for (i in seq_along(private$.manifest)) {
        cohort <- private$.manifest[[i]]
        cohort_id <- cohort$getId()
        cohort_label <- cohort$label
        current_hash <- cohort$getHash()

        # Check if we should skip this cohort based on hash
        should_skip <- FALSE
        stored_hash <- NULL

        if (!is_checksum_empty) {
          # Query the stored hash for this cohort
          hash_query <- paste0(
            "SELECT checksum FROM ", cohort_schema, ".", checksum_table,
            " WHERE cohort_definition_id = ", cohort_id
          )
          hash_result <- try(DatabaseConnector::querySql(conn, hash_query), silent = TRUE)

          if (!inherits(hash_result, "try-error") && nrow(hash_result) > 0) {
            stored_hash <- hash_result$CHECKSUM[1]
            if (!is.na(stored_hash) && stored_hash == current_hash) {
              should_skip <- TRUE
            }
          }
        }

        # Log decision
        if (should_skip) {
          cli::cli_alert_info("Skipping cohort {cohort_id}: {cohort_label} (hash unchanged)")
          results_df <- rbind(results_df, data.frame(
            cohort_id = cohort_id,
            label = cohort_label,
            execution_time_ms = 0,
            status = "Skipped - already generated",
            stringsAsFactors = FALSE
          ))
          next
        }

        # Generate the cohort
        cli::cli_alert_info("Generating cohort {cohort_id}: {cohort_label}...")

        # Get the SQL from the cohort entry
        cohort_sql <- cohort$getSql()

        # Render the SQL with required parameters
        rendered_sql <- SqlRender::render(
          sql = cohort_sql,
          cdm_database_schema = cdm_schema,
          target_database_schema = cohort_schema,
          target_cohort_table = cohort_table,
          target_cohort_id = cohort_id
        )

        # Translate to target dialect
        translated_sql <- SqlRender::translate(
          sql = rendered_sql,
          targetDialect = dbms,
          tempEmulationSchema = temp_schema
        )

        # Execute and time it
        start_time <- Sys.time()
        result <- try({
          DatabaseConnector::executeSql(
            conn,
            translated_sql,
            progressBar = FALSE,
            reportOverallTime = FALSE
          )
        }, silent = TRUE)

        # Check if execution failed
        if (inherits(result, "try-error")) {
          end_time <- Sys.time()
          execution_time_ms <- as.numeric(difftime(end_time, start_time, units = "secs")) * 1000
          error_msg <- as.character(result)

          cli::cli_alert_danger("Failed to generate cohort {cohort_id}: {cohort_label}")
          cli::cli_alert_danger("Error: {error_msg}")

          # Add the failed cohort to results
          results_df <- rbind(results_df, data.frame(
            cohort_id = cohort_id,
            label = cohort_label,
            execution_time_ms = execution_time_ms,
            status = paste("Error:", error_msg),
            stringsAsFactors = FALSE
          ))

          # Add "Not generated" for remaining cohorts
          if (i < length(private$.manifest)) {
            for (j in (i + 1):length(private$.manifest)) {
              remaining_cohort <- private$.manifest[[j]]
              results_df <- rbind(results_df, data.frame(
                cohort_id = remaining_cohort$getId(),
                label = remaining_cohort$label,
                execution_time_ms = NA_real_,
                status = "Not generated",
                stringsAsFactors = FALSE
              ))
            }
          }

          # Stop with informative error message identifying the failed cohort
          stop("Cohort generation stopped at cohort ", cohort_id, " (", cohort_label, "): ", error_msg)
        }

        # Success path
        end_time <- Sys.time()
        execution_time_ms <- as.numeric(difftime(end_time, start_time, units = "secs")) * 1000

        # Update or insert checksum
        if (is.null(stored_hash)) {
          # Insert new checksum record
          insert_sql <- paste0(
            "INSERT INTO ", cohort_schema, ".", checksum_table,
            " (cohort_definition_id, checksum, generated_at) VALUES (",
            cohort_id, ", '", current_hash, "', ", 
            "CAST('", format(Sys.time(), '%Y-%m-%d %H:%M:%S'), "' AS DATETIME))"
          )
        } else {
          # Update existing checksum record
          insert_sql <- paste0(
            "UPDATE ", cohort_schema, ".", checksum_table,
            " SET checksum = '", current_hash, "', ",
            "generated_at = CAST('", format(Sys.time(), '%Y-%m-%d %H:%M:%S'), "' AS DATETIME)",
            " WHERE cohort_definition_id = ", cohort_id
          )
        }

        # Execute checksum update
        try(DatabaseConnector::executeSql(
          conn,
          insert_sql,
          progressBar = FALSE,
          reportOverallTime = FALSE
        ), silent = TRUE)

        cli::cli_alert_success("Generated cohort {cohort_id}: {cohort_label} ({execution_time_ms |> round(2)}ms)")

        results_df <- rbind(results_df, data.frame(
          cohort_id = cohort_id,
          label = cohort_label,
          execution_time_ms = execution_time_ms,
          status = "Success",
          stringsAsFactors = FALSE
        ))
      }

      cli::cli_rule()
      total_time_ms <- sum(results_df$execution_time_ms[results_df$status == "Success"], na.rm = TRUE)
      successful <- sum(results_df$status == "Success")
      skipped <- sum(results_df$status == "Skipped - already generated")
      failed <- sum(grepl("Error:", results_df$status))

      cli::cli_alert_success("Cohort generation complete")
      cli::cli_alert_info("Total cohorts: {nrow(results_df)} | Successful: {successful} | Skipped: {skipped} | Failed: {failed}")
      cli::cli_alert_info("Total execution time: {total_time_ms |> round(2)}ms ({(total_time_ms/1000) |> round(2)}s)")

      return(results_df)
    }
  )
)


# helpers -------------

#' Check if a table exists in the database
#'
#' @description Checks whether a table exists in the specified schema
#'
#' @param connection DatabaseConnector connection object
#' @param schema Character. Database schema name
#' @param tableName Character. Table name to check
#' @param dbms Character. Database management system type
#'
#' @return Logical. TRUE if table exists, FALSE otherwise
#'
tableExists <- function(connection, schema, tableName, dbms) {
  tryCatch({
    query <- paste0("SELECT COUNT(*) FROM ", schema, ".", tableName, " WHERE 1=0")
    result <- DatabaseConnector::querySql(connection, query)
    return(TRUE)
  }, error = function(e) {
    return(FALSE)
  })
}

#' Create main cohort table SQL
#'
#' @description Generates SQL to create the main cohort table
#'
#' @param schema Character. Database schema name
#' @param tableName Character. Table name
#' @param dbms Character. Database management system type
#' @param tempEmulationSchema Character. Temp emulation schema if needed
#'
#' @return Character. SQL statement
#'
createMainCohortTableSql <- function(schema, tableName, dbms, tempEmulationSchema = NULL) {
  sql <- "CREATE TABLE @schema.@table_name (
    cohort_definition_id BIGINT,
    subject_id BIGINT,
    cohort_start_date DATE,
    cohort_end_date DATE
  );"

  sql <- SqlRender::render(
    sql = sql,
    schema = schema,
    table_name = tableName
  )

  sql <- SqlRender::translate(
    sql = sql,
    targetDialect = dbms,
    tempEmulationSchema = tempEmulationSchema
  )

  return(sql)
}

#' Create inclusion table SQL
#'
#' @description Generates SQL to create the inclusion table
#'
#' @param schema Character. Database schema name
#' @param tableName Character. Table name
#' @param dbms Character. Database management system type
#'
#' @return Character. SQL statement
#'
createInclusionTableSql <- function(schema, tableName, dbms) {
  sql <- "CREATE TABLE @schema.@table_name (
    cohort_definition_id INT,
    inclusion_sequence INT,
    inclusion_name VARCHAR(255)
  );"

  sql <- SqlRender::render(
    sql = sql,
    schema = schema,
    table_name = tableName
  )

  sql <- SqlRender::translate(
    sql = sql,
    targetDialect = dbms
  )

  return(sql)
}

#' Create inclusion result table SQL
#'
#' @description Generates SQL to create the inclusion result table
#'
#' @param schema Character. Database schema name
#' @param tableName Character. Table name
#' @param dbms Character. Database management system type
#'
#' @return Character. SQL statement
#'
createInclusionResultTableSql <- function(schema, tableName, dbms) {
  sql <- "CREATE TABLE @schema.@table_name (
    cohort_definition_id INT,
    inclusion_sequence INT,
    subject_id INT,
    inclusion_rule_was_met INT
  );"

  sql <- SqlRender::render(
    sql = sql,
    schema = schema,
    table_name = tableName
  )

  sql <- SqlRender::translate(
    sql = sql,
    targetDialect = dbms
  )

  return(sql)
}

#' Create inclusion stats table SQL
#'
#' @description Generates SQL to create the inclusion stats table
#'
#' @param schema Character. Database schema name
#' @param tableName Character. Table name
#' @param dbms Character. Database management system type
#'
#' @return Character. SQL statement
#'
createInclusionStatsTableSql <- function(schema, tableName, dbms) {
  sql <- "CREATE TABLE @schema.@table_name (
    cohort_definition_id INT,
    rule_sequence INT,
    name VARCHAR(255),
    person_count INT,
    gain_count INT,
    person_total INT
  );"

  sql <- SqlRender::render(
    sql = sql,
    schema = schema,
    table_name = tableName
  )

  sql <- SqlRender::translate(
    sql = sql,
    targetDialect = dbms
  )

  return(sql)
}

#' Create summary stats table SQL
#'
#' @description Generates SQL to create the summary stats table
#'
#' @param schema Character. Database schema name
#' @param tableName Character. Table name
#' @param dbms Character. Database management system type
#'
#' @return Character. SQL statement
#'
createSummaryStatsTableSql <- function(schema, tableName, dbms) {
  sql <- "CREATE TABLE @schema.@table_name (
    cohort_definition_id INT,
    base_count INT,
    final_count INT,
    rule_count INT
  );"

  sql <- SqlRender::render(
    sql = sql,
    schema = schema,
    table_name = tableName
  )

  sql <- SqlRender::translate(
    sql = sql,
    targetDialect = dbms
  )

  return(sql)
}

#' Create checksum table SQL
#'
#' @description Generates SQL to create the cohort checksum table for tracking cohort definition hashes
#'
#' @param schema Character. Database schema name
#' @param tableName Character. Table name
#' @param dbms Character. Database management system type
#'
#' @return Character. SQL statement
#'
createChecksumTableSql <- function(schema, tableName, dbms) {
  sql <- "CREATE TABLE @schema.@table_name (
    cohort_definition_id INT PRIMARY KEY,
    checksum VARCHAR(128),
    generated_at DATETIME
  );"

  sql <- SqlRender::render(
    sql = sql,
    schema = schema,
    table_name = tableName
  )

  sql <- SqlRender::translate(
    sql = sql,
    targetDialect = dbms
  )

  return(sql)
}

#' Get cohort table names
#'
#' @description Creates a list of standard cohort table names
#'
#' @param cohortTable Character. Base name for the cohort table
#' @param cohortSampleTable Character. Name for the sample table
#' @param cohortInclusionTable Character. Name for the inclusion table
#' @param cohortInclusionResultTable Character. Name for the inclusion result table
#' @param cohortInclusionStatsTable Character. Name for the inclusion stats table
#' @param cohortSummaryStatsTable Character. Name for the summary stats table
#' @param cohortCensorStatsTable Character. Name for the censor stats table
#' @param cohortSubsetAttritionTable Character. Name for the subset attrition table
#' @param cohortChecksumTable Character. Name for the checksum table
#'
#' @return List containing all table names
#'
getCohortTableNames <- function(cohortTable = "cohort",
                                cohortSampleTable = cohortTable,
                                cohortInclusionTable = paste0(cohortTable, "_inclusion"),
                                cohortInclusionResultTable = paste0(cohortTable, "_inclusion_result"),
                                cohortInclusionStatsTable = paste0(cohortTable, "_inclusion_stats"),
                                cohortSummaryStatsTable = paste0(cohortTable, "_summary_stats"),
                                cohortCensorStatsTable = paste0(cohortTable, "_censor_stats"),
                                cohortSubsetAttritionTable = paste0(cohortTable, "_subset_attrition"),
                                cohortChecksumTable = paste0(cohortTable, "_checksum")) {
  return(list(
    cohortTable = cohortTable,
    cohortSampleTable = cohortSampleTable,
    cohortInclusionTable = cohortInclusionTable,
    cohortInclusionResultTable = cohortInclusionResultTable,
    cohortInclusionStatsTable = cohortInclusionStatsTable,
    cohortSummaryStatsTable = cohortSummaryStatsTable,
    cohortCensorStatsTable = cohortCensorStatsTable,
    cohortSubsetAttritionTable = cohortSubsetAttritionTable,
    cohortChecksumTable = cohortChecksumTable
  ))
}
