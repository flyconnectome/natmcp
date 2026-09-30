# Index on-disk IO and in-memory query helpers.
#
# The index is a single list saved as index.rds (records) plus a human-readable
# manifest.json (provenance / freshness). build_index() writes it; the tools
# read it via .load_index(), which calls fetch_index() to pull the CI-published
# index.rds into the user cache on first use when no local index exists.

#' @noRd
.write_index <- function(index, out_dir) {
  fs::dir_create(out_dir)
  saveRDS(index, file.path(out_dir, "index.rds"))
  jsonlite::write_json(index$manifest, file.path(out_dir, "manifest.json"),
                       auto_unbox = TRUE, pretty = TRUE, null = "null")
  invisible(out_dir)
}

#' Resolve the path to an index.rds
#'
#' `index` may be a directory (containing index.rds) or the file itself. When
#' `NULL`, prefer a packaged index, then a dev-tree `inst/index`.
#' @noRd
.index_path <- function(index = NULL) {
  if (!is.null(index)) {
    if (dir.exists(index)) return(file.path(index, "index.rds"))
    return(index)
  }
  p <- system.file("index", "index.rds", package = "natmcp")
  if (nzchar(p)) return(p)
  dev <- file.path("inst", "index", "index.rds")
  if (file.exists(dev)) return(dev)
  cached <- file.path(tools::R_user_dir("natmcp", "cache"), "index.rds")
  if (file.exists(cached)) return(cached)
  ""
}

#' @noRd
.load_index <- function(index = NULL) {
  p <- .index_path(index)
  why <- NULL
  # First use with no index anywhere: pull the published one into the cache.
  if (is.null(index) && !nzchar(p) &&
      isTRUE(getOption("natmcp.auto_fetch", TRUE))) {
    why <- tryCatch({
      fetch_index()
      NULL
    }, error = function(e) conditionMessage(e))
    p <- .index_path()
  }
  if (!nzchar(p) || !file.exists(p)) {
    stop("No natmcp index found. Run fetch_index() or build_index().",
         if (!is.null(why)) paste0("\nAutomatic fetch failed: ", why))
  }
  readRDS(p)
}

# --- lookups over an in-memory index ----------------------------------------

#' Packages that were successfully indexed (status "ok")
#' @noRd
.indexed_packages <- function(idx) {
  ok <- Filter(function(p) identical(p$status, "ok"), idx$manifest$packages)
  vapply(ok, function(p) p$name, character(1))
}

#' Map bare function name -> ids (a name may be exported by several packages)
#' @noRd
.name_index <- function(idx) {
  ids <- names(idx$signatures)
  if (!length(ids)) return(list())
  bare <- sub("^.*::", "", ids)
  split(ids, bare)
}

#' Fuzzy suggestions for an unresolved symbol
#' @noRd
.suggest_symbols <- function(idx, symbol, n = 5L) {
  ids <- names(idx$signatures)
  if (!length(ids)) return(character(0))
  bare <- sub("^.*::", "", symbol)
  hits <- tryCatch(
    agrep(bare, sub("^.*::", "", ids), value = FALSE,
          max.distance = 0.25, ignore.case = TRUE),
    error = function(e) integer(0)
  )
  utils::head(ids[hits], n)
}

#' Refresh a stale cached index at server start-up
#'
#' Only touches the fetch_index() cache, and only when it is the index the
#' server would use (a packaged or dev-tree index wins in .index_path()) and
#' was last checked more than `natmcp.refresh_days` days ago. Never errors: a
#' failed or slow check leaves the cached index in place.
#' @return `"skipped"`, `"fresh"`, `"checked"` or `"failed"`.
#' @noRd
.maybe_refresh_index <- function(index = NULL) {
  if (!is.null(index) || !isTRUE(getOption("natmcp.auto_fetch", TRUE))) {
    return("skipped")
  }
  cache <- tools::R_user_dir("natmcp", "cache")
  mf <- file.path(cache, "manifest.json")
  p <- .index_path()
  if (!nzchar(p) || !file.exists(mf) ||
      !.same_dir(normalizePath(dirname(p), mustWork = FALSE),
                 normalizePath(cache, mustWork = FALSE))) {
    return("skipped")
  }
  age <- difftime(Sys.time(), file.mtime(mf), units = "days")
  if (age < getOption("natmcp.refresh_days", 7)) return("fresh")
  op <- options(timeout = 30)
  on.exit(options(op))
  tryCatch({
    suppressMessages(fetch_index(cache_dir = cache))
    "checked"
  }, error = function(e) "failed")
}
