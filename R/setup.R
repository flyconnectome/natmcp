#' Set up natmcp for Claude
#'
#' One-stop setup: gets the natverse index and registers the natmcp server
#' with the Claude desktop app (chat) and Claude Code (terminal, IDEs and the
#' desktop app's Code tab). Run it once, then fully quit and reopen Claude.
#'
#' @details
#' Interactively (`ask = TRUE`) you are asked about each step, with the
#' arguments as the default answers. With `ask = FALSE` the arguments are
#' applied as given.
#'
#' **Index.** `"fetch"` downloads the published index with [fetch_index()];
#' `"build"` runs [build_index()] on your installed natverse packages, writing
#' to the same user cache so the server finds it without extra configuration
#' (a later [fetch_index()] replaces it with the published one). `"skip"` does
#' neither; the server then fetches on first use.
#'
#' **Claude configuration.** The server entry runs
#' `Rscript -e "natmcp::natmcp_mcp_server()"` using the full path to `Rscript`
#' (apps started outside a shell don't see your `PATH`). It is added under
#' `mcpServers` in `claude_desktop_config.json` (`"desktop"`, macOS and
#' Windows only) and `~/.claude.json` (`"code"`, user scope). The rest of each
#' file is kept intact and a timestamped backup is written alongside it before
#' any change. An existing entry that already matches is left alone; one that
#' differs is only replaced after confirmation (or with `overwrite = TRUE`).
#' Claude Code rewrites `~/.claude.json` while running, so quit it before
#' running this if you can, and restart it afterwards.
#'
#' **R profile.** With `rprofile = TRUE`, a line calling
#' [natmcp_session()]`(quiet = TRUE)` is appended to your user `.Rprofile` so
#' every interactive session is available to Claude (look-ups only; Claude
#' can run code only after `natmcp_session(run_r = TRUE)`). A project-level
#' `.Rprofile` takes precedence over the user one.
#'
#' @param clients Which Claude apps to configure: `"desktop"` (desktop app
#'   chat) and/or `"code"` (Claude Code, including the desktop app's Code tab).
#' @param index How to get the index: `"fetch"`, `"build"` or `"skip"`.
#' @param rprofile If `TRUE`, register every interactive R session with
#'   Claude via your `.Rprofile`.
#' @param ask If `TRUE`, ask before each step.
#' @param overwrite If `TRUE`, replace an existing, different `natmcp` entry
#'   without asking.
#' @param rscript Full path to the `Rscript` Claude should launch.
#' @return Invisibly, a named list recording what was done for each step.
#' @export
#' @examples
#' \dontrun{
#' natmcp_setup()
#' # non-interactive: Claude Code only, keep any existing index
#' natmcp_setup(clients = "code", index = "skip", ask = FALSE)
#' }
natmcp_setup <- function(clients = c("desktop", "code"),
                         index = c("fetch", "build", "skip"),
                         rprofile = FALSE, ask = interactive(),
                         overwrite = FALSE, rscript = .rscript_path()) {
  clients <- match.arg(clients, several.ok = TRUE)
  index <- match.arg(index)
  done <- list()

  # 1. index
  if (isTRUE(ask)) {
    choices <- c(fetch = "Download the published index (recommended)",
                 build = "Build from my installed natverse packages",
                 skip = "Skip")
    choices <- choices[c(index, setdiff(names(choices), index))]
    i <- utils::menu(choices, title = "How should natmcp get its index?")
    if (i == 0) cli::cli_abort("Setup cancelled.")
    index <- names(choices)[i]
  }
  cache <- tools::R_user_dir("natmcp", "cache")
  done$index <- switch(index,
    fetch = tryCatch({
      fetch_index()
      "fetched"
    }, error = function(e) {
      cli::cli_alert_warning(
        "Could not fetch the index ({conditionMessage(e)}); the server will \\
         try again on first use.")
      "failed"
    }),
    build = {
      build_index(out_dir = cache)
      "built"
    },
    skip = "skipped")

  # 2. Claude configs
  if (!file.exists(rscript)) {
    cli::cli_abort("Rscript not found at {.path {rscript}}; pass {.arg rscript}.")
  }
  targets <- list(
    desktop = list(label = "the Claude desktop app (chat)",
                   path = .claude_desktop_config_path(),
                   entry = list(command = rscript,
                                args = list("-e", .server_expr))),
    code = list(label = "Claude Code (incl. the desktop app's Code tab)",
                path = .claude_code_config_path(),
                entry = list(type = "stdio", command = rscript,
                             args = list("-e", .server_expr),
                             env = structure(list(), names = character()))))
  for (cl in names(targets)) {
    tg <- targets[[cl]]
    want <- cl %in% clients
    if (is.null(tg$path)) {
      if (want) cli::cli_alert_info("Skipping {tg$label}: not available on this OS.")
      done[[cl]] <- "unavailable"
      next
    }
    if (isTRUE(ask)) want <- .ask_yes_no(
      sprintf("Register natmcp with %s?", tg$label), default = want)
    done[[cl]] <- if (want) {
      .add_mcp_server(tg$path, tg$entry, ask = ask, overwrite = overwrite)
    } else "skipped"
  }

  # 3. R profile
  rp <- .rprofile_path()
  if (isTRUE(ask)) rprofile <- .ask_yes_no(paste(
    "Make every interactive R session available to Claude",
    "(adds a line to your .Rprofile)?"), default = rprofile)
  done$rprofile <- if (isTRUE(rprofile)) .add_rprofile_session(rp) else "skipped"

  if (any(unlist(done[c("desktop", "code")]) %in% c("added", "updated"))) {
    cli::cli_alert_warning(
      "Fully quit and reopen Claude so it picks up the natmcp server.")
  }
  cli::cli_alert_info(
    "Then, in the R session you want Claude to use, run \\
     {.code natmcp::natmcp_session()} (or {.code natmcp_session(run_r = TRUE)} \\
     to let Claude run code there).")
  invisible(done)
}

# The R expression Claude launches.
.server_expr <- "natmcp::natmcp_mcp_server()"

#' @noRd
.rscript_path <- function() {
  file.path(R.home("bin"),
            paste0("Rscript", if (.Platform$OS.type == "windows") ".exe"))
}

#' Claude desktop config path; NULL where the app has no config (Linux) or is
#' not installed.
#' @noRd
.claude_desktop_config_path <- function() {
  dir <- switch(Sys.info()[["sysname"]],
    Darwin = "~/Library/Application Support/Claude",
    Windows = file.path(Sys.getenv("APPDATA"), "Claude"),
    NULL)
  if (is.null(dir) || !dir.exists(dir)) return(NULL)
  file.path(path.expand(dir), "claude_desktop_config.json")
}

#' @noRd
.claude_code_config_path <- function() path.expand("~/.claude.json")

#' @noRd
.rprofile_path <- function() {
  path.expand(Sys.getenv("R_PROFILE_USER", "~/.Rprofile"))
}

#' @noRd
.ask_yes_no <- function(msg, default = TRUE) {
  ans <- utils::askYesNo(msg, default = default)
  if (is.na(ans)) cli::cli_abort("Setup cancelled.")
  ans
}

#' Add or update the natmcp entry under `mcpServers` in a JSON config file
#'
#' Keeps everything else in the file intact (digits = I(17) round-trips floats
#' exactly), writes a timestamped backup before changing an existing file, and
#' writes atomically via a temp file in the same directory.
#' @return `"added"`, `"updated"`, `"unchanged"` or `"kept"` (existing entry
#'   differs but was not replaced).
#' @noRd
.add_mcp_server <- function(path, entry, name = "natmcp", ask = FALSE,
                            overwrite = FALSE) {
  cfg <- if (file.exists(path) && file.size(path) > 0) {
    jsonlite::read_json(path, simplifyVector = FALSE)
  } else structure(list(), names = character())
  servers <- cfg$mcpServers %||% structure(list(), names = character())
  old <- servers[[name]]
  if (!is.null(old)) {
    if (identical(.to_json(old), .to_json(entry))) {
      cli::cli_alert_success("{.path {path}}: natmcp already registered.")
      return("unchanged")
    }
    replace <- isTRUE(overwrite) || (isTRUE(ask) && .ask_yes_no(sprintf(
      "%s already has a different natmcp entry:\n%s\nReplace it?",
      path, .to_json(old)), default = TRUE))
    if (!replace) {
      cli::cli_alert_info(
        "{.path {path}}: kept the existing natmcp entry \\
         (use {.code overwrite = TRUE} to replace it).")
      return("kept")
    }
  }
  servers[[name]] <- entry
  cfg$mcpServers <- servers
  if (file.exists(path)) {
    bak <- paste0(path, ".natmcp-backup-", format(Sys.time(), "%Y%m%d-%H%M%S"))
    file.copy(path, bak)
  }
  fs::dir_create(dirname(path))
  tmp <- tempfile(tmpdir = dirname(path))
  writeLines(.to_json(cfg), tmp)
  file.rename(tmp, path)
  status <- if (is.null(old)) "added" else "updated"
  cli::cli_alert_success("{.path {path}}: natmcp {status}.")
  status
}

#' @noRd
.to_json <- function(x) {
  jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", digits = I(17),
                   pretty = TRUE)
}

.rprofile_marker <- "natmcp::natmcp_session("

#' Append a natmcp_session() call to an R profile (idempotent)
#' @return `"added"` or `"unchanged"`.
#' @noRd
.add_rprofile_session <- function(path) {
  lines <- if (file.exists(path)) readLines(path, warn = FALSE) else character()
  if (any(grepl(.rprofile_marker, lines, fixed = TRUE))) {
    cli::cli_alert_success("{.path {path}} already calls natmcp_session().")
    return("unchanged")
  }
  block <- c(
    "",
    "# Make interactive sessions available to Claude (added by natmcp_setup())",
    "if (interactive() && requireNamespace(\"natmcp\", quietly = TRUE))",
    "  natmcp::natmcp_session(quiet = TRUE)")
  if (!length(lines) || !nzchar(lines[length(lines)])) block <- block[-1]
  writeLines(c(lines, block), path)
  cli::cli_alert_success("Added natmcp_session() to {.path {path}}.")
  "added"
}
