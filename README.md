# natmcp

An [MCP](https://modelcontextprotocol.io) server that gives coding agents
authoritative, current, token-efficient access to **natverse ground truth** —
so they generate, extend, optimise and repurpose natverse analysis code
without working from stale or fuzzy memory of the ecosystem.

natmcp is a *knowledge* server, not a code generator or executor: the agent
already writes and edits code well; natmcp supplies the natverse specifics it
gets wrong (signatures, return shapes, idioms, dataset conventions, current vs
deprecated APIs). It complements [coda](https://coda.science/) — coda is
entry-level exploration with its own notebook code-gen; natmcp serves coders
building robust, extensible, publication-grade code.

## Tools

`guide` (orientation) · `find` (task → functions) · `signature` (formals +
return shape) · `snippet` (canonical usage) · `dataset` (id/coord/auth/quirks) ·
`lint` (are these real, current natverse calls?).

## How it works

A build step introspects installed natverse packages and harvests their
machine-readable artefacts (pkgdown reference groups, vignettes, examples),
adds a small curated corpus (guide, dataset facts, snippets), and emits an
index the server serves. Sourcing is org-driven (`natverse` +
`flyconnectome`), reproducible via a build manifest.

**Status:** early scaffolding. See [`PLAN.md`](PLAN.md).
