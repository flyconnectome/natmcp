# Internal constants and small helpers shared across the builder and server.

# Bump when the on-disk index layout changes (index.rds / manifest.json shape).
.schema_version <- "2"

# Bump when extraction logic changes in a way that should invalidate a rebuild.
.extractor_version <- "0.1.0"

#' Null-coalescing helper
#' @noRd
`%||%` <- function(a, b) if (is.null(a)) b else a

#' Is a package installed (namespace loadable / on the library path)?
#' @noRd
.is_installed <- function(pkg) {
  isTRUE(nzchar(system.file(package = pkg)))
}
