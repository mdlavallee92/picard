# ExecutionSettings ----

#' @title ExecutionSettings
#' @description
#' An R6 class to define an ExecutionSettings object
#'
#' @export
ExecutionSettings <- R6::R6Class(
  classname = "ExecutionSettings",
  public = list(
    #' @param connectionDetails a connectionDetails object
    #' @param connection a connection to a dbms
    #' @param cdmDatabaseSchema The schema of the OMOP CDM database
    #' @param workDatabaseSchema The schema to which results will be written
    #' @param tempEmulationSchema Some database platforms like Oracle and Snowflake do not truly support temp tables. To emulate temp tables, provide a schema with write privileges where temp tables can be created.
    #' @param cohortTable The name of the table where the cohort(s) are stored
    #' @param databaseName A human-readable name for the OMOP CDM database
    initialize = function(connectionDetails = NULL,
                          connection = NULL,
                          cdmDatabaseSchema = NULL,
                          workDatabaseSchema = NULL,
                          tempEmulationSchema = NULL,
                          cohortTable = NULL,
                          databaseName = NULL) {
      stopifnot(is.null(connectionDetails) || is.null(connection))
      .setClass(private = private, key = "connectionDetails", value = connectionDetails,
                class = "ConnectionDetails", nullable = TRUE)
      .setClass(private = private, key = ".connection", value = connection,
                class = "DatabaseConnectorJdbcConnection", nullable = TRUE)
      .setString(private = private, key = ".cdmDatabaseSchema", value = cdmDatabaseSchema)
      .setString(private = private, key = ".workDatabaseSchema", value = workDatabaseSchema)
      .setString(private = private, key = ".tempEmulationSchema", value = tempEmulationSchema)
      .setString(private = private, key = ".cohortTable", value = cohortTable)
      .setString(private = private, key = ".databaseName", value = databaseName)
    },
    #' @description extract the dbms dialect
    getDbms = function() {
      conObj <- private$.connection
      if (!is.null(conObj)) {
        dbms <- conObj@dbms
      } else {
        dbms <- private$connectionDetails$dbms
      }
      return(dbms)
    },
    #' @description connect to dbms
    connect = function() {

      # check if private$connection is NULL
      conObj <- private$.connection
      if (is.null(conObj)) {
        private$.connection <- DatabaseConnector::connect(private$connectionDetails)
      } else{
        cli::cat_bullet(
          "Connection object already open",
          bullet = "info",
          bullet_col = "blue"
        )
      }
    },

    #' @description disconnect from dbms
    disconnect = function() {

      # check if private$connection is NULL
      conObj <- private$.connection
      if (class(conObj) == "DatabaseConnectorJdbcConnection") {
        # disconnect connection
        DatabaseConnector::disconnect(private$.connection)
        private$.connection <- NULL
      }

      cli::cat_bullet(
        "Connection object has been disconected",
        bullet = "info",
        bullet_col = "blue"
      )
      invisible(conObj)
    },

    #TODO make this more rigorous
    # add warning if no connection available
    #' @description retrieve the connection object
    getConnection = function() {
      conObj <- private$.connection
      return(conObj)
    }

  ),

  private = list(
    connectionDetails = NULL,
    .connection = NULL,
    .cdmDatabaseSchema = NULL,
    .workDatabaseSchema = NULL,
    .tempEmulationSchema = NULL,
    .cohortTable = NULL,
    .databaseName = NULL
  ),

  active = list(
    #' @field cdmDatabaseSchema the schema containing the OMOP CDM
    cdmDatabaseSchema = function(value) {
      # return the value if nothing added
      if(missing(value)) {
        cds <- private$.cdmDatabaseSchema
        return(cds)
      }
      # replace the cdmDatabaseSchema
      .setString(private = private, key = ".cdmDatabaseSchema", value = value)
      cli::cat_bullet(
        glue::glue("Replaced {crayon::cyan('cdmDatabaseSchema')} with {crayon::green(value)}"),
        bullet = "info",
        bullet_col = "blue"
      )
    },

    #' @field workDatabaseSchema the schema containing the cohort table
    workDatabaseSchema = function(value) {
      # return the value if nothing added
      if(missing(value)) {
        cds <- private$.workDatabaseSchema
        return(cds)
      }
      # replace the workDatabaseSchema
      .setString(private = private, key = ".workDatabaseSchema", value = value)
      cli::cat_bullet(
        glue::glue("Replaced {crayon::cyan('workDatabaseSchema')} with {crayon::green(value)}"),
        bullet = "info",
        bullet_col = "blue"
      )
    },

    #' @field tempEmulationSchema the schema needed for temp tables
    tempEmulationSchema = function(value) {
      # return the value if nothing added
      if(missing(value)) {
        tes <- private$.tempEmulationSchema
        return(tes)
      }
      # replace the tempEmulationSchema
      .setString(private = private, key = ".tempEmulationSchema", value = value)
      cli::cat_bullet(
        glue::glue("Replaced {crayon::cyan('tempEmulationSchema')} with {crayon::green(value)}"),
        bullet = "info",
        bullet_col = "blue"
      )
    },
    #' @field cohortTable the table containing the cohorts
    cohortTable = function(value) {
      # return the value if nothing added
      if(missing(value)) {
        tct <- private$.cohortTable
        return(tct)
      }
      # replace the cohortTable
      .setString(private = private, key = ".cohortTable", value = value)
      cli::cat_bullet(
        glue::glue("Replaced {crayon::cyan('cohortTable')} with {crayon::green(value)}"),
        bullet = "info",
        bullet_col = "blue"
      )
    },
    #' @field databaseName the name of the source data of the cdm
    databaseName = function(value) {
      # return the value if nothing added
      if(missing(value)) {
        csn <- private$.databaseName
        return(csn)
      }
      # replace the databaseName
      .setString(private = private, key = ".databaseName", value = value)
      cli::cat_bullet(
        glue::glue("Replaced {crayon::cyan('databaseName')} with {crayon::green(value)}"),
        bullet = "info",
        bullet_col = "blue"
      )
    }

  )
)
