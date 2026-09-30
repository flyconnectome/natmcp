#' Make this R session available to Claude
#'
#' Registers the current R session so that Claude can connect to it, and
#' optionally lets Claude run R code in it. Then ask Claude to "connect to my R
#' session".
#'
#' @details
#' This wraps [mcptools::mcp_session()]: the session listens in the background,
#' leaving the console free. Claude lists registered sessions with the
#' `list_r_sessions` tool and connects with `select_r_session`; tool calls then
#' run in this session.
#'
#' The server always offers a `natmcp_run_r` tool (see [natmcp_mcp_server()]),
#' but it only runs code in a session where `run_r = TRUE` was set here; any
#' other session, or the server's own background process, refuses. Code runs
#' in the global environment via [btw::btw_tool_run_r()], so objects Claude
#' creates appear in your workspace. Your Claude app asks you to approve each
#' tool call unless you have told it to always allow the tool. Call again with
#' `run_r = FALSE` to revoke.
#'
#' On macOS, sessions and the server meet in a socket directory that mcptools
#' derives from `TMPDIR`, which can differ between apps. natmcp pins it (via
#' the `MCPTOOLS_SOCKET_DIR` environment variable, unless you have set it) to
#' your per-user temp directory in both, and warns if that was not possible.
#'
#' To register every interactive session automatically, add
#' `natmcp::natmcp_session(quiet = TRUE)` to your `~/.Rprofile` (or let
#' [natmcp_setup()] do it).
#'
#' @param run_r If `TRUE`, allow Claude to run R code in this session. Needs
#'   the `evaluate` package.
#' @param quiet If `TRUE`, suppress the instructions printed on success.
#' @return Invisibly, `TRUE`.
#' @export
#' @examples
#' \dontrun{
#' # Claude can use this session for look-ups
#' natmcp_session()
#' # ... and can also run R code here
#' natmcp_session(run_r = TRUE)
#' }
natmcp_session <- function(run_r = FALSE, quiet = FALSE) {
  if (isTRUE(run_r) && !.is_installed("evaluate")) {
    cli::cli_abort(c(
      "Letting Claude run R code needs the {.pkg evaluate} package.",
      i = "Install it with {.code install.packages(\"evaluate\")}."))
  }
  options(natmcp.run_r = isTRUE(run_r))
  if (!isTRUE(.natmcp_state$session)) {
    pin <- .pin_socket_dir()
    .start_mcp_session()
    .natmcp_state$session <- TRUE
    if (identical(pin, "late")) .warn_socket_mismatch()
  }
  if (!isTRUE(quiet)) {
    cli::cli_alert_success("This R session is now available to Claude.")
    cli::cli_alert_info("In Claude, ask: {.emph \"connect to my R session\"}.")
    if (isTRUE(run_r)) {
      cli::cli_alert_warning(
        "Claude can run R code in this session. Revoke with \\
         {.code natmcp_session(run_r = FALSE)}.")
    } else {
      cli::cli_alert_info(
        "To let Claude run code here: {.code natmcp_session(run_r = TRUE)}.")
    }
  }
  invisible(TRUE)
}

.natmcp_state <- new.env(parent = emptyenv())

#' Seam over mcptools::mcp_session() so tests can mock it
#' @noRd
.start_mcp_session <- function() mcptools::mcp_session()

#' The gated run-R tool served by natmcp_mcp_server()
#'
#' Reuses btw's run_r description, but the function checks the
#' `natmcp.run_r` option in whichever process executes it, so code only runs
#' in a session that opted in via natmcp_session(run_r = TRUE). Returns `NULL`
#' when btw's tool is unavailable (e.g. `evaluate` not installed).
#' @noRd
.run_r_tool <- function() {
  btw_def <- local({
    op <- options(btw.run_r.enabled = TRUE)
    on.exit(options(op))
    btw::btw_tools("run")
  })
  if (!length(btw_def)) return(NULL)
  ellmer::tool(
    .run_r_impl,
    name = "natmcp_run_r",
    description = paste(
      "Run R code in the user's connected R session. Only works after the user",
      "has run `natmcp::natmcp_session(run_r = TRUE)` there and you have",
      "connected with select_r_session.\n\n", btw_def[[1]]@description),
    arguments = list(code = ellmer::type_string("R code to run.")),
    annotations = btw_def[[1]]@annotations
  )
}

#' @noRd
.run_r_impl <- function(code) {
  if (!isTRUE(getOption("natmcp.run_r"))) {
    stop("This R session has not allowed Claude to run code. Ask the user to ",
         "run `natmcp::natmcp_session(run_r = TRUE)` in the R session they ",
         "want you to use, then connect to it with select_r_session.",
         call. = FALSE)
  }
  btw::btw_tool_run_r(code)
}
