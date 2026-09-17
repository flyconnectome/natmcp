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
  endpoint. The plan (Option C) is to build the index in CI and have the
  server fetch the published artefact.

```r
# build an index from the installed natverse (writes inst/index by default)
natmcp::build_index()

# serve it over MCP (configure your client to run this via Rscript)
natmcp::natmcp_mcp_server()
```

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
