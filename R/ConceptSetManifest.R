#' ConceptSetDef R6 Class
#'
#' An R6 class that stores key information about OHDSI CIRCE concept sets that need to be
#' managed in a study.
#'
#' @details
#' The ConceptSetDef class manages concept set metadata, JSON definitions, and domain information.
#' Upon initialization, it loads and validates concept set definitions from CIRCE JSON files,
#' creates a hash to uniquely identify the generated JSON, and stores domain and source concept information.
#'
#' @export
ConceptSetDef <- R6::R6Class(
  classname = "ConceptSetDef",
  private = list(
    .label = NULL,
    .tags = NULL,
    .filePath = NULL,
    .json = NULL,
    .hash = NULL,
    .id = NULL,

    # Load JSON from file
    load_json_from_file = function(filePath) {
      if (!file.exists(filePath)) {
        stop("File does not exist: ", filePath)
      }

      file_ext <- tolower(tools::file_ext(filePath))

      if (file_ext != "json") {
        stop("Concept set file must be .json, got: .", file_ext)
      }

      # Load and validate JSON as CIRCE concept set
      json_content <- readr::read_file(filePath)

      # Validate JSON is valid CIRCE using CirceR
      tryCatch(
        CirceR::conceptSetExpressionFromJson(json_content),
        error = function(e) {
          stop("JSON file is not valid CIRCE concept set format: ", filePath, "\nError: ", e$message)
        }
      )

      # Store JSON string
      private$.json <- json_content

      # Create hash of JSON string
      private$.hash <- rlang::hash(private$.json)
    }
  ),

  public = list(
    #' @description Initialize a new ConceptSetDef
    #'
    #' @param label Character. The common name of the concept set.
    #' @param tags List. A named list of tags that give metadata about the concept set.
    #' @param filePath Character. Path to the concept set JSON file in inputs/conceptSet folder.
    #' @param sourceCode Logical. Whether the concept set uses source concepts (TRUE) or standard concepts (FALSE).
    #' @param domain Character. The OMOP CDM clinical domain for this concept set. 
    #'   Valid values: "drug_exposure", "condition_occurrence", "measurement", "procedure", "observation", "device_exposure", "visit_occurrence", "init".
    initialize = function(label, tags = list(), filePath, domain = "init") {
      checkmate::assert_string(x = label, min.chars = 1)
      checkmate::assert_list(x = tags, names = "named")
      checkmate::assert_file_exists(x = filePath)

      # Validate domain
      valid_domains <- c("drug_exposure", "condition_occurrence", "measurement", "procedure", 
        "observation", "device_exposure", "visit_occurrence", "init")
      if (!(domain %in% valid_domains)) {
        stop("Invalid domain '", domain, "'. Valid domains: ", paste(valid_domains, collapse = ", "))
      }
      tags <- c(tags, list(domain = domain))
      private$.label <- label
      private$.tags <- tags
      private$.filePath <- filePath

      # Load JSON and generate hash
      private$load_json_from_file(filePath)

      # Concept set ID will be assigned later when listed within the ConceptSetManifest
      private$.id <- NA_integer_
    },

    #' Get the file path
    #'
    #' @return Character. Relative path to the concept set file.
    getFilePath = function() {
      fs::path_rel(private$.filePath)
    },

    #' Get the concept set JSON
    #'
    #' @return Character. The JSON definition of the concept set.
    getJson = function() {
      private$.json
    },

    #' Get the JSON hash
    #'
    #' @return Character. MD5 hash of the current JSON definition.
    getHash = function() {
      private$.hash
    },

    #' Get the concept set ID
    #'
    #' @return Integer. The concept set ID, or NA_integer_ if not set.
    getId = function() {
      private$.id
    },

    #' Set the concept set ID (internal use)
    #'
    #' @param id Integer. The concept set ID to set.
    setId = function(id) {
      checkmate::assert_int(x = id)
      private$.id <- id
    },

    #' Format tags as string
    #'
    #' @return Character. Tags formatted as "name: value | name: value".
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
    #' @field label character to set the label to. If missing, returns the current label.
    label = function(label) {
      if (missing(label)) {
        private[[".label"]]
      } else {
        checkmate::assert_string(x = label, min.chars = 1)
        private[[".label"]] <- label
      }
    },

    #' @field tags list of the values to set the tags to. If missing, returns the current tags.
    tags = function(tags) {
      if (missing(tags)) {
        private[[".tags"]]
      } else {
        checkmate::assert_list(x = tags, names = "named")
        private[[".tags"]] <- tags
      }
    }
  )
)

#' ConceptSetManifest R6 Class
#'
#' An R6 class that manages a collection of ConceptSetDef objects and maintains
#' metadata in a SQLite database.
#'
#' @details
#' The ConceptSetManifest class manages multiple concept set definitions and stores their
#' metadata in a SQLite database located at inputs/conceptSets/conceptSetManifest.sqlite.
#' Each ConceptSetDef is assigned a sequential ID based on its position in the manifest.
#'
#' @export
ConceptSetManifest <- R6::R6Class(
  classname = "ConceptSetManifest",
  private = list(
    .manifest = NULL,
    .dbPath = NULL,
    .executionSettings = NULL,

    # Initialize the SQLite database
    init_manifest = function(dbPath) {
      # Create inputs/conceptSets directory if it doesn't exist
      dbDir <- dirname(dbPath)
      if (!dir.exists(dbDir)) {
        dir.create(dbDir, recursive = TRUE, showWarnings = FALSE)
      }

      # Check if database file already exists
      db_exists <- file.exists(dbPath)

      # Create concept set table only if manifest is new
      if (!db_exists) {
        # Connect to manifest (creates if doesn't exist)
        cli::cat_bullet(
            glue::glue("Initializing concept set manifest at {dbPath}."), 
            bullet = "info",
            bullet_col = "blue"
        )
        conn <- DBI::dbConnect(RSQLite::SQLite(), dbPath)
        DBI::dbExecute(
          conn,
          "CREATE TABLE IF NOT EXISTS concept_set_manifest (
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
            glue::glue("Concept set manifest already exists at {dbPath}."), 
            bullet = "warning",
            bullet_col = "yellow"
        )
      }
    },

    # Populate the manifest with concept set entries
    populate_manifest = function(manifest) {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      # Check if table is empty
      existing_count <- DBI::dbGetQuery(
        conn,
        "SELECT COUNT(*) as count FROM concept_set_manifest"
      )$count

      if (existing_count == 0) {
        # Table is empty, insert all concept set entries
        cli::cli_alert_info("Concept set manifest table is empty. Inserting {length(manifest)} concept set entries...")
        
        for (i in seq_along(manifest)) {
          concept_set <- manifest[[i]]

          DBI::dbExecute(
            conn,
            "INSERT INTO concept_set_manifest (id, label, tags, filePath, hash, timestamp) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)",
            list(
              concept_set$getId(),
              concept_set$label,
              concept_set$formatTagsAsString(),
              concept_set$getFilePath(),
              concept_set$getHash()
            )
          )
          
          cli::cli_alert_success("Inserted concept set {concept_set$getId()}: {concept_set$label}")
        }
        
        cli::cli_alert_success("Successfully loaded {length(manifest)} concept sets into manifest")
      } else {
        # Table has existing entries, check for hash changes
        cli::cli_alert_info("Checking {length(manifest)} concept sets against existing manifest ({existing_count} entries)...")
        
        updated_count <- 0
        new_count <- 0
        unchanged_count <- 0
        
        for (i in seq_along(manifest)) {
          concept_set <- manifest[[i]]
          cs_id <- concept_set$getId()
          new_hash <- concept_set$getHash()

          # Get existing hash from database
          existing_record <- DBI::dbGetQuery(
            conn,
            "SELECT hash FROM concept_set_manifest WHERE id = ?",
            list(cs_id)
          )

          if (nrow(existing_record) == 0) {
            # New concept set entry, insert it
            DBI::dbExecute(
              conn,
              "INSERT INTO concept_set_manifest (id, label, tags, filePath, hash, timestamp) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)",
              list(
                cs_id,
                concept_set$label,
                concept_set$formatTagsAsString(),
                concept_set$getFilePath(),
                new_hash
              )
            )
            
            cli::cli_alert_info("New concept set {cs_id}: {concept_set$label}")
            new_count <- new_count + 1
          } else if (existing_record$hash[1] != new_hash) {
            # Hash has changed, update the record and timestamp
            DBI::dbExecute(
              conn,
              "UPDATE concept_set_manifest SET label = ?, tags = ?, filePath = ?, hash = ?, timestamp = CURRENT_TIMESTAMP WHERE id = ?",
              list(
                concept_set$label,
                concept_set$formatTagsAsString(),
                concept_set$getFilePath(),
                new_hash,
                cs_id
              )
            )
            
            cli::cli_alert_warning("Updated concept set {cs_id}: {concept_set$label} (JSON hash changed)")
            updated_count <- updated_count + 1
          } else {
            # Hash hasn't changed
            cli::cli_alert_success("Unchanged concept set {cs_id}: {concept_set$label}")
            unchanged_count <- unchanged_count + 1
          }
        }
        
        cli::cli_rule("Concept Set Manifest Update Summary")
        cli::cli_alert_success("Updated: {updated_count} | New: {new_count} | Unchanged: {unchanged_count}")
      }
    },

    # Suggest source vocabularies based on domain
    suggest_source_vocabs_for_domain = function(domain) {
      vocab_map <- list(
        condition_occurrence = c("ICD10CM", "ICD9CM"),
        procedure = c("HCPCS", "CPT4"),
        measurement = c("LOINC"),
        drug_exposure = c("NDC"),
        observation = c("ICD9CM", "ICD10CM", "HCPCS", "CPT4", "LOINC", "NDC"),
        device_exposure = c("NDC"),
        visit_occurrence = c("ICD10CM", "ICD9CM", "HCPCS", "CPT4"),
        init = c("ICD10CM")
      )
      
      if (domain %in% names(vocab_map)) {
        return(vocab_map[[domain]])
      } else {
        return(NULL)
      }
    }
  ),

  public = list(
    #' @description Initialize a new ConceptSetManifest
    #'
    #' @param conceptSetEntries List. A list of ConceptSetDef objects.
    #' @param executionSettings Object. (Optional) Execution settings for accessing the vocabulary database.
    #'   Can be any object type containing configuration for vocabulary queries.
    #' @param dbPath Character. Path to the SQLite database. Defaults to
    #'   "inputs/conceptSets/conceptSetManifest.sqlite"
    initialize = function(conceptSetEntries, executionSettings = NULL, dbPath = "inputs/conceptSets/conceptSetManifest.sqlite") {
      # Validate input is a list
      checkmate::assert_list(x = conceptSetEntries, min.len = 1)

      # Validate all elements are ConceptSetDef objects
      valid_entries <- all(sapply(conceptSetEntries, function(x) {
        inherits(x, "ConceptSetDef")
      }))

      if (!valid_entries) {
        stop("All elements in conceptSetEntries must be ConceptSetDef objects")
      }

      # Assign IDs to each concept set entry
      for (i in seq_along(conceptSetEntries)) {
        conceptSetEntries[[i]]$setId(as.integer(i))
      }

      private$.manifest <- conceptSetEntries
      private$.dbPath <- dbPath

      checkmate::assert_class(x = executionSettings, classes = "ExecutionSettings", null.ok = TRUE)
      private$.executionSettings <- executionSettings

      # Initialize and populate manifest
      private$init_manifest(dbPath)
      private$populate_manifest(conceptSetEntries)
    },

    #' Get the manifest as a data frame
    #'
    #' @return Data frame. The manifest with id, label, tags, filePath, hash, and timestamp columns.
    getManifest = function() {
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))
      man <- DBI::dbGetQuery(
          conn, "SELECT id, label, tags, filePath, hash, timestamp FROM concept_set_manifest ORDER BY id"
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
    #' @return Object. The execution settings object for vocabulary access, or NULL if not set.
    getExecutionSettings = function() {
      private$.executionSettings
    },

    #' Get a specific concept set by ID
    #'
    #' @param id Integer. The concept set ID.
    #'
    #' @return Data frame. A subset of the manifest with columns id, label, tags, filePath,  hash, timestamp for the requested concept set.
    getConceptSetById = function(id) {
      checkmate::assert_int(x = id)

      concept_set_obj <- NULL
      for (concept_set in private$.manifest) {
        if (concept_set$getId() == id) {
          concept_set_obj <- concept_set
          break
        }
      }

      if (is.null(concept_set_obj)) {
        stop("Concept set with ID ", id, " not found")
      }

      # Get timestamp from database
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      timestamp_record <- DBI::dbGetQuery(
        conn,
        "SELECT timestamp FROM concept_set_manifest WHERE id = ?",
        list(id)
      )

      timestamp <- if (nrow(timestamp_record) > 0) {
        timestamp_record$timestamp[1]
      } else {
        NA_character_
      }

      # Return as data frame
      data.frame(
        id = concept_set_obj$getId(),
        label = concept_set_obj$label,
        tags = concept_set_obj$formatTagsAsString(),
        filePath = concept_set_obj$getFilePath(),
        hash = concept_set_obj$getHash(),
        timestamp = timestamp,
        stringsAsFactors = FALSE
      )
    },

    #' Get concept sets by tag
    #'
    #' @param tagString Character. A tag in the format "name: value" (e.g., "category: primary").
    #'
    #' @return Data frame. A subset of the manifest with matching tags, or NULL if none found.
    getConceptSetsByTag = function(tagString) {
      checkmate::assert_string(x = tagString, min.chars = 1)

      # Parse the tag string to extract name and value
      tag_parts <- strsplit(tagString, ":\\s*")[[1]]
      if (length(tag_parts) != 2) {
        stop("Tag must be in the format 'name: value'")
      }

      tag_name <- trimws(tag_parts[1])
      tag_value <- trimws(tag_parts[2])

      matching_concept_sets <- list()

      # Search through manifest for matching tags
      for (concept_set in private$.manifest) {
        cs_tags <- concept_set$tags
        if (!is.null(cs_tags) && tag_name %in% names(cs_tags)) {
          if (cs_tags[[tag_name]] == tag_value) {
            matching_concept_sets[[length(matching_concept_sets) + 1]] <- concept_set
          }
        }
      }

      if (length(matching_concept_sets) == 0) {
        cli::cli_alert_warning("No concept sets found with tag '{tag_name}: {tag_value}'")
        return(NULL)
      }

      # Convert matching concept sets to data frame
      manifest_df <- data.frame(
        id = integer(),
        label = character(),
        tags = character(),
        filePath = character(),
        hash = character(),
        timestamp = character(),
        stringsAsFactors = FALSE
      )

      for (concept_set in matching_concept_sets) {
        manifest_df <- rbind(manifest_df, data.frame(
          id = concept_set$getId(),
          label = concept_set$label,
          tags = concept_set$formatTagsAsString(),
          filePath = concept_set$getFilePath(),
          hash = concept_set$getHash(),
          timestamp = NA_character_,
          stringsAsFactors = FALSE
        ))
      }

      # Get timestamps from database
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      for (i in seq_len(nrow(manifest_df))) {
        cs_id <- manifest_df$id[i]
        timestamp_record <- DBI::dbGetQuery(
          conn,
          "SELECT timestamp FROM concept_set_manifest WHERE id = ?",
          list(cs_id)
        )
        if (nrow(timestamp_record) > 0) {
          manifest_df$timestamp[i] <- timestamp_record$timestamp[1]
        }
      }

      return(manifest_df)
    },

    #' Get concept sets by label
    #'
    #' @param label Character. The label to search for.
    #' @param matchType Character. Either "exact" for exact match or "pattern" for pattern matching.
    #'   Defaults to "exact".
    #'
    #' @return Data frame. A subset of the manifest with matching labels, or NULL if none found.
    getConceptSetsByLabel = function(label, matchType = c("exact", "pattern")) {
      checkmate::assert_string(x = label, min.chars = 1)
      matchType <- match.arg(matchType)

      matching_concept_sets <- list()

      # Search through manifest for matching labels
      for (concept_set in private$.manifest) {
        cs_label <- concept_set$label
        
        if (matchType == "exact") {
          if (cs_label == label) {
            matching_concept_sets[[length(matching_concept_sets) + 1]] <- concept_set
          }
        } else if (matchType == "pattern") {
          # Use grepl for pattern matching (case-insensitive)
          if (grepl(label, cs_label, ignore.case = TRUE)) {
            matching_concept_sets[[length(matching_concept_sets) + 1]] <- concept_set
          }
        }
      }

      if (length(matching_concept_sets) == 0) {
        cli::cli_alert_warning("No concept sets found with {matchType} label match '{label}'")
        return(NULL)
      }

      # Convert matching concept sets to data frame
      manifest_df <- data.frame(
        id = integer(),
        label = character(),
        tags = character(),
        filePath = character(),
        hash = character(),
        timestamp = character(),
        stringsAsFactors = FALSE
      )

      for (concept_set in matching_concept_sets) {
        manifest_df <- rbind(manifest_df, data.frame(
          id = concept_set$getId(),
          label = concept_set$label,
          tags = concept_set$formatTagsAsString(),
          filePath = concept_set$getFilePath(),
          hash = concept_set$getHash(),
          timestamp = NA_character_,
          stringsAsFactors = FALSE
        ))
      }

      # Get timestamps from database
      conn <- DBI::dbConnect(RSQLite::SQLite(), private$.dbPath)
      on.exit(DBI::dbDisconnect(conn))

      for (i in seq_len(nrow(manifest_df))) {
        cs_id <- manifest_df$id[i]
        timestamp_record <- DBI::dbGetQuery(
          conn,
          "SELECT timestamp FROM concept_set_manifest WHERE id = ?",
          list(cs_id)
        )
        if (nrow(timestamp_record) > 0) {
          manifest_df$timestamp[i] <- timestamp_record$timestamp[1]
        }
      }

      return(manifest_df)
    },

    #' @description Get number of concept sets in manifest
    #'
    #' @return Integer. The number of concept sets.
    nConceptSets = function() {
      length(private$.manifest)
    },

    #' Grab a specific concept set by ID
    #'
    #' @param id Integer. The concept set ID.
    #'
    #' @return ConceptSetDef. The ConceptSetDef object with matching ID, or NULL if not found.
    grabConceptSetById = function(id) {
      checkmate::assert_int(x = id)

      for (concept_set in private$.manifest) {
        if (concept_set$getId() == id) {
          return(concept_set)
        }
      }

      cli::cli_alert_warning("Concept set with ID {id} not found")
      return(NULL)
    },

    #' Grab concept sets by tag
    #'
    #' @param tagString Character. A tag in the format "name: value" (e.g., "category: primary").
    #'
    #' @return List. A list of ConceptSetDef objects with matching tags, or NULL if none found.
    grabConceptSetsByTag = function(tagString) {
      checkmate::assert_string(x = tagString, min.chars = 1)

      # Parse the tag string to extract name and value
      tag_parts <- strsplit(tagString, ":\\s*")[[1]]
      if (length(tag_parts) != 2) {
        stop("Tag must be in the format 'name: value'")
      }

      tag_name <- trimws(tag_parts[1])
      tag_value <- trimws(tag_parts[2])

      matching_concept_sets <- list()

      # Search through manifest for matching tags
      for (concept_set in private$.manifest) {
        cs_tags <- concept_set$tags
        if (!is.null(cs_tags) && tag_name %in% names(cs_tags)) {
          if (cs_tags[[tag_name]] == tag_value) {
            matching_concept_sets[[length(matching_concept_sets) + 1]] <- concept_set
          }
        }
      }

      if (length(matching_concept_sets) == 0) {
        cli::cli_alert_warning("No concept sets found with tag '{tag_name}: {tag_value}'")
        return(NULL)
      }

      return(matching_concept_sets)
    },

    #' Grab concept sets by label
    #'
    #' @param label Character. The label to search for.
    #' @param matchType Character. Either "exact" for exact match or "pattern" for pattern matching.
    #'   Defaults to "exact".
    #'
    #' @return List. A list of ConceptSetDef objects with matching labels, or NULL if none found.
    grabConceptSetsByLabel = function(label, matchType = c("exact", "pattern")) {
      checkmate::assert_string(x = label, min.chars = 1)
      matchType <- match.arg(matchType)

      matching_concept_sets <- list()

      # Search through manifest for matching labels
      for (concept_set in private$.manifest) {
        cs_label <- concept_set$label

        if (matchType == "exact") {
          if (cs_label == label) {
            matching_concept_sets[[length(matching_concept_sets) + 1]] <- concept_set
          }
        } else if (matchType == "pattern") {
          # Use grepl for pattern matching (case-insensitive)
          if (grepl(label, cs_label, ignore.case = TRUE)) {
            matching_concept_sets[[length(matching_concept_sets) + 1]] <- concept_set
          }
        }
      }

      if (length(matching_concept_sets) == 0) {
        cli::cli_alert_warning("No concept sets found with {matchType} label match '{label}'")
        return(NULL)
      }

      return(matching_concept_sets)
    },

    #' Extract Source Codes for Concept Sets
    #'
    #' Finds source codes that map to each concept set's standard concepts
    #' based on a defined source vocabulary. Results are exported to a single
    #' xlsx file with one sheet per concept set, saved in the inputs/conceptSets folder.
    #'
    #' @param sourceVocabs Character vector. Source vocabulary IDs to search for.
    #'   Valid options: "ICD9CM", "ICD10CM", "HCPCS", "CPT4", "LOINC", "NDC".
    #'   Defaults to c("ICD10CM").
    #' @param outputFolder Character. Path where the xlsx file will be saved.
    #'   Defaults to "inputs/conceptSets".
    #'
    #' @details
    #' **Vocabulary Suggestion by Domain:**
    #' The function automatically suggests appropriate vocabularies based on concept set domains:
    #' - `condition_occurrence`: ICD10CM, ICD9CM
    #' - `procedure`: HCPCS, CPT4
    #' - `measurement`: LOINC
    #' - `drug_exposure`: NDC
    #' - `observation`: All vocabularies (ICD9CM, ICD10CM, HCPCS, CPT4, LOINC, NDC)
    #' - `device_exposure`: NDC
    #'
    #' Note: These are suggestions only. You can override with any valid vocabulary combination.
    #'
    #' **Workflow:**
    #' 1. Detects domains of all concept sets in the manifest
    #' 2. Displays suggested vocabularies based on detected domains
    #' 3. Creates a single xlsx workbook
    #' 4. For each concept set in the manifest:
    #'    - Reads the CIRCE JSON definition
    #'    - Builds a concept query using CirceR
    #'    - Joins with concept_relationship via "Maps to" relationship
    #'    - Finds matching source codes in the specified vocabularies
    #'    - Adds results to a new sheet in the xlsx workbook
    #' 5. Exports all results to `{outputFolder}/SourceCodeMap_{vocabs}.xlsx`
    #' 6. Each sheet contains: vocabulary_id, concept_code, concept_name
    #'
    #' **Requirements:**
    #' - ExecutionSettings must be initialized with a valid connection
    #' - Vocabulary schema must be accessible from ExecutionSettings
    #' - openxlsx2 package must be installed
    #'
    #' @return Invisibly returns NULL. Saves xlsx file to outputFolder and prints status messages.
    #'
    #' @export
    #'
    #' @examples
    #' \dontrun{
    #'   # Get source codes for all concept sets in single xlsx with multiple sheets
    #'   settings <- createExecutionSettings(...)
    #'   manifest <- loadConceptSetManifest(settings)
    #'   manifest$extractSourceCodes(
    #'     sourceVocabs = c("ICD10CM", "ICD9CM")
    #'   )
    #'   # Saves SourceCodeMap_ICD10CM_ICD9CM.xlsx to inputs/conceptSets
    #' }
    #'
    extractSourceCodes = function(sourceVocabs = c("ICD10CM"),
                                  outputFolder = here::here("inputs/conceptSets")) {
      # Validate executionSettings is available
      if (is.null(private$.executionSettings)) {
        stop("ExecutionSettings is required to extract source codes. Initialize manifest with valid ExecutionSettings.")
      }

      # Define valid source vocabularies
      valid_vocabs <- c("ICD9CM", "ICD10CM", "HCPCS", "CPT4", "LOINC", "NDC")

      # Validate sourceVocabs
      checkmate::assert_character(sourceVocabs, min.len = 1)
      invalid_vocabs <- setdiff(sourceVocabs, valid_vocabs)
      if (length(invalid_vocabs) > 0) {
        stop("Invalid source vocabulary: ", paste(invalid_vocabs, collapse = ", "),
             ". Valid options: ", paste(valid_vocabs, collapse = ", "))
      }

      # Collect domains from all concept sets and suggest vocabularies
      domains <- unique(sapply(private$.manifest, function(cs) {
        tags <- cs$tags
        if (!is.null(tags) && "domain" %in% names(tags)) {
          return(tags[["domain"]])
        }
        return(NA_character_)
      }))
      
      domains <- domains[!is.na(domains)]
      
      # Suggest vocabularies based on domains
      if (length(domains) > 0) {
        suggested_vocabs <- unique(unlist(lapply(domains, private$suggest_source_vocabs_for_domain)))
        cli::cli_alert_info("Concept set domains detected: {paste(domains, collapse = ', ')}")
        cli::cli_alert_info("Suggested source vocabularies for these domains: {paste(suggested_vocabs, collapse = ', ')}")
        
        # Interactive prompt to use suggested vocabularies
        cli::cli_rule("Source Vocabulary Selection")
        choice <- utils::menu(
          c("Yes", "No"),
          title = "Would you like to use the suggested source vocabularies?"
        )
        
        if (choice == 1) {
          # User selected "Yes"
          sourceVocabs <- suggested_vocabs
          cli::cli_alert_success("Using suggested vocabularies: {paste(sourceVocabs, collapse = ', ')}")
        } else {
          # User selected "No"
          cli::cli_alert_info("Using specified vocabularies: {paste(sourceVocabs, collapse = ', ')}")
        }
      }

      # Get connection and vocabulary schema from ExecutionSettings
      exec_settings <- private$.executionSettings
      connection <- exec_settings$getConnection()
      vocab_schema <- exec_settings$cdmDatabaseSchema

      if (is.null(connection)) {
        exec_settings$connect()
        connection <- exec_settings$getConnection()
      }
      on.exit(settings$disconnect())


      if (is.null(vocab_schema)) {
        stop("ExecutionSettings must have vocabularySchema defined")
      }

      # Check if openxlsx2 is available
      if (!requireNamespace("openxlsx2", quietly = TRUE)) {
        stop("The 'openxlsx2' package is required to extract source codes. Install it with: install.packages('openxlsx2')")
      }

      # Create output file path
      output_file <- fs::path(outputFolder, paste0("SourceCodeWorkbook", ".xlsx"))

      # Create workbook
      wb <- openxlsx2::wb_workbook()

      cli::cli_alert_info("Extracting source codes for {length(private$.manifest)} concept sets...")

      # Process each concept set
      for (i in seq_along(private$.manifest)) {
        concept_set <- private$.manifest[[i]]

        tryCatch({
          cs_label <- concept_set$label
          cs_json <- concept_set$getJson()
          cs_file_path <- concept_set$getFilePath()

          cli::cli_alert_info("[{i}/{length(private$.manifest)}] Processing: {crayon::magenta(cs_label)}")

          # Build CIRCE concept set query
          cs_sql <- CirceR::buildConceptSetQuery(cs_json)

          # Wrap in CTE and join with source codes
          full_sql <- glue::glue(
            "WITH concepts AS ({cs_sql})\n",
            "SELECT c.vocabulary_id, c.concept_code, c.concept_name\n",
            "FROM concepts\n",
            "JOIN @vocabulary_database_schema.concept_relationship cr\n",
            "  ON cr.concept_id_2 = concepts.concept_id\n",
            "  AND relationship_id = 'Maps to'\n",
            "JOIN @vocabulary_database_schema.concept c\n",
            "  ON c.concept_id = cr.concept_id_1\n",
            "  AND c.vocabulary_id IN (@vocabs)\n",
            "  AND c.invalid_reason IS NULL\n",
            "ORDER BY 1, 2;"
          )

          # Format vocabulary list for SQL
          vocabs_sql <- paste0("'", paste(sourceVocabs, collapse = "','"), "'")

          # Execute query
          source_codes <- DatabaseConnector::renderTranslateQuerySql(
            connection,
            full_sql,
            vocabulary_database_schema = vocab_schema,
            vocabs = vocabs_sql
          )

          # Create a valid sheet name (max 31 characters, no special chars)
          sheet_name <- substr(gsub("[^a-zA-Z0-9]", "_", cs_label), 1, 31)

          # Add worksheet to workbook and add data
          wb <- openxlsx2::wb_add_worksheet(wb, sheet = sheet_name)
          wb <- openxlsx2::wb_add_data(wb, sheet = sheet_name, x = source_codes)

          # Format the header row
          hs <- openxlsx2::create_style(fgFill = "#4472C4", fontColour = "white", textDecoration = "bold")
          wb <- openxlsx2::wb_add_style(wb, sheet = sheet_name, style = hs, rows = 1, cols = 1:ncol(source_codes))

          # Auto-fit columns
          wb <- openxlsx2::set_col_widths(wb, sheet = sheet_name, widths = "auto", cols = 1:ncol(source_codes))

          cli::cli_alert_success(
            "Added {nrow(source_codes)} source codes for {crayon::cyan(cs_label)}"
          )
        }, error = function(e) {
          cli::cli_alert_danger(
            "Error extracting source codes for {concept_set$label}: {e$message}"
          )
        })
      }

      # Save the workbook
      openxlsx2::wb_save(wb, file = output_file, overwrite = TRUE)
      cli::cli_alert_success("Source codes extracted and saved to: {fs::path_rel(output_file)}")

      invisible(NULL)
    }
  )
)
