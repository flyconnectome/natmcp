# natmcp

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

An [MCP](https://modelcontextprotocol.io) server that gives coding agents
authoritative, current, token-efficient access to **[natverse](https://natverse.org)
ground truth** — so they generate, extend, optimise and repurpose natverse
analysis code without working from stale or fuzzy memory of the ecosystem.

natmcp is a *knowledge* server, not a code generator or executor: the agent
already writes and edits code well; natmcp supplies the natverse specifics it
gets wrong (signatures, return shapes, idioms, dataset conventions, current vs
deprecated APIs). It complements [coda](https://coda.science/) — coda is
entry-level exploration with its own notebook code-gen; natmcp serves coders
building robust, extensible, publication-grade code.

> **Experimental.** The API and index format may change without notice, and
> natmcp is not yet on CRAN. Install from GitHub.

## Quick start

Three steps, all in R:

```r
# 1. Install (with the natverse installer)
if (!requireNamespace("natmanager")) install.packages("natmanager")
natmanager::install(pkgs = "flyconnectome/natmcp")

# 2. Set up: fetch the natverse index and register natmcp with Claude
natmcp::natmcp_setup()
#    ...then fully quit and reopen Claude

# 3. In the R session you want Claude to work with
natmcp::natmcp_session()               # Claude can use this session
natmcp::natmcp_session(run_r = TRUE)   # ...and can also run R code in it
```

Then ask Claude to *"connect to my R session"*. Step 3 is optional: without
it Claude still gets natverse answers from natmcp, it just can't see or use
your session.

The sections below explain each step in more detail.

## Setup in detail

### What `natmcp_setup()` does

You don't start the natmcp server yourself: Claude launches it in the
background (as `Rscript -e "natmcp::natmcp_mcp_server()"`) whenever it needs
it. `natmcp_setup()` registers that command once, asking before each step:

1. **Index.** Downloads the published natverse index (or builds one from your
   installed packages). If you skip this, the server downloads it the first
   time Claude uses a natmcp tool.
2. **Claude apps.** Adds a `natmcp` entry to the configuration of
   - the **Claude desktop app (chat)**: `claude_desktop_config.json`, and
   - **Claude Code** (terminal, IDEs and the desktop app's **Code tab**):
     `~/.claude.json`.

   These are separate configurations, so both are set up by default. Nothing
   else in either file is touched, and a backup is saved next to each before
   it changes.
3. **R profile (optional).** Adds `natmcp::natmcp_session(quiet = TRUE)` to
   your `~/.Rprofile` so every interactive R session is available to Claude.

After it finishes, **quit Claude completely** (Cmd-Q / File → Exit, not just
closing the window) and reopen it. To check it worked, ask Claude
*"Using natmcp, what's the signature of nat::nlapply?"*

Run `natmcp::natmcp_setup(ask = FALSE)` to accept the defaults without
questions; see `?natmcp_setup` for the options. To pick up a newer published
index later, run `natmcp::fetch_index()`.

### Setting up by hand

If you'd rather edit the configuration yourself, first find the full path to
your `Rscript` (apps started from the Dock/Start menu don't see your shell
`PATH`, so a bare `Rscript` often fails):

```r
file.path(R.home("bin"), "Rscript")
#> e.g. "/Library/Frameworks/R.framework/Resources/bin/Rscript"
```

- **Claude desktop app (chat):** open **Settings → Developer → Edit Config**
  and add a `natmcp` entry under `mcpServers`, alongside any servers already
  there:

  ```json
  {
    "mcpServers": {
      "natmcp": {
        "command": "/path/to/Rscript",
        "args": ["-e", "natmcp::natmcp_mcp_server()"]
      }
    }
  }
  ```

  After restarting, *Settings → Developer* should show `natmcp` as
  **running**; if it shows an error, click it for the log. The usual culprits
  are a wrong `Rscript` path or natmcp not being installed in the library
  that `Rscript` uses.

- **Claude Code:** if you have the `claude` command-line tool,

  ```bash
  claude mcp add -s user natmcp -- /path/to/Rscript -e "natmcp::natmcp_mcp_server()"
  ```

  and check with `claude mcp list`. Otherwise add the same entry under
  `mcpServers` in `~/.claude.json`.

- **Other MCP clients:** use the same `command` and `args` in whatever
  configuration the client uses for a local ("stdio") server.

## Working in your R session

### Connecting Claude to a session

By default the natmcp server runs in its own background R process. Running

```r
natmcp::natmcp_session()
```

makes the R session you're working in (RStudio, Positron, a terminal)
available to Claude as well. It returns immediately and leaves the console
free; the session just listens in the background. Then ask Claude to
*"connect to my R session"*: Claude uses the `list_r_sessions` and
`select_r_session` tools to pick it, and from then on its tool calls run in
that session until you restart Claude or it connects to another. If you have
several sessions registered, tell Claude which one you mean (they are listed
by working directory).

### Letting Claude run code

```r
natmcp::natmcp_session(run_r = TRUE)
```

additionally lets Claude run R code in *this* session: it sees the printed
output, plots, messages, warnings and errors, and the objects it creates
appear in your workspace. You can then ask e.g. *"read the FAFB DA1 PNs into
`da1` and plot them"*. Revoke it with `natmcp_session(run_r = FALSE)`.

The server always offers Claude a `natmcp_run_r` tool, but it only works in a
session where you ran `natmcp_session(run_r = TRUE)`; anywhere else it
refuses. It needs the `evaluate` package and is built on
[btw](https://posit-dev.github.io/btw/)'s `btw_tool_run_r()`.

> **Security.** With `run_r = TRUE`, Claude can execute arbitrary R code in
> your session with your permissions: read and write files, delete objects,
> and use any credentials the session has. Your Claude app asks you to
> approve each tool call unless you've told it to always allow that tool;
> keep approval on for `natmcp_run_r` unless you're comfortable with what it
> may run.

### Trying the tools by hand

The tools are plain `ellmer::tool()` objects, so you can call one directly
from R without any MCP client:

```r
sig <- natmcp::natmcp_tools("signature")[[1]]  # pick one tool by group
sig(symbol = "nat::read.neurons")              # returns the tool's result
```

## Tools

| Tool | Job |
|---|---|
| `guide` | orientation: package roles, altitude map, dataset roster |
| `find` | task → candidate functions + a canonical snippet |
| `signature` | ground-truth formals, defaults, return value, lifecycle |
| `snippet` | canonical usage from tested examples/vignettes |
| `dataset` | id conventions, coordinate space, auth, quirks |
| `lint` | are these real, current natverse calls? |
| `run_r` | run R code in a connected session that allows it |

## How it works

Two decoupled artefacts:

- **The index (data).** [`build_index()`](R/build.R) introspects *installed*
  natverse packages (namespaces, `formals()`, Rd) into signature records,
  harvests their examples and vignettes into tagged snippets, and folds in a
  small curated corpus (a package/altitude [guide](inst/corpus/guide.md), the
  `nv_datasets` facts table). It writes `index.rds` + a reproducible
  `manifest.json` (git SHA + package version of everything it touched).
  Sourcing is org-driven (`natverse` + `flyconnectome`).
- **The server (code).** [`natmcp_mcp_server()`](R/serve.R) serves the tools
  over MCP (stdio) by reading a built index. Serving needs no natverse
  toolchain, so the same server runs as a local per-user process or a hosted
  endpoint. The index is built in CI and published; the server fetches it
  on first use (`fetch_index()`).

### Building your own index (developers)

The published index is built in CI from the current natverse. If you want the
tools to reflect the packages *you* have installed (e.g. development versions),
build a local index and point the server at it:

```r
natmcp::build_index(out_dir = "~/natmcp-index")  # introspects installed natverse
```

then use `natmcp::natmcp_mcp_server(index = '~/natmcp-index')` as the `-e`
expression in your Claude config. (With no `out_dir`, the index goes to
`inst/index` in the working directory, which the server only finds when it is
launched from that directory — e.g. Claude Code in the natmcp checkout.)

## Built on

natmcp stands on the Posit R MCP stack rather than reinventing it:

- **[mcptools](https://posit-dev.github.io/mcptools/)** — MCP transport.
- **[ellmer](https://ellmer.tidyverse.org/)** — tools are `ellmer::tool()`
  objects, so they work both over MCP and when R is the client.
- **[btw](https://posit-dev.github.io/btw/)** — surfaces generic
  package documentation; natmcp delegates generic docs to btw and adds the
  curated natverse layer on top. The two compose in one server:
  `c(btw::btw_tools(), natmcp::natmcp_tools())`.

It introspects the [natverse](https://natverse.org) packages themselves
(e.g. `nat`, `coconatfly`, `neuprintr`, `fafbseg`, `nat.templatebrains`,
`nat.flybrains`), plus a curated interop surface of adjacent foundations
(`rgl`, `Rvcg`, `Morpho`, `igraph`).

## Reference

Bates, Manton, et al. (2020). *The natverse, a versatile toolbox for combining
and analysing neuroanatomical data.* eLife 9:e53350.
<https://doi.org/10.7554/eLife.53350>
