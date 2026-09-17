# MCP tool handlers.
#
# Each handler reads the built index and returns lean-by-default results with
# progressive disclosure (drill-down on request). These are the natverse
# knowledge layer; generic package docs are delegated to btw (btw_tool_docs_*).
# Backing sources per the plan:
#   guide     <- package guide (curated) + package records
#   find      <- find_doc (hybrid lexical + embedding over Rd meta + snippets)
#   signature <- btw help page + natmcp overlay (executed return-shape,
#                lifecycle, curated note)
#   snippet   <- snippet records (harvested examples/vignettes + curated)
#   dataset   <- nv_datasets table (curated)
#   lint      <- signature index applied to submitted code
#
# Exposed as ellmer::tool() objects via natmcp_tools(); see R/serve.R.
# Not yet implemented -- Phase 1 scaffolds signatures and contracts only.

#' Tool: orientation guide to the natverse
#' @param lean If `TRUE` (default) omit drill-down detail.
#' @return A guide document (package roles, altitude map, dataset roster).
#' @noRd
tool_guide <- function(lean = TRUE) .nyi("guide")

#' Tool: map a task to candidate functions + a canonical snippet
#' @param task Natural-language description of the task.
#' @noRd
tool_find <- function(task, package = NULL, dataset = NULL) .nyi("find")

#' Tool: ground-truth signature for a function
#' @param symbol A `pkg::fn` identifier.
#' @noRd
tool_signature <- function(symbol) .nyi("signature")

#' Tool: canonical usage snippet(s)
#' @noRd
tool_snippet <- function(task = NULL, id = NULL) .nyi("snippet")

#' Tool: dataset facts (id conventions, coord space, auth, quirks)
#' @noRd
tool_dataset <- function(name) .nyi("dataset")

#' Tool: check code against real natverse symbols / args / deprecations
#' @param code A string of R code.
#' @noRd
tool_lint <- function(code) .nyi("lint")

.nyi <- function(what) stop(sprintf("tool '%s' not implemented yet", what))
