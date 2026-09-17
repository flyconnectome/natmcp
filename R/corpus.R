# Tier-3 curated corpus: the hand-authored guide (altitude map) and the
# nv_datasets facts table, folded into the index at build time so the served
# tools have a single consumption path (always the fetched index).

#' Load the curated guide markdown that ships with the package
#' @noRd
.load_guide <- function() {
  path <- system.file("corpus", "guide.md", package = "natmcp")
  if (!nzchar(path) || !file.exists(path)) return(NA_character_)
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

#' Load the curated nv_datasets table (works installed or under load_all)
#' @noRd
.load_datasets <- function() {
  e <- new.env()
  ok <- tryCatch({
    utils::data("nv_datasets", package = "natmcp", envir = e)
    TRUE
  }, error = function(err) FALSE)
  if (!ok || !exists("nv_datasets", envir = e)) return(NULL)
  as.data.frame(get("nv_datasets", envir = e), stringsAsFactors = FALSE)
}

#' Convert the dataset data frame to a list of row records
#' @noRd
.datasets_records <- function(df) {
  if (is.null(df) || !nrow(df)) return(list())
  recs <- lapply(seq_len(nrow(df)), function(i) as.list(df[i, , drop = FALSE]))
  stats::setNames(recs, df$id)
}

#' Auto-seed a one-line role per package from its DESCRIPTION Title
#' @noRd
.package_roles <- function(packages) {
  roles <- list()
  for (p in packages) {
    title <- tryCatch(
      suppressWarnings(utils::packageDescription(p, fields = "Title")),
      error = function(e) NA_character_)
    if (length(title) != 1L || is.na(title)) next
    roles[[p]] <- gsub("[[:space:]]+", " ", trimws(title))
  }
  roles
}
