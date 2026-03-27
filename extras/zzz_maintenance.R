get_package_exports <- function() {
  # Get exported names using the official method
  exports <- getNamespaceExports("picard")
  
  # Load package namespace
  ns <- getNamespace("picard")

  # Categorize exports
  r6_classes <- character(0)
  regular_funcs <- character(0)

  for (name in exports) {
    tryCatch({
      obj <- get(name, envir = ns)
      if (inherits(obj, "R6ClassGenerator")) {
        r6_classes <- c(r6_classes, name)
      } else if (is.function(obj)) {
        regular_funcs <- c(regular_funcs, name)
      }
    }, error = function(e) {
      # Skip if object cannot be retrieved
      NULL
    })
  }

  # Create summary
  summary_df <- data.frame(
    name = c(r6_classes, regular_funcs),
    type = c(rep("R6Class", length(r6_classes)), rep("Function", length(regular_funcs))),
    documented = as.logical(NA),
    stringsAsFactors = FALSE
  )

  # Check if documented by looking for .Rd files
  man_dir <- system.file("man", package = "picard")
  if (dir.exists(man_dir)) {
    rd_files <- list.files(man_dir, pattern = "\\.Rd$")
    rd_names <- sub("\\.Rd$", "", rd_files)
    summary_df$documented <- summary_df$name %in% rd_names
  }

  return(
    list(
      r6_classes = sort(r6_classes),
      functions = sort(regular_funcs),
      all_exports = sort(exports),
      summary = summary_df[order(summary_df$type, summary_df$name), ]
    )
  )
}


validate_documentation <- function(show_missing = TRUE) {
  exports_info <- get_package_exports()
  summary_df <- exports_info$summary

  # Summary statistics
  total <- nrow(summary_df)
  documented <- sum(summary_df$documented, na.rm = TRUE)
  undocumented <- sum(!summary_df$documented, na.rm = TRUE)

  cli::cli_h2("Package Documentation Status")
  cli::cli_rule()

  cli::cli_bullets(c(
    "v" = "{.strong Total Exports:} {total}",
    "v" = "{.strong Documented:} {documented}",
    "!" = "{.strong Undocumented:} {undocumented}"
  ))

  if (show_missing && undocumented > 0) {
    cli::cli_h3("Undocumented Exports")
    missing <- summary_df[!summary_df$documented, ]

    for (type in unique(missing$type)) {
      type_items <- missing[missing$type == type, "name"]
      cli::cli_bullets(c("i" = "{.strong {type}s}: {paste(type_items, collapse = ', ')}"))
    }
  }

  # Summary by type
  cli::cli_h3("Summary by Type")
  by_type <- summary_df |>
    dplyr::group_by(type, documented) |>
    dplyr::summarise(count = dplyr::n(), .groups = "drop") |>
    tidyr::pivot_wider(names_from = documented, values_from = count, values_fill = 0)

  print(by_type)

  invisible(summary_df)
}

#' Update pkgdown Reference in _pkgdown.yml
#'
#' Analyzes current package exports and updates the reference section in _pkgdown.yml
#' based on function/class categories. Overwrites the existing reference section while 
#' preserving other sections.
#'
#' @return Invisibly returns the path to the updated file.
#'
#' @examples
#' \dontrun{
#'   update_pkgdown_reference()
#' }
#'
#' @noRd
update_pkgdown_reference <- function() {
  exports_info <- get_package_exports()
  funcs <- exports_info$functions

  cli::cli_h2("Updating _pkgdown.yml Reference Section")
  cli::cli_rule()

  # Define categories
  make_funcs <- grep("^make", funcs, value = TRUE)
  init_funcs <- grep("^init", funcs, value = TRUE)
  build_funcs <- grep("^build", funcs, value = TRUE)
  create_funcs <- grep("^create", funcs, value = TRUE)
  set_funcs <- grep("^set", funcs, value = TRUE)
  get_funcs <- grep("^get", funcs, value = TRUE)
  load_funcs <- grep("^load", funcs, value = TRUE)
  exec_funcs <- grep("^exec", funcs, value = TRUE)

  # Remaining functions
  categorized <- c(
    make_funcs, init_funcs, build_funcs, create_funcs,
    set_funcs, get_funcs, load_funcs, exec_funcs
  )
  other_funcs <- setdiff(funcs, categorized)

  # Build YAML reference section as a vector of lines
  reference_lines <- c("reference:")

  # Core Classes
  if (length(exports_info$r6_classes) > 0) {
    reference_lines <- c(reference_lines,
      "  - title: \"Core Classes\"",
      "    desc: \"Main R6 classes for package functionality\"",
      "    contents:"
    )
    for (cls in exports_info$r6_classes) {
      reference_lines <- c(reference_lines, glue::glue("      - {cls}"))
    }
    reference_lines <- c(reference_lines, "")
  }

  # Categorized functions
  if (length(make_funcs) > 0) {
    reference_lines <- c(reference_lines,
      "  - title: \"Creation Functions\"",
      "    desc: \"Functions for creating objects and structures (make*)\"",
      "    contents:"
    )
    for (func in sort(make_funcs)) {
      reference_lines <- c(reference_lines, glue::glue("      - {func}"))
    }
    reference_lines <- c(reference_lines, "")
  }

  if (length(init_funcs) > 0) {
    reference_lines <- c(reference_lines,
      "  - title: \"Initialization Functions\"",
      "    desc: \"Functions for initializing components (init*)\"",
      "    contents:"
    )
    for (func in sort(init_funcs)) {
      reference_lines <- c(reference_lines, glue::glue("      - {func}"))
    }
    reference_lines <- c(reference_lines, "")
  }

  if (length(build_funcs) > 0) {
    reference_lines <- c(reference_lines,
      "  - title: \"Build Functions\"",
      "    desc: \"Functions for building study components (build*)\"",
      "    contents:"
    )
    for (func in sort(build_funcs)) {
      reference_lines <- c(reference_lines, glue::glue("      - {func}"))
    }
    reference_lines <- c(reference_lines, "")
  }

  if (length(create_funcs) > 0) {
    reference_lines <- c(reference_lines,
      "  - title: \"Create Functions\"",
      "    desc: \"Functions for creating new objects (create*)\"",
      "    contents:"
    )
    for (func in sort(create_funcs)) {
      reference_lines <- c(reference_lines, glue::glue("      - {func}"))
    }
    reference_lines <- c(reference_lines, "")
  }

  if (length(exec_funcs) > 0) {
    reference_lines <- c(reference_lines,
      "  - title: \"Execution Functions\"",
      "    desc: \"Functions for executing study tasks (exec*)\"",
      "    contents:"
    )
    for (func in sort(exec_funcs)) {
      reference_lines <- c(reference_lines, glue::glue("      - {func}"))
    }
    reference_lines <- c(reference_lines, "")
  }

  if (length(set_funcs) > 0) {
    reference_lines <- c(reference_lines,
      "  - title: \"Configuration Functions\"",
      "    desc: \"Functions for configuration and setup (set*)\"",
      "    contents:"
    )
    for (func in sort(c(set_funcs, get_funcs))) {
      reference_lines <- c(reference_lines, glue::glue("      - {func}"))
    }
    reference_lines <- c(reference_lines, "")
  }

  if (length(load_funcs) > 0) {
    reference_lines <- c(reference_lines,
      "  - title: \"Loading Functions\"",
      "    desc: \"Functions for loading and importing data (load*)\"",
      "    contents:"
    )
    for (func in sort(load_funcs)) {
      reference_lines <- c(reference_lines, glue::glue("      - {func}"))
    }
    reference_lines <- c(reference_lines, "")
  }

  if (length(other_funcs) > 0) {
    reference_lines <- c(reference_lines,
      "  - title: \"Utility Functions\"",
      "    desc: \"Other utility and helper functions\"",
      "    contents:"
    )
    for (func in sort(other_funcs)) {
      reference_lines <- c(reference_lines, glue::glue("      - {func}"))
    }
    reference_lines <- c(reference_lines, "")
  }

  # Read existing _pkgdown.yml
  pkgdown_path <- here::here("_pkgdown.yml")

  if (file.exists(pkgdown_path)) {
    existing_lines <- readLines(pkgdown_path)
    
    # Find the line where "reference:" starts
    ref_start <- grep("^reference:", existing_lines)
    
    if (length(ref_start) > 0) {
      # Keep everything before "reference:"
      content_before_reference <- existing_lines[1:(ref_start[1] - 1)]
    } else {
      # If no reference section exists, keep all existing content
      content_before_reference <- existing_lines
    }
  } else {
    content_before_reference <- character(0)
  }

  # Combine - remove trailing empty lines and add new reference
  final_lines <- c(content_before_reference, reference_lines)
  
  # Remove excessive trailing empty lines
  while (length(final_lines) > 0 && final_lines[length(final_lines)] == "") {
    final_lines <- final_lines[-length(final_lines)]
  }

  # Always add development section with proper YAML formatting
  final_lines <- c(final_lines, "", "development:", "  mode: \"auto\"")

  # Write back to file
  writeLines(final_lines, con = pkgdown_path)

  cli::cli_alert_success("Updated {.file _pkgdown.yml}")
  cli::cli_bullets(c(
    "i" = "Total exports documented: {length(exports_info$all_exports)}",
    "i" = "R6 Classes: {length(exports_info$r6_classes)}",
    "i" = "Functions: {length(funcs)}"
  ))

  invisible(pkgdown_path)
}

#' Generate pkgdown Reference Suggestions (Display Only)
#'
#' Analyzes current package exports and displays suggested reference structure
#' for _pkgdown.yml. Use update_pkgdown_reference() to actually update the file.
#'
#' @return Invisibly returns the suggested reference structure as a list.
#'   The output is also printed as YAML-formatted text.
#'
#' @examples
#' \dontrun{
#'   suggest_pkgdown_structure()
#' }
#'
#' @noRd
suggest_pkgdown_structure <- function() {
  exports_info <- get_package_exports()

  cli::cli_h2("Suggested pkgdown Reference Structure")
  cli::cli_rule()

  # Categorize functions by prefix
  funcs <- exports_info$functions

  # Define categories
  make_funcs <- grep("^make", funcs, value = TRUE)
  init_funcs <- grep("^init", funcs, value = TRUE)
  build_funcs <- grep("^build", funcs, value = TRUE)
  create_funcs <- grep("^create", funcs, value = TRUE)
  set_funcs <- grep("^set", funcs, value = TRUE)
  get_funcs <- grep("^get", funcs, value = TRUE)
  load_funcs <- grep("^load", funcs, value = TRUE)
  exec_funcs <- grep("^exec", funcs, value = TRUE)

  # Remaining functions
  categorized <- c(
    make_funcs, init_funcs, build_funcs, create_funcs,
    set_funcs, get_funcs, load_funcs, exec_funcs
  )
  other_funcs <- setdiff(funcs, categorized)

  # Print YAML structure
  cat("reference:\n")

  # Core Classes
  if (length(exports_info$r6_classes) > 0) {
    cat("  - title: \"Core Classes\"\n")
    cat("    desc: \"Main R6 classes for package functionality\"\n")
    cat("    contents:\n")
    for (cls in exports_info$r6_classes) {
      cat(glue::glue("      - {cls}\n"))
    }
    cat("\n")
  }

  # Categorized functions
  if (length(make_funcs) > 0) {
    cat("  - title: \"Creation Functions\"\n")
    cat("    desc: \"Functions for creating objects and structures (make*)\"\n")
    cat("    contents:\n")
    for (func in sort(make_funcs)) {
      cat(glue::glue("      - {func}\n"))
    }
    cat("\n")
  }

  if (length(init_funcs) > 0) {
    cat("  - title: \"Initialization Functions\"\n")
    cat("    desc: \"Functions for initializing components (init*)\"\n")
    cat("    contents:\n")
    for (func in sort(init_funcs)) {
      cat(glue::glue("      - {func}\n"))
    }
    cat("\n")
  }

  if (length(build_funcs) > 0) {
    cat("  - title: \"Build Functions\"\n")
    cat("    desc: \"Functions for building study components (build*)\"\n")
    cat("    contents:\n")
    for (func in sort(build_funcs)) {
      cat(glue::glue("      - {func}\n"))
    }
    cat("\n")
  }

  if (length(create_funcs) > 0) {
    cat("  - title: \"Create Functions\"\n")
    cat("    desc: \"Functions for creating new objects (create*)\"\n")
    cat("    contents:\n")
    for (func in sort(create_funcs)) {
      cat(glue::glue("      - {func}\n"))
    }
    cat("\n")
  }

  if (length(exec_funcs) > 0) {
    cat("  - title: \"Execution Functions\"\n")
    cat("    desc: \"Functions for executing study tasks (exec*)\"\n")
    cat("    contents:\n")
    for (func in sort(exec_funcs)) {
      cat(glue::glue("      - {func}\n"))
    }
    cat("\n")
  }

  if (length(set_funcs) > 0) {
    cat("  - title: \"Configuration Functions\"\n")
    cat("    desc: \"Functions for configuration and setup (set*)\"\n")
    cat("    contents:\n")
    for (func in sort(c(set_funcs, get_funcs))) {
      cat(glue::glue("      - {func}\n"))
    }
    cat("\n")
  }

  if (length(load_funcs) > 0) {
    cat("  - title: \"Loading Functions\"\n")
    cat("    desc: \"Functions for loading and importing data (load*)\"\n")
    cat("    contents:\n")
    for (func in sort(load_funcs)) {
      cat(glue::glue("      - {func}\n"))
    }
    cat("\n")
  }

  if (length(other_funcs) > 0) {
    cat("  - title: \"Utility Functions\"\n")
    cat("    desc: \"Other utility and helper functions\"\n")
    cat("    contents:\n")
    for (func in sort(other_funcs)) {
      cat(glue::glue("      - {func}\n"))
    }
    cat("\n")
  }

  cli::cli_alert_info("Copy the output above to your _pkgdown.yml file")

  invisible(
    list(
      r6_classes = exports_info$r6_classes,
      make = make_funcs,
      init = init_funcs,
      build = build_funcs,
      create = create_funcs,
      exec = exec_funcs,
      set = set_funcs,
      get = get_funcs,
      load = load_funcs,
      other = other_funcs
    )
  )
}

package_maintenance_report <- function() {
  cli::cli_h1("PICARD Package Maintenance Report")
  cli::cli_rule()

  # Get basic package info
  desc <- read.dcf(system.file("DESCRIPTION", package = "picard"))
  version <- desc[1, "Version"]
  date <- Sys.Date()

  cli::cli_bullets(c(
    "i" = "Package: {.strong picard}",
    "i" = "Version: {.strong {version}}",
    "i" = "Report Date: {.strong {date}}"
  ))

  cli::cli_rule()

  # Documentation validation
  validate_documentation(show_missing = TRUE)

  cli::cli_rule()

  # Suggest structure
  cli::cli_alert_info("Run suggest_pkgdown_structure() to see YAML suggestions for _pkgdown.yml")

  invisible(NULL)
}
