#' Create a new PM Surveillance analysis project
#'
#' Scaffolds a new R analysis project pre-wired with MotherDuck connection,
#' targets pipeline, and a CLAUDE.md that gives Claude Code full context
#' about the pm_surveillance data model.
#'
#' @param path Path where the project should be created.
#' @param git_init Whether to initialize a git repository. Default TRUE.
#' @return The path to the created project (invisibly).
#' @export
#' @examples
#' \dontrun{
#' pm_new_project("~/my-analysis")
#' # Then open in Positron: File > Open Folder > ~/my-analysis
#' }
pm_new_project <- function(path, git_init = TRUE) {
  path <- normalizePath(path, mustWork = FALSE)

  if (dir.exists(path)) {
    stop("Directory already exists: ", path, call. = FALSE)
  }

  # Find template directory

  template_dir <- system.file("template", package = "pmsurveillance")
  if (template_dir == "") {
    stop("Template files not found. Is pmsurveillance installed correctly?", call. = FALSE)
  }

  # Copy template
  dir.create(path, recursive = TRUE)
  file.copy(
    list.files(template_dir, full.names = TRUE, all.files = TRUE, no.. = TRUE),
    path,
    recursive = TRUE
  )

  # Ensure R/ subdirectory exists
  r_dir <- file.path(path, "R")
  if (!dir.exists(r_dir)) dir.create(r_dir)

  # Ensure output/ directory exists
  out_dir <- file.path(path, "output")
  if (!dir.exists(out_dir)) dir.create(out_dir)

  # Git init
  if (git_init) {
    withr::with_dir(path, {
      system2("git", "init", stdout = FALSE, stderr = FALSE)
    })
  }

  cli::cli_h1("Project created: {basename(path)}")
  cli::cli_bullets(c(
    "i" = "Open in Positron: File > Open Folder > {path}",
    "i" = "CLAUDE.md included \u2014 Claude Code knows the data model",
    "i" = "Run targets::tar_make() to execute the pipeline",
    "*" = "Edit R/helpers.R to add your analysis functions"
  ))

  invisible(path)
}
