# natmcp — plan

An MCP server that gives coding agents authoritative, current, token-efficient
access to **natverse ground truth**, so they generate / extend / optimise /
repurpose natverse code efficiently. It is a *knowledge* server, not a code
generator or executor — the agent already writes and edits code; natmcp stops
it working from stale, fuzzy memory of the ecosystem.

Complements coda (coda.science): coda is entry-level, capped exploration with
its own notebook code-gen; natmcp serves the coder audience building robust,
extensible, publication-grade natverse code.

## Foundation — build on the Posit stack, don't reinvent it

- **mcptools** — MCP transport (`mcp_server(tools=)`, stdio; `mcp_session()`
  runs tools in a live interactive R session, which inherits the user's
  CAVE/neuprint auth — no credential handling in natmcp).
- **ellmer** — tools are `ellmer::tool()` objects with `type_*()` typed args.
  Dual use for free: the same tools work when R is the *client* (ellmer chat),
  not just over MCP.
- **btw** — already surfaces generic installed-package help/vignettes/news to an
  LLM (`btw_tool_docs_*`, `btw_tool_docs_package_news`). natmcp **delegates
  generic docs to btw** and layers the natverse-specific value on top.

**Compose, don't compete.** Export `natmcp_tools()` returning a list of
`ellmer::tool()`s (selectable groups, mirroring `btw_tools(tools=...)`), plus a
`natmcp_mcp_server()` convenience. A natverse user already running btw passes
`c(btw_tools(), natmcp_tools())` to one `mcp_server()`.

**Dev-version accuracy is a differentiator.** btw's `cran_*` tools describe the
CRAN package, but natverse is installed from GitHub dev and routinely *ahead of
CRAN*. natmcp indexes the installed *dev* namespace, so its signatures/API are
correct where btw's CRAN lookups would be stale.

## Tools (six, lean-first, progressive disclosure)

The natverse value is the tacit/curated/retrieval layer that btw structurally
cannot provide (altitude, cross-dataset facts, task->function retrieval over a
curated corpus, executed return-shapes, tested snippets, a natverse lint).

| Tool | Job | Backed by |
|---|---|---|
| `guide` | orientation: package roles, altitude map, dataset roster | curated guide + package records (btw has none) |
| `find` | task -> candidate functions + canonical snippet | hybrid lexical + embedding over Rd meta + snippets (btw is package-level cran_search only) |
| `signature` | ground-truth formals/defaults/**return-shape**/lifecycle | **btw help page + natmcp overlay** (executed return-shape + lifecycle + curated note) |
| `snippet` | canonical usage | curated, tagged, tested corpus (btw dumps raw vignettes) |
| `dataset` | id conventions, coord space, auth, quirks | curated `nv_datasets` table (btw has none) |
| `lint` | are these real, current natverse calls? | signature index applied to code (btw has none) |

## Sourcing — org-driven, source-first

Config (`inst/config/packages.yml`) declares orgs + rules, not a static list.

- Enumerate `natverse` + `flyconnectome` repos live (all candidates).
- Classify each by presence of `DESCRIPTION`: package -> indexed
  (full, or allowlist for Tier B adjacent deps); no DESCRIPTION -> corpus-only
  (harvest `.R`/`.Rmd` as snippets).
- `overrides` handle exceptions; `adjacent` covers external CRAN foundations
  (rgl, Rvcg, Morpho, igraph) via a curated interop allowlist.
- Record git SHA + package version of everything in `manifest.json`
  (reproducible, auditable scrape). Rerun on package updates = currentness.

Hybrid extraction: **installed** package for namespace / `formals()` / Rd /
`\value`; **source** for `_pkgdown.yml` (reference groups), vignettes, README,
and SHAs. Return shapes captured by executing `@examples` in a `callr` sandbox
(doubles as a freshness check).

## Record contract

`source` (provenance), `signature`, `snippet`, `dataset`, `package`,
`find_doc`. Every record carries `source_ref` into the provenance table.
(Full field lists in the design discussion; see `data-raw/nv_datasets.R` for
the dataset schema.)

## Package scope

- **Tier A — core natverse** (`tier_A_core`): full coverage + guide altitude.
- **Tier B — adjacent foundations** (rgl/Rvcg/Morpho/igraph): allowlisted
  interop surface + one interop note each.
- **Tier C — base/tidyverse**: excluded (agent already knows them).

## Deployment — Option C (index in CI, serve anywhere)

Two artifacts, decoupled lifecycles:

- **Package** (code) — installed the ordinary way (GitHub/CRAN), slow cadence.
- **Index** (data) — built in **GitHub Actions**, published as a versioned
  artifact (release asset / Pages) with its manifest. Scheduled + triggered on
  natverse releases. `build_index()` runs in CI; the server never builds.

The **server reads a fetched index** — `fetch_index()` pulls the latest
published artifact (checking schema + natverse-SHA compatibility from the
manifest). Serving needs no natverse toolchain, so it runs identically as a
per-user local stdio process *or* a hosted HTTP endpoint (e.g. alongside
coda-mcp on flyem). v1 default: local stdio; HTTP transport + fetch-on-timer
host is a later add. Both consume the same CI-published index.

**Build split (auth constraint):** example execution for return-shapes can hit
live services needing CAVE/neuprint tokens, which CI lacks.

- **offline core** — namespaces/formals/Rd/pkgdown/vignettes/static snippets +
  shapes for offline-runnable examples → runs fully in CI. Ships in v1.
- **online enrichment** — shapes/snippets needing live tokens → runs where
  tokens exist (dev machine, or host with GitHub secrets), as an optional
  overlay. Later.

## Phases

1. **Scaffold + config** — package skeleton, populated `packages.yml`. ✅ done
2. **Builder: Tier-1** — namespace/formals/Rd -> `signature`; enables
   `signature` + `lint`. ✅ done
3. **Builder: Tier-2** — harvest examples/vignettes/pkgdown -> `snippet` +
   `find_doc`; static-analysis tagging; enables `find` + `snippet`. ✅ done
   (tagging via `getParseData`; pkgdown groups still TODO).
4. **Tier-3 curated** — `guide.md` altitude map + `nv_datasets`; enables
   `guide` + `dataset`. ✅ done
5. **Server** — `natmcp_tools()` (ellmer tools, selectable groups) +
   `natmcp_mcp_server()` over mcptools/stdio; verify `c(btw_tools(),
   natmcp_tools())` composes; MCP Inspector smoke test. ✅ done (verified
   end-to-end over stdio: initialize / tools/list / tools/call; `c(btw_tools(),
   natmcp_tools())` = 42 tools, no name collision).
6. **Return-shape execution + freshness** — sandboxed example run captures
   shapes, flags stale examples (offline core). ✅ done (`R/shapes.R`;
   `build_index(shapes = TRUE)`, off by default, CI turns it on; callr sandbox,
   null device, per-example timeout; freshness in manifest, shape surfaced in
   `signature`).
7. **CI + fetch** — ✅ done. Publish target decided: **GitHub Pages** (best CI
   plumbing — `actions/deploy-pages`, no external secret). `.github/workflows/
   build-index.yaml` installs the natverse (best-effort), builds the
   offline-core index with shapes, deploys `_site` to Pages;
   `fetch_index(source, cache_dir, force)` pulls + schema-checks + caches it
   (also accepts a local/mounted path). `.index_path(NULL)` falls back to the
   cache so a fetched index is used automatically. R-CMD-check workflow added.
   Still TODO: online-enrichment overlay where CAVE/neuprint tokens exist
   (candidate host: flyem.mrc-lmb.cam.ac.uk, which also fits a future hosted
   HTTP MCP endpoint); natverse-release trigger for the build.

## Decisions

- MCP shell: **mcptools + ellmer** (R-native), delegating generic docs to btw.
  (Plumber + proxy dropped.)
- Verification depth for `lint`: static-only for v1.
- Language scope: R/natverse first; Python/navis later.
- **Index store: `index.rds` + human-readable `manifest.json`** (schema 3).
  Not SQLite/duckdb — the index is small, loaded whole per process, and a plain
  rds keeps the build/serve path dependency-free. Revisit if it grows.
- **Result serialization: tools return fully-named R lists.** mcptools then
  emits them as `structuredContent` (a JSON object) *and* a JSON text block on
  MCP protocol ≥ 2025-06-18 (what Claude Code/Desktop negotiate), so the agent
  reads labelled JSON. The plain newline-joined "free text" is only mcptools'
  legacy fallback for older protocols / atomic returns; a test locks in that
  every handler returns a named list so we never regress into it.
- **Incubation home: `flyconnectome` GitHub org, public.** Moves to `natverse`
  once stable (Greg's usual incubate-then-promote flow).

## Open decisions (deferred)

- Sourcing knobs: `source: auto|github|local`, `introspect: installed|scratch`
  — `auto` (GitHub defines set/ref, local bytes when clean, introspect
  installed) for v1; scratch-library installs for CI reproducibility later.
- `find` retrieval: lexical v1 shipped; embedding store still an option if
  lexical recall proves insufficient.
- Private flyconnectome repos: opt-in, off by default.
