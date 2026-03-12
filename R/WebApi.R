
# WebApiConnection ---------------------
WebApiConnection <- R6::R6Class(
  classname = "WebApiConnection",
  public = list(
    initialize = function(baseUrl, authMethod, user, password) {
      # check baseUrl
      checkmate::assert_string(x = baseUrl, min.chars = 1)
      private[[".baseUrl"]] <- baseUrl
      # check authMethod
      checkmate::assert_string(x = authMethod, min.chars = 1)
      private[[".authMethod"]] <- authMethod
      # check user
      checkmate::assert_string(x = user, min.chars = 1)
      private[[".user"]] <- user
      # check user
      checkmate::assert_string(x = password, min.chars = 1)
      private[[".password"]] <- password
    },

    checkUser = function() {
      usr <- private$.user
      cli::cat_line(glue::glue("- user: {crayon::green(usr)}"))
      invisible(usr)
    },

    checkPassword = function() {
      pwd <- private$.password
      cli::cat_line(glue::glue("- password: {crayon::hidden(pwd)}"))
      invisible(pwd)
    },

    checkBaseUrl = function() {
      baseUrl <- private$.baseUrl
      cli::cat_line(glue::glue("- baseUrl: {crayon::green(baseUrl)}"))
      invisible(baseUrl)
    },

    checkAuthMethod = function() {
      am <- private$.authMethod
      cli::cat_line(glue::glue("- authMethod: {crayon::green(am)}"))
      invisible(am)
    },

    getWebApiUrl = function() {
      baseUrl <- private$.baseUrl
      return(baseUrl)
    },

    checkAtlasCredentials = function() {

      headerTxt <- glue::glue_col("Checking Atlas Credentials from {cyan .Renviron}")
      cli::cat_rule(headerTxt)
      cli::cat_line()

      self$checkBaseUrl()
      self$checkAuthMethod()
      self$checkUser()
      self$checkPassword()

      cli::cat_line()
      messageTxt <- glue::glue_col("To modify credentials run function {magenta 'usethis::edit_r_environ()'} and change system variables for Atlas credentials")
      cli::cat_bullet(messageTxt, bullet = "warning", bullet_col = "yellow")

    },

    getCohortDefinition = function(cohortId) {

      if (is.null(private$.bearerToken)) {
        private$authorizeWebApi()
      }
      baseUrl <- private$.baseUrl
      req <- glue::glue("{baseUrl}/cohortdefinition/{cohortId}") |>
        httr2::request() |>
        httr2::req_auth_bearer_token(token = private$.bearerToken)
      resp <- httr2::req_perform(req = req)
      cd <- httr2::resp_body_json(resp)
      cdExp <- RJSONIO::fromJSON(cd$expression, nullValue = NA, digits = 23)

      tb <- tibble::tibble(
        id = cd$id,
        name = cd$name,
        expression = formatCohortExpression(cdExp),
        saveName = glue::glue("{id}_{name}") |> snakecase::to_snake_case()
      )

      return(tb)
    },

    getConceptSetDefinition = function(conceptSetId) {

      if (is.null(private$.bearerToken)) {
        private$authorizeWebApi()
      }
      baseUrl <- private$.baseUrl
      req <- glue::glue("{baseUrl}/conceptset/{conceptSetId}") |>
        httr2::request() |>
        httr2::req_auth_bearer_token(token = private$.bearerToken)
      resp <- httr2::req_perform(req = req)
      cs <- httr2::resp_body_json(resp)

      # get the expression from the right spot
      csExp <-pluckConceptSetExpression(
        conceptSetId = conceptSetId,
        baseUrl = baseUrl,
        bearerToken = private$.bearerToken
      )

      tb <- tibble::tibble(
        id = cs$id,
        name = cs$name,
        expression = csExp,
        saveName = glue::glue("{id}_{name}") |> snakecase::to_snake_case()
      )

      return(tb)
    }

  ),
  private = list(
    .baseUrl = NULL,
    .authMethod = NULL,
    .user = NULL,
    .password = NULL,
    .bearerToken = NULL,

    # functions
    authorizeWebApi = function() {

      baseUrl <- private$.baseUrl
      authMethod <- private$.authMethod
      user <- private$.user
      password <- private$.password

      cli::cat_bullet(
        glue::glue("Authorizing Web Api connection for {crayon::cyan(baseUrl)}"),
        bullet = "pointer",
        bullet_col = "yellow"
      )

      authUrl <- paste0(baseUrl, glue::glue("/user/login/{authMethod}"))

      req <- httr2::request(authUrl) |>
        httr2::req_body_form(
          login = user,
          password = password
        )

      bearerToken <- httr2::req_perform(req)$headers$Bearer

      .setString(private = private, key = ".bearerToken", value = bearerToken)

      invisible(bearerToken)
    }
  )
)


CirceCohortsToLoad <- R6::R6Class(
  classname = "CirceCohortsToLoad",
  public = list(
    initialize = function(cohortsToLoadTable,
                          webApiCreds) {
      # check and init cohortsToLoadTable
      checkmate::assert_data_frame(
        x = cohortsToLoadTable,
        min.rows = 1,
        ncols = 3
      )
      private[[".cohortsToLoadTable"]] <- cohortsToLoadTable

      # check webApi creds
      checkmate::assert_class(x = webApiCreds, classes = "WebApiCreds")
      private[[".webApiCreds"]] <- webApiCreds
    },

    getCirce = function() {

      private$.webApiCreds$authorizeWebApi()
      circeIds <- private$.cohortsToLoadTable$atlasId
      circeTb <- vector('list', length = length(circeIds))
      for (i in seq_along(circeIds)) {
        circeTb[[i]] <- grabCohortFromWebApi(
          cohortId = circeIds[i],
          baseUrl = private$.webApiCreds$getWebApiUrl()
        )
      }
      circeTb2 <- do.call('rbind', circeTb)
      circeTb3 <- private$.cohortsToLoadTable |>
        dplyr::left_join(
          circeTb2, by = c('atlasId' = "id")
        ) |>
        dplyr::mutate(
          savePath = fs::path("inputs/cohorts/json", analysisType, saveName, ext = "json")
        ) |>
        dplyr::select(
          atlasId, assetLabel, analysisType, expression, saveName, savePath
        )

      return(circeTb3)
    }


  ),
  private = list(
    .webApiCreds = NULL,
    .cohortsToLoadTable = NULL
  ),
  active = list(
    cohortsToLoadTable = function(value) {
      if(missing(value)) {
        res <- private$.cohortsToLoadTable
        return(res)
      }
      checkmate::assert_data_frame(
        x = value,
        min.rows = 1,
        ncols = 3
      )
      private[[".cohortsToLoadTable"]] <- value

      cli::cat_bullet(
        glue::glue("Replaced {crayon::cyan('cohortsToLoadTable')} with {crayon::green(value)}"),
        bullet = "info",
        bullet_col = "blue"
      )
    }
  )
)


CirceConceptSetsToLoad <- R6::R6Class(
  classname = "CirceConceptSetsToLoad",
  public = list(
    initialize = function(conceptSetsToLoadTable,
                          webApiCreds) {
      # check and init cohortsToLoadTable
      checkmate::assert_data_frame(
        x = conceptSetsToLoadTable,
        min.rows = 1,
        ncols = 3
      )
      private[[".conceptSetsToLoadTable"]] <- conceptSetsToLoadTable

      # check webApi creds
      checkmate::assert_class(x = webApiCreds, classes = "WebApiCreds")
      private[[".webApiCreds"]] <- webApiCreds
    },

    getCirce = function() {

      private$.webApiCreds$authorizeWebApi()
      circeIds <- private$.conceptSetsToLoadTable$atlasId
      circeTb <- vector('list', length = length(circeIds))
      for (i in seq_along(circeIds)) {
        circeTb[[i]] <- grabConceptSetFromWebApi(
          conceptSetId = circeIds[i],
          baseUrl = private$.webApiCreds$getWebApiUrl()
        )
      }
      circeTb2 <- do.call('rbind', circeTb)
      circeTb3 <- private$.conceptSetsToLoadTable |>
        dplyr::left_join(
          circeTb2, by = c('atlasId' = "id")
        ) |>
        dplyr::mutate(
          savePath = fs::path("inputs/conceptSets/json", analysisType, saveName, ext = "json")
        ) |>
        dplyr::select(
          atlasId, assetLabel, analysisType, expression, saveName, savePath
        )

      return(circeTb3)
    }


  ),
  private = list(
    .webApiCreds = NULL,
    .conceptSetsToLoadTable = NULL
  ),
  active = list(
    conceptSetsToLoadTable = function(value) {
      if(missing(value)) {
        res <- private$.conceptSetsToLoadTable
        return(res)
      }
      checkmate::assert_data_frame(
        x = value,
        min.rows = 1,
        ncols = 3
      )
      private[[".conceptSetsToLoadTable"]] <- value

      cli::cat_bullet(
        glue::glue("Replaced {crayon::cyan('conceptSetsToLoadTable')} with {crayon::green(value)}"),
        bullet = "info",
        bullet_col = "blue"
      )
    }
  )
)

# Atlas Connection ---------------

#' @title Set Atlas Connection
#' @returns an R6 class of WebApiConnection
#' @export
setAtlasConnection <- function() {

  atlasCon <- WebApiConnection$new(
    baseUrl = Sys.getenv("atlasBaseUrl"),
    authMethod = Sys.getenv("atlasAuthMethod"),
    user = Sys.getenv("atlasUser"),
    password = Sys.getenv("atlasPassword")
  )
  return(atlasCon)
}

pluckConceptSetExpression <- function(conceptSetId, baseUrl, bearerToken) {
  req <- glue::glue("{baseUrl}/conceptset/{conceptSetId}/expression") |>
    httr2::request() |>
    httr2::req_auth_bearer_token(token = bearerToken)
  resp <- httr2::req_perform(req = req)
  csExp <- httr2::resp_body_json(resp)
  csExp2 <- RJSONIO::toJSON(csExp, digits = 23, pretty = TRUE)
  return(csExp2)
}


formatCohortExpression <- function(expression) {
  # reformat to standard circe
  circe <- list(
    'ConceptSets' = expression$ConceptSets,
    'PrimaryCriteria' = expression$PrimaryCriteria,
    'AdditionalCriteria' = expression$AdditionalCriteria,
    'QualifiedLimit' = expression$QualifiedLimit,
    'ExpressionLimit' = expression$ExpressionLimit,
    'InclusionRules' = expression$InclusionRules,
    'EndStrategy' = expression$EndStrategy,
    'CensoringCriteria' = expression$CensoringCriteria,
    'CollapseSettings' = expression$CollapseSettings,
    'CensorWindow' = expression$CensorWindow,
    'cdmVersionRange' = expression$cdmVersionRange
  )
  if (is.null(circe$AdditionalCriteria)) {
    circe$AdditionalCriteria <- NULL
  }
  if (is.null(circe$EndStrategy)) {
    circe$EndStrategy <- NULL
  }

  circeJson <- RJSONIO::toJSON(circe, digits = 23, pretty = TRUE)

  return(circeJson)
}



#' @title Template for setting Atlas Credentials
#' @returns no return; prints info to console
#' @export
templateAtlasCredentials <- function() {

  credsToSetTxt <- c("atlasBaseUrl='https://organization-atlas.com/WebAPI'",
                     "atlasAuthMethod='ad'",
                     "atlasUser='atlas.user@company.com'",
                     "atlasPassword='TisASecret'") |>
    glue::glue_collapse(sep = "\n")

  headerTxt <- "Atlas Credential Template"
  instructionsTxt1 <- "Providing a template for setting Atlas Credentials. Please alter to the correct credentials!!!"
  instructionsTxt2 <- glue::glue_col("To set Atlas Credentials run function {magenta 'usethis::edit_r_environ()'} and paste template to {cyan .Renviron} changing the credentials accordingly.")
  noteTxt <- "The variable name of the atlas credentials must be in this format!!!"

  cli::cat_rule(headerTxt)
  cli::cat_line()
  cli::cat_bullet(instructionsTxt1, bullet = "info", bullet_col = "blue")
  cli::cat_bullet(instructionsTxt2, bullet = "info", bullet_col = "blue")
  cli::cat_bullet(noteTxt, bullet = "warning", bullet_col = "yellow")
  cli::cat_line()
  cli::cat_line(credsToSetTxt)

  invisible(credsToSetTxt)
}





getAtlasAuthBearerToken <- function(baseUrl, authMethod, user, password) {

  authUrl <- paste0(baseUrl, glue::glue("user/login/{authMethod}"))

  req <- httr2::request(authUrl) |>
    httr2::req_body_form(
      login = user,
      password = password
    )

  bearerToken <- httr2::req_perform(req)$headers$Bearer

  return(bearerToken)
}



