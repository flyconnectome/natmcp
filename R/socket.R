# Where R sessions and the natmcp server meet.
#
# mcptools puts its IPC sockets (and shared secret) in a socket directory,
# fixed when mcptools is loaded. On macOS that defaults to $TMPDIR/mcptools,
# but apps launched by launchd (e.g. Claude Desktop) can inherit a different
# TMPDIR, or none, from a terminal or RStudio. The server Claude launches and
# the user's session then look in different places and never find each other.
# natmcp pins MCPTOOLS_SOCKET_DIR to the per-user temp dir reported by
# `getconf DARWIN_USER_TEMP_DIR` (the usual TMPDIR) on both sides, before
# mcptools is loaded. natmcp only calls mcptools via `::`, so loading natmcp
# does not load mcptools.

#' The socket directory natmcp uses on macOS; NULL elsewhere
#' @noRd
.canonical_socket_dir <- function() {
  if (!identical(Sys.info()[["sysname"]], "Darwin")) return(NULL)
  d <- tryCatch(
    suppressWarnings(system2("getconf", "DARWIN_USER_TEMP_DIR",
                             stdout = TRUE, stderr = FALSE)),
    error = function(e) character())
  if (!length(d) || !nzchar(d[1])) return(NULL)
  file.path(sub("/+$", "", d[1]), "mcptools")
}

#' Pin MCPTOOLS_SOCKET_DIR to the canonical dir if it is still possible
#'
#' @return `"user"` (already set, left alone), `"pinned"`, `"late"` (mcptools
#'   already loaded, so too late to change) or `"default"` (no canonical dir,
#'   e.g. not macOS).
#' @noRd
.pin_socket_dir <- function(canonical = .canonical_socket_dir(),
                            loaded = isNamespaceLoaded("mcptools")) {
  if (nzchar(Sys.getenv("MCPTOOLS_SOCKET_DIR"))) return("user")
  if (is.null(canonical)) return("default")
  if (isTRUE(loaded)) return("late")
  Sys.setenv(MCPTOOLS_SOCKET_DIR = canonical)
  "pinned"
}

#' The socket directory mcptools is actually using in this process
#' @noRd
.socket_dir_in_use <- function() {
  if (!isNamespaceLoaded("mcptools")) return(NULL)
  tryCatch(utils::getFromNamespace("socket_dir_in_use", "mcptools")(),
           error = function(e) NULL)
}

#' @noRd
.same_dir <- function(a, b) {
  norm <- function(x) sub("/+$", "", gsub("/+", "/", x))
  identical(norm(a), norm(b))
}

#' Warn if this session listens somewhere the natmcp server won't look
#' @noRd
.warn_socket_mismatch <- function(in_use = .socket_dir_in_use(),
                                  canonical = .canonical_socket_dir()) {
  if (is.null(in_use) || is.null(canonical) || .same_dir(in_use, canonical)) {
    return(invisible(FALSE))
  }
  cli::cli_warn(c(
    "Claude may not find this session: it listens in {.path {in_use}}, but
     the natmcp server looks in {.path {canonical}}.",
    i = "mcptools was loaded before natmcp could set the location. Restart R
         and run {.code natmcp::natmcp_session()} before anything else uses
         mcptools, or put
         {.code Sys.setenv(MCPTOOLS_SOCKET_DIR = \"{canonical}\")} at the top
         of your {.file ~/.Rprofile}."))
  invisible(TRUE)
}
