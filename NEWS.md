# natmcp 0.2.0

First release.

## What's Changed
* natverse knowledge tools served over MCP: `guide`, `find`, `signature`,
  `snippet`, `dataset` and `lint`, backed by an index built from the installed
  natverse (`build_index()`) and published by CI (`fetch_index()`, run
  automatically on first use).
* `natmcp_setup()`: one-step setup that fetches the index and registers natmcp
  with the Claude desktop app and Claude Code, optionally via your `.Rprofile`.
* `natmcp_session()` makes an R session available to Claude; with
  `run_r = TRUE` Claude can also run code in it (the `natmcp_run_r` tool
  refuses in any session that hasn't opted in).
  by @jefferis in https://github.com/flyconnectome/natmcp/pull/1
* Fix macOS session discovery when Claude inherits a different `TMPDIR`
  (natmcp now pins `MCPTOOLS_SOCKET_DIR`), and add `natmcp_sitrep()` plus a
  `natmcp_sitrep` server tool to diagnose connection problems
  by @jefferis in https://github.com/flyconnectome/natmcp/pull/2
* pkgdown site at https://flyconnectome.github.io/natmcp/
