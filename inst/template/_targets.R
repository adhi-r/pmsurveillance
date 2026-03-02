library(targets)

tar_source("R/")

tar_option_set(
  packages = c(
    "tidyverse", "DBI", "duckdb", "pmsurveillance",
    "lubridate", "glue", "cli", "scales"
  )
)

list(
  # ── Connection ──────────────────────────────────────────────────────────────
  # MotherDuck connection. Refreshed every run.
  tar_target(con, pm_connect(), cue = tar_cue(mode = "always")),

  # ── Data ────────────────────────────────────────────────────────────────────
  # Add your data query targets here. Example:
  # tar_target(my_data, dbGetQuery(con, "SELECT * FROM v_trades_taxonomized WHERE ...")),

  # ── Analysis ────────────────────────────────────────────────────────────────
  # Add your analysis targets here.

  # ── Visualization ───────────────────────────────────────────────────────────
  # Add your plot targets here.

  NULL
)
