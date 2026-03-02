# Analysis helper functions
#
# Add your query and analysis functions here.
# Use pm_catalog(con) to discover available views and tables.
#
# Example:
#
# get_daily_volume <- function(con, exchange = NULL, days = 30) {
#   query <- glue::glue("
#     SELECT * FROM v_daily_volume
#     WHERE source_date >= CURRENT_DATE - {days}
#     {if (!is.null(exchange)) glue::glue(\"AND exchange = '{exchange}'\") else ''}
#     ORDER BY source_date
#   ")
#   dbGetQuery(con, query)
# }
