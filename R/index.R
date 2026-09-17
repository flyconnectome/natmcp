# Index on-disk IO and in-memory query helpers.
#
# The index is a single list saved as index.rds (records) plus a human-readable
# manifest.json (provenance / freshness). build_index() writes it; the tools
# read it via .load_index(). fetch_index() (Phase 7) will pull a CI-published
# index.rds; until then tools load a locally built or packaged index.

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
  ""
}

#' @noRd
.load_index <- function(index = NULL) {
  p <- .index_path(index)
  if (!nzchar(p) || !file.exists(p)) {
    stop("No natmcp index found. Run build_index() (Phase 2) or fetch_index().")
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
