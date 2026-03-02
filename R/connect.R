#' Connect to the pm_surveillance MotherDuck database
#'
#' Creates a DBI connection to MotherDuck with the pm_surveillance database
#' attached and active. Requires MOTHERDUCK_TOKEN in environment (typically
#' set in ~/.Renviron).
#'
#' @param db Database name. Default "pm_surveillance".
#' @return A DBI connection object.
#' @export
#' @examples
#' \dontrun{
#' con <- pm_connect()
#' dbGetQuery(con, "SELECT * FROM v_exchange_coverage")
#' pm_disconnect(con)
#' }
pm_connect <- function(db = "pm_surveillance") {
  token <- Sys.getenv("MOTHERDUCK_TOKEN")
  if (token == "") {
    stop(
      "MOTHERDUCK_TOKEN not set.\n",
      "Add to ~/.Renviron: MOTHERDUCK_TOKEN=your_token_here\n",
      "Then restart R.",
      call. = FALSE
    )
  }

  con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
  DBI::dbExecute(con, "INSTALL motherduck")
  DBI::dbExecute(con, "LOAD motherduck")
  DBI::dbExecute(con, sprintf("ATTACH 'md:%s'", db))
  DBI::dbExecute(con, sprintf("USE %s", db))
  con
}


#' Disconnect from MotherDuck
#'
#' @param con A DBI connection from pm_connect().
#' @export
pm_disconnect <- function(con) {
  DBI::dbDisconnect(con, shutdown = TRUE)
}
