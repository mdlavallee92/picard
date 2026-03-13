.setClass <- function(private, key, value, class, nullable = FALSE) {
  checkmate::assert_class(x = value, classes = class, null.ok = nullable)
  private[[key]] <- value
  invisible(private)
}

.setString <- function(private, key, value, naOk = FALSE) {
  checkmate::assert_string(x = value, na.ok = naOk, min.chars = 1, null.ok = FALSE)
  private[[key]] <- value
  invisible(private)
}

# Study Options Class -------------
UlyssesStudy <- R6::R6Class(
  classname = "UlyssesStudy",
  public = list(
    initialize = function(repoName,
                          repoFolder,
                          toolType = c("dbms", "external"),
                          studyMeta,
                          execOptions,
                          gitRemote = NULL,
                          renvLock = NULL
    ) {

      checkmate::assert_string(x = repoName, min.chars = 1)
      private[[".repoName"]] <- repoName

      checkmate::assert_string(x = repoFolder, min.chars = 1)
      private[[".repoFolder"]] <- repoFolder

      checkmate::assert_string(x = toolType, min.chars = 1)
      private[[".toolType"]] <- toolType

      .setClass(private = private, key = ".studyMeta", value = studyMeta, class = "StudyMeta")

      .setClass(private = private,key = ".execOptions",value = execOptions,class = "ExecOptions")

      checkmate::assert_string(x = gitRemote, null.ok = TRUE)
      private[[".gitRemote"]] <- gitRemote

      checkmate::assert_string(x = renvLock, null.ok = TRUE)
      private[[".renvLock"]] <- renvLock
    },

    initUlyssesRepo = function(verbose = TRUE, openProject = FALSE) {
      repoPath <- private$.getRepoPath()
      
      if (verbose) cli::cli_h2("Initializing Ulysses Repository")
      
      tryCatch({
        # Step 1: Create repo directory and R project
        if (verbose) cli::cli_inform("Creating R project directory...")
        fs::dir_create(repoPath, recurse = TRUE)
        usethis::local_project(repoPath, force = TRUE)
        private$.initRProj()
        
        # Step 2: Create folder structure
        if (verbose) cli::cli_inform("Creating directory structure...")
        listDefaultFolders(repoPath = repoPath)
        
        # Step 3: Initialize files
        if (verbose) cli::cli_inform("Creating initialization files...")
        private$.initReadMe()
        private$.initNews()
        private$.initConfigFile()
        private$.initQuarto()
        private$.initMainExec()
        private$.initAgent()
        
        # Step 4: Initialize git
        if (verbose) cli::cli_inform("Initializing git repository...")
        private$.initGit()
        
        cli::cli_alert_success("Repository successfully initialized at {repoPath}")
        
        # Open project if requested
        if (openProject) {
          cli::cli_inform("Opening project in new session...")
          rstudioapi::openProject(repoPath, newSession = TRUE)
        }
      }, error = function(e) {
        cli::cli_alert_danger("Failed to initialize repository: {e$message}")
        stop(e)
      })
      
      invisible(repoPath)
    }
  ),
  private = list(
    .repoName = NULL,
    .repoFolder = NULL,
    .toolType = NULL,
    .studyMeta = NULL,
    .execOptions = NULL,
    .gitRemote = NULL,
    .renvLock = NULL,

    # Helper method to get expanded repository path
    .getRepoPath = function() {
      fs::path(private$.repoFolder, private$.repoName) |> fs::path_expand()
    },

    # File initialization methods
    .initRProj = function() {
      repoPath <- private$.getRepoPath()
      repoName <- private$.repoName
      
      tryCatch({
        projLines <- fs::path_package("picard", "templates/rproj.txt") |>
          readr::read_file()
        
        projFile <- fs::path(repoPath, repoName, ext = "Rproj")
        readr::write_file(x = projLines, file = projFile)
        
        cli::cli_alert_success("Created {.file {fs::path_rel(projFile)}}")
        
        usethis::use_git_ignore(
          c(".Rproj.user", ".Ruserdata", ".Rhistory", ".RData",
            ".Renviron", "exec/results", "errorReportSql.txt")
        )
      }, error = function(e) {
        cli::cli_alert_danger("Failed to initialize R project: {e$message}")
        stop(e)
      })
      
      invisible(NULL)
    },

    .initReadMe = function() {
      repoPath <- private$.getRepoPath()
      tryCatch({
        initReadMeFn(sm = private$.studyMeta, repoName = private$.repoName, repoPath = repoPath)
      }, error = function(e) {
        cli::cli_alert_danger("Failed to initialize README: {e$message}")
        stop(e)
      })
      invisible(NULL)
    },

    .initNews = function() {
      repoPath <- private$.getRepoPath()
      tryCatch({
        initNewsFn(repoName = private$.repoName, repoPath = repoPath)
      }, error = function(e) {
        cli::cli_alert_danger("Failed to initialize NEWS: {e$message}")
        stop(e)
      })
      invisible(NULL)
    },

    .initConfigFile = function() {
      repoPath <- private$.getRepoPath()
      tryCatch({
        private$.execOptions$makeConfigFile(
          repoName = private$.repoName,
          repoPath = repoPath,
          toolType = private$.toolType
        )
      }, error = function(e) {
        cli::cli_alert_danger("Failed to initialize config: {e$message}")
        stop(e)
      })
      invisible(NULL)
    },

    .initGit = function() {
      repoPath <- private$.getRepoPath()
      tryCatch({
        gert::git_init(repoPath)
        
        if (!is.null(private$.gitRemote)) {
          addGitRemoteToUlysses(
            gitRemoteUrl = private$.gitRemote,
            gitRemoteName = "origin",
            commitMessage = "Initialize Ulysses Repo for study"
          )
        } else {
          gert::git_add(files = ".")
          gert::git_commit_all(message = "Initialize Ulysses Repo for study")
        }
        cli::cli_alert_success("Git repository initialized")
      }, error = function(e) {
        cli::cli_alert_danger("Failed to initialize git: {e$message}")
        stop(e)
      })
      invisible(NULL)
    },

    .initQuarto = function() {
      tryCatch({
        initStudyHubFiles(
          repoName = private$.repoName,
          repoFolder = private$.repoFolder,
          studyTitle = private$.studyMeta$studyTitle
        )
      }, error = function(e) {
        cli::cli_alert_danger("Failed to initialize Quarto files: {e$message}")
        stop(e)
      })
      invisible(NULL)
    },

    .initMainExec = function() {
      tryCatch({
        configBlocks <- if (private$.toolType == "dbms") {
          purrr::map_chr(private$.execOptions$dbConnectionBlocks, ~.x$configBlockName)
        } else {
          ""
        }
        
        addMainFile(
          repoName = private$.repoName,
          repoFolder = private$.repoFolder,
          toolType = private$.toolType,
          configBlocks = configBlocks,
          studyName = private$.studyMeta$studyTitle
        )
      }, error = function(e) {
        cli::cli_alert_danger("Failed to initialize main execution file: {e$message}")
        stop(e)
      })
      invisible(NULL)
    },

    .initAgent = function() {
      repoPath <- private$.getRepoPath()
      tryCatch({
        agent_folder <- fs::path(repoPath, ".agent")
        fs::dir_create(agent_folder)
        
        agent_template <- fs::path_package("picard", "templates/agent_skills.md") |>
          readr::read_file()
        
        agent_file <- fs::path(agent_folder, "agent_skills.md")
        readr::write_file(x = agent_template, file = agent_file)
        
        cli::cli_alert_success("Created {.file {fs::path_rel(agent_file)}}")
      }, error = function(e) {
        cli::cli_alert_danger("Failed to initialize agent configuration: {e$message}")
        stop(e)
      })
      invisible(NULL)
    }
  ),
  active = list(
    repoName = function(value) {
      if (missing(value)) return(private$.repoName)
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".repoName"]] <- value
      cli::cli_alert_info("Updated {.field repoName}")
    },

    repoFolder = function(value) {
      if (missing(value)) return(private$.repoFolder)
      checkmate::assert_string(x = value, min.chars = 1)
      private[[".repoFolder"]] <- value
      cli::cli_alert_info("Updated {.field repoFolder}")
    },

    toolType = function(value) {
      if (missing(value)) return(private$.toolType)
      checkmate::assert_choice(x = value, choices = c("dbms", "external"))
      private[[".toolType"]] <- value
      cli::cli_alert_info("Updated {.field toolType}")
    },

    studyMeta = function(value) {
      if(missing(value)) return(private$.studyMeta)
      .setClass(private = private, key = ".studyMeta", value = value, class = "StudyMeta")
      cli::cli_alert_info("Updated {.field studyMeta}")
    },

    gitRemote = function(value) {
      if (missing(value)) return(private$.gitRemote)
      checkmate::assert_string(x = value, null.ok = TRUE)
      private[[".gitRemote"]] <- value
      cli::cli_alert_info("Updated {.field gitRemote}")
    },

    renvLock = function(value) {
      if (missing(value)) return(private$.renvLock)
      checkmate::assert_string(x = value, null.ok = TRUE)
      private[[".renvLock"]] <- value
      cli::cli_alert_info("Updated {.field renvLock}")
    }
  )
)

# Sub options classes ------------

# sub class for contributors in study meta
# Contributor Line ---------------
ContributorLine <- R6::R6Class(
  classname = "ContributorLine",
  public = list(
    initialize = function(name, email, role) {
      .setString(private = private, key = ".name", value = name)
      .setString(private = private, key = ".email", value = email)
      .setString(private = private, key = ".role", value = role)
    },
    printContributorLine = function() {
      txt <- glue::glue("Name: {private$.name} | Email: {private$.email} | Role: {private$.role}")
      return(txt)
    }
  ),
  private = list(
    .name = NA_character_,
    .email = NA_character_,
    .role = NA_character_
  ),
  active = list(
    name = function(value) {
      if (missing(value)) return(private$.name)
      .setString(private = private, key = ".name", value = value)
      cli::cli_alert_info("Updated contributor {.field name}")
    },

    email = function(value) {
      if (missing(value)) return(private$.email)
      .setString(private = private, key = ".email", value = value)
      cli::cli_alert_info("Updated contributor {.field email}")
    },

    role = function(value) {
      if (missing(value)) return(private$.role)
      .setString(private = private, key = ".role", value = value)
      cli::cli_alert_info("Updated contributor {.field role}")
    }
  )
)

# Study Meta ---------------
StudyMeta <- R6::R6Class(
  classname = "StudyMeta",
  public = list(
    initialize = function(studyTitle,
                          therapeuticArea,
                          studyType,
                          contributors,
                          studyLinks = NULL,
                          studyTags = NULL) {
      .setString(private = private, key = ".studyTitle", value = studyTitle)
      .setString(private = private, key = ".therapeuticArea", value = therapeuticArea)
      .setString(private = private, key = ".studyType", value = studyType)

      checkmate::assert_character(x = studyLinks, null.ok = TRUE)
      if (!is.null(studyLinks)) {
        private[[".studyLinks"]] <- studyLinks
      }


      checkmate::assert_character(x = studyTags, null.ok = TRUE)
      if (!is.null(studyTags)) {
        private[[".studyTags"]] <- studyTags
      }

      checkmate::assert_list(x = contributors, min.len = 1, types = "ContributorLine")
      private[[".contributors"]] <- contributors

    },

    listContributors = function() {
      ctbs <- private$.contributors
      ctbsList <- purrr::map(
        private$.contributors,
        ~glue::glue("- {.x$role}: {.x$name} (email: {.x$email})")
      ) |>
        glue::glue_collapse(sep = "\n")
      ctbs2 <- c("## Contributors", ctbsList) |> glue::glue_collapse(sep = "\n\n")

      return(ctbs2)
    },

    listStudyTags = function() {
      tags <- private$.studyTags
      if (length(tags) > 0) {
        tagList <- purrr::map(
          private$.studyTags,
          ~glue::glue("\t* {.x}")
        ) |>
          glue::glue_collapse(sep = "\n")
        tagList <- c("- Tags", tagList) |> glue::glue_collapse(sep = "\n")
      } else {
        tagList <- "- Tags (Please Add)"
      }

      return(tagList)
    },

    listStudyLinks = function() {
      links <- private$.studyLinks
      if (length(links) > 0) {
        linksList <- purrr::map(
          private$.studyLinks,
          ~glue::glue("\t* {.x}")
        ) |>
          glue::glue_collapse(sep = "\n")
        linksList <- c("## Resources", links) |> glue::glue_collapse(sep = "\n\n")
      } else {
        linksList <- c("## Resources", "<!-- Place study Links as needed -->") |> glue::glue_collapse(sep = "\n\n")
      }

      return(linksList)
    }

  ),
  private = list(
    .studyTitle = NULL,
    .therapeuticArea = NULL,
    .studyType = NULL,
    .contributors = NULL,
    .studyLinks = NULL,
    .studyTags = NULL
  ),
  active = list(
    studyTitle = function(value) {
      if (missing(value)) return(private$.studyTitle)
      .setString(private = private, key = ".studyTitle", value = value)
      cli::cli_alert_info("Updated {.field studyTitle}")
    },

    therapeuticArea = function(value) {
      if (missing(value)) return(private$.therapeuticArea)
      .setString(private = private, key = ".therapeuticArea", value = value)
      cli::cli_alert_info("Updated {.field therapeuticArea}")
    },

    studyType = function(value) {
      if (missing(value)) return(private$.studyType)
      .setString(private = private, key = ".studyType", value = value)
      cli::cli_alert_info("Updated {.field studyType}")
    },

    studyTags = function(value) {
      if (missing(value)) return(private$.studyTags)
      checkmate::assert_character(x = value)
      private[[".studyTags"]] <- value
      cli::cli_alert_info("Updated {.field studyTags}")
    },

    studyLinks = function(value) {
      if (missing(value)) return(private$.studyLinks)
      checkmate::assert_character(x = value)
      private[[".studyLinks"]] <- value
      cli::cli_alert_info("Updated {.field studyLinks}")
    },

    contributors = function(value) {
      if (missing(value)) return(private$.contributors)
      checkmate::assert_list(x = value, min.len = 1, types = "ContributorLine")
      private[[".contributors"]] <- value
      cli::cli_alert_info("Updated {.field contributors}")
    }
  )
)

# Db Config Block -----------------------
DbConfigBlock <- R6::R6Class(
  classname = "DbConfigBlock",
  public = list(
    initialize = function(configBlockName,
                          cdmDatabaseSchema,
                          cohortTable,
                          databaseName = NULL,
                          databaseLabel = NULL) {

      .setString(private = private, key = ".configBlockName", value = configBlockName)
      .setString(private = private, key = ".cdmDatabaseSchema", value = cdmDatabaseSchema)
      .setString(private = private, key = ".cohortTable", value = cohortTable)

      checkmate::assert_string(x = databaseName, min.chars = 1, null.ok = TRUE)
      if (is.null(databaseName)) {
        private[[".databaseName"]] <- configBlockName
      } else {
        private[[".databaseName"]] <- databaseName
      }


      checkmate::assert_string(x = databaseLabel, min.chars = 1, null.ok = TRUE)
      if (is.null(databaseName) & is.null(databaseLabel)) {
        private[[".databaseLabel"]] <- configBlockName
      } else if (!is.null(databaseName) & is.null(databaseLabel)) {
        private[[".databaseLabel"]] <- databaseName
      } else {
        private[[".databaseLabel"]] <- databaseLabel
      }
    },

    writeBlockSection = function(repoName, dbms, workSchema, tempSchema) {

      configBlockName <- private$.configBlockName
      databaseName <- private$.databaseName
      databaseLabel <- private$.databaseLabel
      cdmSchema <- private$.cdmDatabaseSchema
      cohortTable <- private$.cohortTable

      configBlock <- fs::path_package(package = "picard", "templates/configBlock.txt") |>
        readr::read_file() |>
        glue::glue()

      return(configBlock)
    }
  ),
  private = list(
    .configBlockName = NULL,
    .cdmDatabaseSchema = NULL,
    .cohortTable = NULL,
    .databaseName = NULL,
    .databaseLabel = NULL
  ),
  active = list(
    configBlockName = function(value) {
      if (missing(value)) return(private$.configBlockName)
      .setString(private = private, key = ".configBlockName", value = value)
      cli::cli_alert_info("Updated {.field configBlockName}")
    },

    cdmDatabaseSchema = function(value) {
      if (missing(value)) return(private$.cdmDatabaseSchema)
      .setString(private = private, key = ".cdmDatabaseSchema", value = value)
      cli::cli_alert_info("Updated {.field cdmDatabaseSchema}")
    },

    cohortTable = function(value) {
      if (missing(value)) return(private$.cohortTable)
      .setString(private = private, key = ".cohortTable", value = value)
      cli::cli_alert_info("Updated {.field cohortTable}")
    },

    databaseName = function(value) {
      if (missing(value)) return(private$.databaseName)
      .setString(private = private, key = ".databaseName", value = value)
      cli::cli_alert_info("Updated {.field databaseName}")
    },

    databaseLabel = function(value) {
      if (missing(value)) return(private$.databaseLabel)
      .setString(private = private, key = ".databaseLabel", value = value)
      cli::cli_alert_info("Updated {.field databaseLabel}")
    }
  )
)

# Exec Options ---------------------
ExecOptions <- R6::R6Class(
  classname = "ExecOptions",
  public = list(
    initialize = function(
    dbms = NULL,
    workDatabaseSchema = NULL,
    tempEmulationSchema = NULL,
    dbConnectionBlocks = NULL) {

      checkmate::assert_string(x = dbms, min.chars = 1, null.ok = TRUE)
      if (!is.null(dbms)) {
        private[[".dbms"]] <- dbms
      }

      checkmate::assert_string(x = workDatabaseSchema, min.chars = 1, null.ok = TRUE)
      if (!is.null(workDatabaseSchema)) {
        private[[".workDatabaseSchema"]] <- workDatabaseSchema
      }

      checkmate::assert_string(x = tempEmulationSchema, min.chars = 1, null.ok = TRUE)
      if (!is.null(tempEmulationSchema)) {
        private[[".tempEmulationSchema"]] <- tempEmulationSchema
      }

      checkmate::assert_list(x = dbConnectionBlocks, min.len = 1, types = "DbConfigBlock", null.ok = TRUE)
      if (!is.null(dbConnectionBlocks)) {
        private[[".dbConnectionBlocks"]] <- dbConnectionBlocks
      }

    },

    makeConfigFile = function(repoName, repoPath, toolType) {
      if(toolType == "dbms") {
        dbBlocks <- vector('list', length = length(private$.dbConnectionBlocks))
        for (i in seq_along(dbBlocks)) {
          dbBlocks[[i]] <- private$.dbConnectionBlocks[[i]]$writeBlockSection(
            repoName = repoName,
            dbms = private$.dbms,
            workSchema = private$.workDatabaseSchema,
            tempSchema = private$.tempEmulationSchema
          )
        }
        dbBlocks <- do.call('c', dbBlocks) |>
          glue::glue_collapse(sep = "\n\n")
      } else {
        dbBlocks <- ""
      }

      header <- fs::path_package(package = "picard", "templates/configHeader.txt") |>
        readr::read_file() |>
        glue::glue()

      configFile <- c(header, dbBlocks) |>
        glue::glue_collapse(sep = "\n\n")

      readr::write_lines(
        x = configFile,
        file = fs::path(repoPath, "config.yml")
      )

      actionItem(glue::glue_col("Initialize Config: {green {fs::path(repoPath, repoName, 'config.yml')}}"))
      invisible(configFile)

    }
  ),
  private = list(
    .dbms = NULL,
    .workDatabaseSchema = NULL,
    .tempEmulationSchema = NULL,
    .dbConnectionBlocks = NULL
  ),
  active = list(
    dbms = function(value) {
      if (missing(value)) return(private$.dbms)
      .setString(private = private, key = ".dbms", value = value)
      cli::cli_alert_info("Updated {.field dbms}")
    },

    workDatabaseSchema = function(value) {
      if (missing(value)) return(private$.workDatabaseSchema)
      .setString(private = private, key = ".workDatabaseSchema", value = value)
      cli::cli_alert_info("Updated {.field workDatabaseSchema}")
    },

    tempEmulationSchema = function(value) {
      if (missing(value)) return(private$.tempEmulationSchema)
      .setString(private = private, key = ".tempEmulationSchema", value = value)
      cli::cli_alert_info("Updated {.field tempEmulationSchema}")
    },

    dbConnectionBlocks = function(value) {
      if (missing(value)) return(private$.dbConnectionBlocks)
      checkmate::assert_list(x = value, min.len = 1, types = "DbConfigBlock")
      private[[".dbConnectionBlocks"]] <- value
      cli::cli_alert_info("Updated {.field dbConnectionBlocks}")
    }
  )
)


listDefaultFolders <- function(repoPath) {
  analysisFolders <- c("src", "tasks", "migrations")
  execFolders <- c('logs', 'results')
  inputFolders <- c("cohorts/json", "cohorts/sql", "conceptSets/json")
  disseminationFolders <- c("quarto", "export/pretty", "export/merge", "documents")

  folders <- c(
    paste('inputs', inputFolders, sep = "/"),
    paste('analysis', analysisFolders, sep = "/"),
    paste('exec', execFolders, sep = "/"),
    paste('dissemination', disseminationFolders, sep = "/"),
    'extras'
  )
  
  # Create directories and .gitkeep files to ensure empty folders are tracked by git
  for (folder in folders) {
    dir_path <- fs::path(repoPath, folder)
    fs::dir_create(dir_path, recurse = TRUE)
    fs::file_create(fs::path(dir_path, ".gitkeep"))
  }
  
  return(folders)
}


initReadMeFn <- function(sm, repoName, repoPath) {
  # prep title
  title <- glue::glue("# {sm$studyTitle} (Id: {repoName})")
  # prep start badge
  badge <- glue::glue(
    "<!-- badge: start -->

      ![Study Status: Started](https://img.shields.io/badge/Study%20Status-Started-blue.svg)
      ![Version: 0.0.1](https://img.shields.io/badge/Version-0.0.1-yellow.svg)

    <!-- badge: end -->"
  )

  # create tag list
  tagList <- sm$listStudyTags()

  # prep study info
  info <-c(
    "## Study Information",
    glue::glue("- Study Id: {repoName}"),
    glue::glue("- Study Title: {sm$studyTitle}"),
    glue::glue("- Study Start Date: {lubridate::today()}"),
    glue::glue("- Expected Study End Date: {lubridate::today() + (365 * 2)}"),
    glue::glue("- Study Type: {sm$studyType}"),
    glue::glue("- Therapeutic Area: {sm$therapeuticArea}"),
    tagList
  ) |>
    glue::glue_collapse(sep = "\n")

  # prep placeholder for desc
  desc <- c(
    "## Study Description",
    "Add a short description about the study!"
  ) |>
    glue::glue_collapse(sep = "\n\n")

  # prep contributors
  contributors <- sm$listContributors()

  # prep links
  links <- sm$listStudyLinks()

  # combine and save to README file
  readmeLines <- c(
    title,
    badge,
    info,
    desc,
    contributors,
    links
  ) |>
    glue::glue_collapse(sep = "\n\n")

  readr::write_lines(
    x = readmeLines,
    file = fs::path(repoPath, "README.md")
  )

  actionItem(glue::glue_col("Initialize Readme: {green {fs::path(repoPath, 'README.md')}}"))
  invisible(readmeLines)
}


initNewsFn <- function(repoName, repoPath) {

  header <- glue::glue("# {repoName} 0.0.1")
  items <- c(
    glue::glue("- Run Date: {lubridate::today()}"),
    "- Initialize Ulysses Repo"
  ) |>
    glue::glue_collapse(sep = "\n")

  newsLines <- c(header, items) |>
    glue::glue_collapse(sep = "\n")
  #cat(newsLines)

  readr::write_lines(
    x = newsLines,
    file = fs::path(repoPath, "NEWS.md")
  )

  actionItem(glue::glue_col("Initialize NEWS: {green {fs::path(repoPath, 'NEWS.md')}}"))
  invisible(newsLines)
}

updateNews <- function(versionNumber, projectPath = here::here(), openFile = TRUE) {

  repoName <- basename(projectPath)
  newsFile <- readr::read_file(file = fs::path(projectPath, "NEWS.md"))
  newsHeader <- glue::glue("# {repoName} {versionNumber}\n\t-Run Date: {lubridate::today()}")
  updateNewsFile <- c(newsHeader, newsFile) |> glue::glue_collapse(sep = "\n\n")
  readr::write_file(updateNewsFile, file = fs::path(projectPath, "NEWS.md"))
  actionItem(glue::glue_col("Update NEWS: {green {fs::path(projectPath, 'NEWS.md')}}"))
  cli::cat_bullet(
    "Please add a bulleted description of changes to the new version!!!",
    bullet = "warning",
    bullet_col = "yellow"
  )
  if (openFile) {
    rstudioapi::navigateToFile(file = fs::path(projectPath, "NEWS.md"))
    actionItem("Opening NEWS.md for edits")
  }
  invisible(updateNewsFile)
}


notification <- function(txt) {
  cli::cat_bullet(
    txt,
    bullet = "info",
    bullet_col = "blue"
  )
  invisible(txt)
}

actionItem <- function(txt) {
  cli::cat_bullet(
    txt,
    bullet = "pointer",
    bullet_col = "yellow"
  )
  invisible(txt)
}


writeFileAndNotify <- function(x, repoPath, fileName) {

  filePath <- fs::path(repoPath, fileName)

  readr::write_lines(
    x = x,
    file = filePath
  )

  actionItem(glue::glue_col("Write {green {fileName}} to: {cyan {filePath}}"))
  invisible(filePath)
}

#' Validate Ulysses Repository Structure
#'
#' @description Checks that a directory is a valid Ulysses-style repository
#' with all required files and folders.
#'
#' @param path Character. Path to the repository to validate. If NULL (default),
#'   uses the current working directory.
#'
#' @return List with validation results containing:
#'   - is_valid: Logical. TRUE if all requirements met
#'   - path: Character. Path that was validated
#'   - required_files: Data frame with required files and their status
#'   - required_dirs: Data frame with required directories and their status
#'   - summary: Character. Summary message
#'
#' @details
#' A valid Ulysses repository must contain:
#' - README.md file
#' - NEWS.md file
#' - config.yml file
#' - *.Rproj file (R project file)
#' - analysis/ directory
#'
#' @export
#' @examples
#' \dontrun{
#'   validateUlyssesStructure()  # Check current directory
#'   validateUlyssesStructure("/path/to/repo")  # Check specific directory
#' }
validateUlyssesStructure <- function(path = NULL) {
  # Use current working directory if path not provided
  if (is.null(path)) {
    path <- here::here()
  }
  
  checkmate::assert_string(x = path, min.chars = 1)
  path <- fs::path_expand(path)
  
  # Check if path exists
  if (!fs::dir_exists(path)) {
    cli::cli_alert_danger("Path does not exist: {path}")
    return(list(
      is_valid = FALSE,
      path = path,
      summary = glue::glue("Path does not exist: {path}")
    ))
  }
  
  # Required files
  required_files <- list(
    README = fs::path(path, "README.md"),
    NEWS = fs::path(path, "NEWS.md"),
    CONFIG = fs::path(path, "config.yml")
  )
  
  # Check for .Rproj file (any .Rproj file in the directory)
  rproj_files <- fs::dir_ls(path, glob = "*.Rproj", recurse = FALSE)
  required_files$RPROJ <- if (length(rproj_files) > 0) rproj_files[1] else NA_character_
  
  # Check which files exist
  files_status <- data.frame(
    file = names(required_files),
    path = unlist(required_files),
    exists = sapply(unlist(required_files), function(p) {
      if (is.na(p)) FALSE else fs::file_exists(p)
    }),
    row.names = NULL,
    stringsAsFactors = FALSE
  )
  
  # Required directories
  required_dirs_list <- list(
    analysis = fs::path(path, "analysis")
  )
  
  dirs_status <- data.frame(
    directory = names(required_dirs_list),
    path = unlist(required_dirs_list),
    exists = sapply(unlist(required_dirs_list), fs::dir_exists),
    row.names = NULL,
    stringsAsFactors = FALSE
  )
  
  # Determine overall validity
  files_valid <- all(files_status$exists)
  dirs_valid <- all(dirs_status$exists)
  is_valid <- files_valid && dirs_valid
  
  # Build summary message
  if (is_valid) {
    summary <- glue::glue("Valid Ulysses repository at {path}")
    cli::cli_alert_success(summary)
  } else {
    missing_files <- files_status$file[!files_status$exists]
    missing_dirs <- dirs_status$directory[!dirs_status$exists]
    
    missing_items <- c(
      if (length(missing_files) > 0) glue::glue("Missing files: {paste(missing_files, collapse = ', ')}"),
      if (length(missing_dirs) > 0) glue::glue("Missing directories: {paste(missing_dirs, collapse = ', ')}")
    )
    summary <- glue::glue("Invalid Ulysses repository at {path}. {paste(missing_items, collapse = '. ')}")
    cli::cli_alert_danger(summary)
  }
  
  # Return results
  list(
    is_valid = is_valid,
    path = path,
    required_files = files_status,
    required_dirs = dirs_status,
    summary = summary
  )
}
