#' natmcp tools as a list of ellmer tools
#'
#' Returns the natmcp tools as [ellmer::tool()] objects. Because they are plain
#' ellmer tools they work both over MCP (via [natmcp_mcp_server()]) and when R
#' is the client (`ellmer::Chat$set_tools()`). The API mirrors
#' `btw::btw_tools()` so the two compose: pass `c(btw::btw_tools(),
#' natmcp_tools())` to a single [mcptools::mcp_server()].
#'
#' @param tools Optional character vector selecting tools by group name
#'   (`"guide"`, `"find"`, `"signature"`, `"snippet"`, `"dataset"`, `"lint"`);
#'   `NULL` returns all.
#' @param index Path to a built index (see [build_index()]); `NULL` uses the
#'   packaged/locally built index.
#' @return A list of `ellmer::tool()` objects.
#' @export
natmcp_tools <- function(tools = NULL, index = NULL) {
  defs <- list(
    guide = ellmer::tool(
      function(lean = TRUE) tool_guide(lean = lean, index = index),
      name = "natmcp_guide",
      description = paste(
        "Orientation guide to the natverse: the altitude map (which layer to",
        "reach for), a one-line role per package, and the dataset roster.",
        "Read this before searching."),
      arguments = list(lean = ellmer::type_boolean(
        "If true (default) omit the full dataset records.", required = FALSE))
    ),
    find = ellmer::tool(
      function(task, package = NULL) {
        tool_find(task, package = package, index = index)
      },
      name = "natmcp_find",
      description = paste(
        "Map a natural-language task to candidate natverse functions (with",
        "usage and a one-line intent) plus a canonical usage snippet."),
      arguments = list(
        task = ellmer::type_string("What you are trying to do."),
        package = ellmer::type_string(
          "Optional package name to restrict candidates.", required = FALSE))
    ),
    signature = ellmer::tool(
      function(symbol) tool_signature(symbol, index = index),
      name = "natmcp_signature",
      description = paste(
        "Ground-truth signature for a natverse function: formals, defaults,",
        "per-argument glosses, return value and lifecycle. Accepts pkg::fn or",
        "a bare name. Full help is delegated to btw."),
      arguments = list(symbol = ellmer::type_string(
        "A pkg::fn identifier or bare function name."))
    ),
    snippet = ellmer::tool(
      function(task = NULL, id = NULL) {
        tool_snippet(task = task, id = id, index = index)
      },
      name = "natmcp_snippet",
      description = paste(
        "Canonical usage snippet: fetch one by id, or the best-matching",
        "snippet for a task."),
      arguments = list(
        task = ellmer::type_string(
          "What you are trying to do.", required = FALSE),
        id = ellmer::type_string(
          "A snippet id, e.g. pkg::fn#example.", required = FALSE))
    ),
    dataset = ellmer::tool(
      function(name) tool_dataset(name, index = index),
      name = "natmcp_dataset",
      description = paste(
        "Curated facts for a connectome dataset: id conventions, coordinate",
        "space, authentication and quirks (e.g. FlyWire root-id drift)."),
      arguments = list(name = ellmer::type_string(
        "Dataset id or alias, e.g. flywire."))
    ),
    lint = ellmer::tool(
      function(code) tool_lint(code, index = index),
      name = "natmcp_lint",
      description = paste(
        "Statically check R code against the natverse index: unknown",
        "functions, unknown named arguments and deprecated calls."),
      arguments = list(code = ellmer::type_string("R code to check."))
    )
  )

  if (is.null(tools)) return(unname(defs))
  unknown <- setdiff(tools, names(defs))
  if (length(unknown)) {
    cli::cli_warn("Unknown tool group{cli::qty(length(unknown))}{?s}: \\
                  {.val {unknown}}. Available: {.val {names(defs)}}.")
  }
  unname(defs[intersect(tools, names(defs))])
}

#' Serve the natmcp tools over MCP
#'
#' Convenience wrapper around [mcptools::mcp_server()] that serves
#' [natmcp_tools()]. Configure your client to run
#' `Rscript -e "natmcp::natmcp_mcp_server()"`. The generic package-documentation
#' tools are delegated to `btw`; combine them by serving
#' `c(btw::btw_tools(), natmcp_tools())` yourself if you want both.
#'
#' @details
#' Transport is stdio for local clients (Claude Desktop/Code). With
#' `index = NULL` a packaged or locally built index is used, else the
#' [fetch_index()] cache. If none exists, the first tool call runs
#' [fetch_index()] automatically, and at start-up a cached index that was last
#' checked more than a week ago is refreshed if a newer one has been published
#' (`options(natmcp.refresh_days = )` sets the interval). Set
#' `options(natmcp.auto_fetch = FALSE)` to disable both.
#'
#' On macOS the socket directory used to find R sessions is pinned as
#' described in [natmcp_session()]. The server also offers a `natmcp_sitrep`
#' tool so Claude can diagnose connection problems (see [natmcp_sitrep()]).
#'
#' @param index Path to a built index (see [build_index()]); `NULL` uses the
#'   packaged/locally built index.
#' @param tools Tool groups to serve (see [natmcp_tools()]); `NULL` for all.
#' @param run_r If `TRUE` (default), also serve `natmcp_run_r`, which runs R
#'   code in a connected R session that has opted in with
#'   [natmcp_session()]`(run_r = TRUE)` and refuses everywhere else. Omitted
#'   when the `evaluate` package is not installed.
#' @param ... Passed to [mcptools::mcp_server()] (e.g. `type`, `port`).
#' @export
natmcp_mcp_server <- function(index = NULL, tools = NULL, run_r = TRUE, ...) {
  .pin_socket_dir()
  .maybe_refresh_index(index)
  tl <- natmcp_tools(tools = tools, index = index)
  if (isTRUE(run_r)) tl <- c(tl, list(.run_r_tool()))
  tl <- c(tl, list(.sitrep_tool()))
  mcptools::mcp_server(tools = Filter(Negate(is.null), tl), ...)
}
