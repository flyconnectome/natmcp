#' Diagnose natmcp setup and connection problems
#'
#' Reports what natmcp can see from this R process: the Claude configuration
#' entries, the index, and where R sessions and the natmcp server meet. Run it
#' in the R session Claude can't reach and paste the output into Claude.
#'
#' @details
#' Claude can run the same report from the natmcp server with the
#' `natmcp_sitrep` tool, so it can compare the server's view with yours. The
#' usual cause of an empty `list_r_sessions` is the two processes using
#' different socket directories (see [natmcp_session()]).
#'
#' Only natmcp's own entry is read from each Claude configuration file.
#'
#' @param sessions If `TRUE`, also list the R sessions visible from here. This
#'   loads mcptools.
#' @return A `natmcp_sitrep` object: a named list of the report's fields,
#'   printed as plain text ready to paste.
#' @export
#' @examples
#' \dontrun{
#' natmcp_sitrep()
#' }
natmcp_sitrep <- function(sessions = TRUE) {
  .sitrep(sessions = sessions)
}

#' @noRd
.sitrep <- function(sessions = TRUE) {
  .pin_socket_dir()
  rscript <- .rscript_path()
  cfg <- list(desktop = .claude_desktop_config_path(),
              code = .claude_code_config_path())
  ip <- .index_path()
  mf <- if (nzchar(ip)) file.path(dirname(ip), "manifest.json")
  manifest <- if (!is.null(mf) && file.exists(mf)) {
    tryCatch(jsonlite::read_json(mf), error = function(e) NULL)
  }
  canonical <- .canonical_socket_dir()
  if (isTRUE(sessions)) loadNamespace("mcptools")
  in_use <- .socket_dir_in_use()
  x <- list(
    natmcp = as.character(utils::packageVersion("natmcp")),
    r = R.version$version.string,
    os = paste(Sys.info()[c("sysname", "release")], collapse = " "),
    pid = Sys.getpid(),
    interactive = interactive(),
    rscript = rscript,
    config = lapply(cfg, .sitrep_config, rscript = rscript),
    index = if (nzchar(ip)) ip else "none (fetched on first use)",
    index_built = manifest$built_at,
    tmpdir = Sys.getenv("TMPDIR", unset = "<unset>"),
    socket_dir_env = Sys.getenv("MCPTOOLS_SOCKET_DIR", unset = "<unset>"),
    socket_dir_expected = canonical,
    socket_dir_in_use = in_use,
    socket_dir_ok = is.null(canonical) || is.null(in_use) ||
      .same_dir(in_use, canonical),
    session_registered = isTRUE(.natmcp_state$session),
    run_r = isTRUE(getOption("natmcp.run_r")),
    evaluate = .is_installed("evaluate"),
    sessions_visible = if (isTRUE(sessions)) .visible_sessions())
  structure(x, class = "natmcp_sitrep")
}

#' Summarise natmcp's entry in one Claude config file
#' @noRd
.sitrep_config <- function(path, rscript) {
  if (is.null(path)) return("not available on this OS")
  if (!file.exists(path)) return(sprintf("%s: file not found", path))
  cfg <- tryCatch(jsonlite::read_json(path, simplifyVector = FALSE),
                  error = function(e) e)
  if (inherits(cfg, "error")) {
    return(sprintf("%s: unreadable JSON (%s)", path, conditionMessage(cfg)))
  }
  e <- cfg$mcpServers$natmcp
  if (is.null(e)) return(sprintf("%s: no natmcp entry", path))
  cmd <- e$command %||% ""
  notes <- c(
    if (!file.exists(cmd)) "command not found",
    if (file.exists(cmd) && !.same_dir(normalizePath(cmd), normalizePath(rscript)))
      "a different R from this one",
    if (!is.null(e$env$MCPTOOLS_SOCKET_DIR))
      paste("MCPTOOLS_SOCKET_DIR =", e$env$MCPTOOLS_SOCKET_DIR))
  sprintf("%s: %s %s%s", path, cmd, paste(unlist(e$args), collapse = " "),
          if (length(notes)) paste0(" [", paste(notes, collapse = "; "), "]")
          else "")
}

#' @noRd
.visible_sessions <- function() {
  tryCatch(utils::getFromNamespace("list_r_sessions", "mcptools")(),
           error = function(e) paste("error:", conditionMessage(e)))
}

#' @export
format.natmcp_sitrep <- function(x, ...) {
  yn <- function(b) if (isTRUE(b)) "yes" else "no"
  or_na <- function(v) if (is.null(v)) "n/a" else v
  sess <- x$sessions_visible
  c("natmcp sitrep",
    sprintf("- natmcp %s, %s, %s (pid %s, %s)", x$natmcp, x$r, x$os, x$pid,
            if (x$interactive) "interactive" else "non-interactive"),
    sprintf("- Rscript: %s", x$rscript),
    sprintf("- Claude desktop config: %s", x$config$desktop),
    sprintf("- Claude Code config: %s", x$config$code),
    sprintf("- index: %s%s", x$index,
            if (!is.null(x$index_built)) sprintf(" (built %s)", x$index_built)
            else ""),
    sprintf("- TMPDIR: %s", x$tmpdir),
    sprintf("- MCPTOOLS_SOCKET_DIR: %s", x$socket_dir_env),
    sprintf("- socket dir expected: %s; in use: %s%s",
            or_na(x$socket_dir_expected), or_na(x$socket_dir_in_use),
            if (x$socket_dir_ok) "" else "  <-- MISMATCH"),
    sprintf("- this session registered with natmcp_session(): %s; run_r: %s; evaluate installed: %s",
            yn(x$session_registered), yn(x$run_r), yn(x$evaluate)),
    if (!is.null(sess)) sprintf("- R sessions visible from here: %s",
            if (length(sess)) paste(sess, collapse = "; ") else "none"))
}

#' @export
print.natmcp_sitrep <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' The natmcp_sitrep tool served by natmcp_mcp_server()
#' @noRd
.sitrep_tool <- function() {
  ellmer::tool(
    function() paste(format(.sitrep()), collapse = "\n"),
    name = "natmcp_sitrep",
    description = paste(
      "Diagnose natmcp setup and R-session connection problems. Reports, for",
      "the process it runs in (the natmcp server, or the connected R session),",
      "the natmcp version, Claude config entries, index, the socket directory",
      "used to find R sessions and the sessions visible from there. Use it when",
      "list_r_sessions is empty or a session can't be reached, and compare with",
      "the output of `natmcp::natmcp_sitrep()` run by the user in their R",
      "session: a different 'socket dir in use' means the two can't see each",
      "other."),
    arguments = list(),
    annotations = ellmer::tool_annotations(read_only_hint = TRUE)
  )
}
