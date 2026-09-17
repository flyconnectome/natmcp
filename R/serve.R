#' natmcp tools as a list of ellmer tools
#'
#' Returns the natmcp tools as [ellmer::tool()] objects. Because they are plain
#' ellmer tools they work both over MCP (via [natmcp_mcp_server()]) and when R
#' is the client (`ellmer::Chat$set_tools()`). The API mirrors
#' `btw::btw_tools()` so the two compose: pass `c(btw::btw_tools(),
#' natmcp_tools())` to a single [mcptools::mcp_server()].
#'
#' @param tools Optional character vector selecting tool groups (e.g.
#'   `"guide"`, `"find"`, `"signature"`, `"snippet"`, `"dataset"`, `"lint"`);
#'   `NULL` returns all.
#' @param index Path to a built index (see [build_index()]).
#' @return A list of `ellmer::tool()` objects.
#' @export
natmcp_tools <- function(tools = NULL, index = NULL) {
  stop("natmcp_tools() is not implemented yet (Phase 5). See PLAN.md.")
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
#' Transport defaults to stdio for local clients (Claude Desktop/Code).
#' Dataset-touching tools can run inside a live session via
#' [mcptools::mcp_session()] so they inherit the user's CAVE/neuprint auth.
#' With `index = NULL` the latest CI-published index is obtained via
#' [fetch_index()] (Option C: build in CI, serve anywhere).
#' Not yet implemented -- Phase 5.
#'
#' @param index Path to a built index (see [build_index()]).
#' @param tools Tool groups to serve (see [natmcp_tools()]); `NULL` for all.
#' @export
natmcp_mcp_server <- function(index = NULL, tools = NULL) {
  stop("natmcp_mcp_server() is not implemented yet (Phase 5). See PLAN.md.")
}
