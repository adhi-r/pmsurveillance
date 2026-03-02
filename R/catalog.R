#' Browse the pm_surveillance schema catalog
#'
#' Queries the schema_catalog table in MotherDuck and returns a tibble
#' describing all available tables and views. When called interactively,
#' also prints a formatted summary grouped by layer.
#'
#' @param con A DBI connection from pm_connect(). If NULL, connects and
#'   disconnects automatically.
#' @param layer Optional filter: "core", "taxonomy", "matching", "regulatory",
#'   "analysis", or "operational".
#' @return A tibble with columns: object_name, object_type, layer, description,
#'   key_columns, join_hint, example_query.
#' @export
#' @examples
#' \dontrun{
#' con <- pm_connect()
#' pm_catalog(con)
#' pm_catalog(con, layer = "matching")
#' }
pm_catalog <- function(con = NULL, layer = NULL) {
  auto_con <- is.null(con)
  if (auto_con) con <- pm_connect()
  on.exit(if (auto_con) pm_disconnect(con))

  query <- "SELECT object_name, object_type, layer, description, key_columns, join_hint, example_query FROM schema_catalog ORDER BY layer, object_type, object_name"
  catalog <- tibble::as_tibble(DBI::dbGetQuery(con, query))

  if (!is.null(layer)) {
    catalog <- catalog[catalog$layer == layer, ]
  }

  if (interactive()) {
    .print_catalog(catalog)
  }

  invisible(catalog)
}


#' List available views
#'
#' @inheritParams pm_catalog
#' @return A tibble of views from the schema catalog.
#' @export
pm_views <- function(con = NULL) {
  cat <- pm_catalog(con)
  cat[cat$object_type == "view", ]
}


#' List available tables
#'
#' @inheritParams pm_catalog
#' @return A tibble of tables from the schema catalog.
#' @export
pm_tables <- function(con = NULL) {
  cat <- pm_catalog(con)
  cat[cat$object_type == "table", ]
}


#' @keywords internal
.print_catalog <- function(catalog) {
  layers <- unique(catalog$layer)
  layer_labels <- c(
    core = "Core Data",
    taxonomy = "Taxonomy",
    matching = "Cross-Exchange Matching",
    regulatory = "Regulatory Intelligence",
    analysis = "Analysis Views",
    operational = "Operational"
  )

  for (l in layers) {
    label <- if (l %in% names(layer_labels)) layer_labels[[l]] else l
    cli::cli_h2(label)
    subset <- catalog[catalog$layer == l, ]
    for (i in seq_len(nrow(subset))) {
      row <- subset[i, ]
      icon <- if (row$object_type == "view") "v" else "T"
      cli::cli_alert_info("[{icon}] {.strong {row$object_name}} \u2014 {row$description}")
    }
  }

  cli::cli_alert_success(
    "Total: {nrow(catalog)} objects. Use $example_query for starter SQL."
  )
}
