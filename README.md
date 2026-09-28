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

## Use it

**1. Install the package** (R ≥ 3.5):

```r
# install.packages("remotes")
remotes::install_github("flyconnectome/natmcp")
```

**2. Tell Claude about the server.** You don't start natmcp yourself: Claude
launches it in the background (as `Rscript -e "natmcp::natmcp_mcp_server()"`)
whenever it needs it. You just have to register that command once.

First find the full path to your `Rscript` — apps started from the Dock/Start
menu don't see your shell `PATH`, so a bare `Rscript` often fails. In R:

```r
file.path(R.home("bin"), "Rscript")
#> e.g. "/Library/Frameworks/R.framework/Resources/bin/Rscript"
```

Use that path wherever `/path/to/Rscript` appears below.

### Claude desktop app (chat)

1. Open **Settings → Developer → Edit Config**. This reveals
   `claude_desktop_config.json` (macOS:
   `~/Library/Application Support/Claude/`, Windows: `%APPDATA%\Claude\`).
2. Add a `natmcp` entry under `mcpServers`. If the file already has other
   servers, add `natmcp` alongside them rather than replacing the file:

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

3. **Quit Claude completely** (Cmd-Q / File → Exit, not just closing the
   window) and reopen it.
4. Check it worked: *Settings → Developer* should list `natmcp` as
   **running**, and in a new chat the tools menu below the message box should
   show natmcp's tools. Try asking
   *"Using natmcp, what's the signature of nat::nlapply?"*

If it shows an error, click it for the log — the usual culprits are a wrong
`Rscript` path or natmcp not being installed in the R library that `Rscript`
uses.

### Claude Code (terminal, IDE, or the desktop app's Code tab)

One command; `-s user` makes it available in every project:

```bash
claude mcp add -s user natmcp -- /path/to/Rscript -e "natmcp::natmcp_mcp_server()"
```

Check with `claude mcp list` (should say `natmcp … ✔ Connected`), or `/mcp`
inside a session.

### Other MCP clients

Use the same `command` and `args` in whatever config the client uses for a
local ("stdio") server.

That's it. The first time Claude uses a natmcp tool, the server downloads the
published natverse index into your user cache (a few seconds, once). To pick
up a newer published index later, run `natmcp::fetch_index()` in R.

## Connect Claude to your running R session (optional)

By default the server runs in its own throwaway R process. You can instead
point it at the R session you are working in (RStudio, Positron, a terminal)
so that tool calls are answered *there* — this is what makes it possible for
Claude to see your objects and, if you allow it, run code for you.

**1. Register your session.** In the R session you want Claude to use:

```r
mcptools::mcp_session()
```

This returns immediately and leaves the console free; the session just
listens in the background. To do this automatically in every interactive
session, add it to your `~/.Rprofile` (`usethis::edit_r_profile()`):

```r
if (interactive() && requireNamespace("mcptools", quietly = TRUE))
  mcptools::mcp_session()
```

**2. Ask Claude to connect.** In a chat, say something like
*"list my R sessions and connect to the RStudio one"*. Claude uses the
`list_r_sessions` and `select_r_session` tools (provided automatically by
natmcp's server) to pick it. From then on its tool calls run in that session
until you restart Claude or it selects another.

### Letting Claude run code in your session

On its own, natmcp only *looks things up* — it never executes code. For true
two-way work (Claude runs R in your session, sees the printed output, plots,
warnings and errors, and you see the resulting objects in your environment),
also serve [btw](https://posit-dev.github.io/btw/)'s opt-in `run_r` tool.
Replace the `args` in your config with:

```json
"args": ["-e", "options(btw.run_r.enabled = TRUE); mcptools::mcp_server(tools = c(btw::btw_tools(c('docs', 'env', 'run')), natmcp::natmcp_tools()))"]
```

(for Claude Code, remove and re-add the server with the same expression after
`-e`). This needs the `evaluate` package installed. Restart Claude, register
your session as above, and ask Claude to connect to it; you can then say
e.g. *"read the FAFB DA1 PNs into `da1` and plot them"*.

> **Security.** `run_r` executes arbitrary R code in your global environment
> with your permissions — it can read/write files, delete objects, and use any
> credentials your session has. Claude asks before each tool call unless you
> have told it to always allow that tool; keep that approval on for `run_r`
> unless you are comfortable with what it may run. Leave it out of the config
> when you only want natmcp's look-up tools.

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
