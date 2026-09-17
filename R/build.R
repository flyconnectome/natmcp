#' Build the natmcp index
#'
#' Runs the ingestion pipeline: resolve sources from the scrape config,
#' introspect installed packages (namespaces, formals, Rd, executed examples),
#' harvest machine-readable artefacts (pkgdown reference groups, vignettes,
#' examples), fold in the curated corpus (guide, dataset table, snippets), and
#' emit the index plus a reproducibility manifest.
#'
#' @details
#' Sourcing is org-driven and source-first. The builder enumerates each org in
#' the config (all repos are candidates), classifies each repo by the presence
#' of a `DESCRIPTION` (package -> indexed; otherwise -> corpus-only), applies
#' `overrides`, and records the git SHA + package version of everything it
#' touches in `manifest.json`. Return shapes are captured by executing package
#' `@examples` in a sandboxed [callr] process, which doubles as a freshness
#' check.
#'
#' This is the CI-side half of the deployment split (Option C): `build_index()`
#' runs in GitHub Actions (which has natverse installed) and publishes a
#' versioned index artifact; servers never build, they [fetch_index()]. The
#' `scope` distinguishes the CI-runnable offline core from the online
#' enrichment that needs live dataset tokens.
#'
#' Not yet implemented -- Phase 1 scaffolds structure and configuration only.
#' Implemented in Phase 2 (Tier-1 introspection) onward per `PLAN.md`.
#'
#' @param config Path to the scrape config
#'   (default the packaged `inst/config/packages.yml`).
#' @param out_dir Directory to write the index + manifest into
#'   (default `inst/index`).
#' @param scope `"offline"` (CI-runnable core) or `"online"` (enrichment
#'   overlay needing CAVE/neuprint auth).
#' @return Invisibly, the path to the written index.
#' @export
build_index <- function(config = system.file("config", "packages.yml",
                                              package = "natmcp"),
                        out_dir = NULL,
                        scope = c("offline", "online")) {
  scope <- match.arg(scope)
  stop("build_index() is not implemented yet (Phase 2). See PLAN.md.")
}

#' Fetch a published natmcp index
#'
#' The server-side half of the deployment split: pulls the latest index
#' artifact published by CI (see [build_index()]) and verifies schema +
#' natverse-SHA compatibility from its manifest. Serving needs no natverse
#' toolchain, so this runs the same for a local stdio server or a hosted HTTP
#' endpoint. Not yet implemented -- Phase 7.
#'
#' @param source Where to fetch from (release asset / Pages URL); default TBD.
#' @param cache_dir Local cache directory for the downloaded index.
#' @return Invisibly, the path to the local index.
#' @export
fetch_index <- function(source = NULL, cache_dir = NULL) {
  stop("fetch_index() is not implemented yet (Phase 7). See PLAN.md.")
}

#' Read the scrape configuration
#'
#' @param config Path to the scrape config YAML.
#' @return The parsed config as a list.
#' @export
read_config <- function(config = system.file("config", "packages.yml",
                                              package = "natmcp")) {
  yaml::read_yaml(config)
}
