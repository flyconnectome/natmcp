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
#'
#' Returns the curated altitude map plus an auto-seeded package roster (one line
#' per indexed package, from its DESCRIPTION Title) and the dataset roster. This
#' is the orientation an agent should read before searching.
#' @param lean If `TRUE` (default) return the guide, package roster and dataset
#'   names; if `FALSE` also include the full dataset records.
#' @param index Optional index path/dir.
#' @return A guide document (altitude map, package roles, dataset roster).
#' @noRd
tool_guide <- function(lean = TRUE, index = NULL) {
  idx <- .load_index(index)
  ok <- Filter(function(p) identical(p$status, "ok"), idx$manifest$packages)
  packages <- lapply(ok, function(p) {
    list(package = p$name, coverage = p$coverage,
         role = p$role %||% NA_character_)
  })
  datasets <- if (isTRUE(lean)) {
    names(idx$datasets)
  } else {
    unname(idx$datasets)
  }
  list(
    guide = idx$guide,
    packages = packages,
    datasets = datasets,
    note = "Use `find` for task -> function, `signature` for exact API, `dataset` for dataset facts."
  )
}

#' Tool: map a task to candidate functions + a canonical snippet
#'
#' Lexical retrieval (v1) over the index's function + snippet documents. Returns
#' the top candidate functions (id, usage, one-line intent) and a canonical
#' snippet — a matching harvested snippet, else the top function's Rd example.
#' @param task Natural-language description of the task.
#' @param package Optional package name to restrict candidates.
#' @param dataset Optional dataset name (reserved for Phase 4; unused for now).
#' @param index Optional index path/dir.
#' @param n Maximum number of candidate functions to return.
#' @noRd
tool_find <- function(task, package = NULL, dataset = NULL, index = NULL,
                      n = 5L) {
  idx <- .load_index(index)
  scored <- .score_find(idx$find_doc, task, package = package)
  funcs <- Filter(function(x) x$kind == "function", scored)
  candidates <- lapply(utils::head(funcs, n), function(x) {
    rec <- idx$signatures[[x$ref]]
    list(id = rec$id, usage = rec$usage,
         intent = .first_sentence(rec$description), score = x$score)
  })
  snips <- Filter(function(x) x$kind == "snippet", scored)
  snip <- if (length(snips)) {
    idx$snippets[[snips[[1]]$ref]]
  } else if (length(funcs)) {
    idx$snippets[[paste0(funcs[[1]]$ref, "#example")]]
  } else {
    NULL
  }
  list(query = task, candidates = candidates,
       snippet = .render_snippet(snip))
}

#' Tool: ground-truth signature for a function
#'
#' Returns the introspected formals/defaults, per-arg glosses, description,
#' `\value` text, lifecycle and concepts from the index. Full help is delegated
#' to btw (see the `note`). Accepts `pkg::fn` or a bare name (resolved when
#' unambiguous).
#' @param symbol A `pkg::fn` identifier or bare function name.
#' @param index Optional index path/dir (default: packaged/dev index).
#' @noRd
tool_signature <- function(symbol, index = NULL) {
  idx <- .load_index(index)
  rec <- idx$signatures[[symbol]]
  if (is.null(rec) && !grepl("::", symbol, fixed = TRUE)) {
    hits <- .name_index(idx)[[symbol]]
    if (length(hits) == 1L) {
      rec <- idx$signatures[[hits]]
    } else if (length(hits) > 1L) {
      return(list(error = "ambiguous", symbol = symbol, matches = hits))
    }
  }
  if (is.null(rec)) {
    return(list(error = "not-found", symbol = symbol,
                did_you_mean = .suggest_symbols(idx, symbol)))
  }
  out <- list(
    id = rec$id,
    usage = rec$usage,
    description = rec$description,
    arguments = lapply(rec$formals, function(f) {
      list(arg = f$arg, default = f$default, gloss = f$gloss)
    }),
    value = rec$value_text,
    lifecycle = rec$lifecycle,
    concepts = rec$concepts,
    note = sprintf(
      "Full help via btw_tool_docs_help_page(\"%s\", package = \"%s\").",
      rec$name, rec$package)
  )
  # Phase 6 enrichment (present only when the index was built with shapes = TRUE).
  if (!is.null(rec$example_return_shape)) {
    out$return_shape <- c(
      rec$example_return_shape,
      list(from = "shape of the documented example's last value"))
  }
  if (!is.null(rec$example_status) && !identical(rec$example_status, "none")) {
    out$example_status <- rec$example_status
  }
  out
}

#' Tool: canonical usage snippet(s)
#'
#' Fetch a snippet by `id`, or retrieve the best-matching snippet for a `task`
#' (falling back to the top matching function's Rd example).
#' @param task Natural-language description of the task.
#' @param id A snippet id (e.g. `pkg::fn#example`).
#' @param index Optional index path/dir.
#' @noRd
tool_snippet <- function(task = NULL, id = NULL, index = NULL) {
  idx <- .load_index(index)
  if (!is.null(id)) {
    sn <- idx$snippets[[id]]
    if (is.null(sn)) return(list(error = "not-found", id = id))
    return(.render_snippet(sn))
  }
  if (!is.null(task)) {
    scored <- .score_find(idx$find_doc, task, kinds = "snippet")
    if (length(scored)) return(.render_snippet(idx$snippets[[scored[[1]]$ref]]))
    ff <- .score_find(idx$find_doc, task, kinds = "function")
    if (length(ff)) {
      sn <- idx$snippets[[paste0(ff[[1]]$ref, "#example")]]
      if (!is.null(sn)) return(.render_snippet(sn))
    }
    return(list(query = task, error = "no-snippet"))
  }
  stop("Provide either `task` or `id`.")
}

#' Tool: dataset facts (id conventions, coord space, auth, quirks)
#'
#' Looks up a dataset by id or alias (case-insensitive) in the curated
#' `nv_datasets` facts. Returns the row, or the available names when unmatched.
#' @param name Dataset id or alias (e.g. `"flywire"`).
#' @param index Optional index path/dir.
#' @noRd
tool_dataset <- function(name, index = NULL) {
  idx <- .load_index(index)
  ds <- idx$datasets
  if (!length(ds)) return(list(error = "no-datasets"))
  key <- tolower(trimws(name))
  hit <- ds[[names(ds)[match(key, tolower(names(ds)))]]]
  if (is.null(hit)) {
    aliases <- vapply(ds, function(d) {
      a <- d$aliases %||% ""
      if (length(a) != 1L || is.na(a)) "" else tolower(a)
    }, character(1))
    idxa <- which(vapply(strsplit(aliases, "\\s*,\\s*"),
                         function(v) key %in% v, logical(1)))
    if (length(idxa)) hit <- ds[[idxa[1]]]
  }
  if (is.null(hit)) {
    return(list(error = "not-found", name = name, available = names(ds)))
  }
  hit
}

#' Tool: check code against real natverse symbols / args / deprecations
#'
#' Static check (v1): parses `code`, and for every call to an indexed natverse
#' function flags unknown functions (in a covered package), unknown named
#' arguments (unless the function takes `...`), and deprecated/defunct calls.
#' Calls to non-indexed packages (base, tidyverse, ...) are left alone.
#' @param code A string of R code.
#' @param index Optional index path/dir (default: packaged/dev index).
#' @noRd
tool_lint <- function(code, index = NULL) {
  idx <- .load_index(index)
  exprs <- tryCatch(parse(text = code, keep.source = TRUE),
                    error = function(e) e)
  if (inherits(exprs, "error")) {
    return(list(ok = FALSE, findings = list(
      list(type = "parse-error", message = conditionMessage(exprs)))))
  }
  name_index <- .name_index(idx)
  indexed <- .indexed_packages(idx)
  srcrefs <- attr(exprs, "srcref")

  findings <- list()
  for (i in seq_along(exprs)) {
    line <- if (!is.null(srcrefs)) srcrefs[[i]][1L] else NA_integer_
    findings <- .lint_walk(exprs[[i]], line, idx, name_index, indexed, findings)
  }
  list(
    ok = length(findings) == 0L,
    n_findings = length(findings),
    findings = findings,
    checked_against = idx$manifest$scope,
    index_built = idx$manifest$built_at
  )
}

#' Recurse an expression, checking every call
#' @noRd
.lint_walk <- function(e, line, idx, name_index, indexed, acc) {
  if (is.call(e)) {
    acc <- c(acc, lapply(.check_call(e, idx, name_index, indexed),
                         function(f) c(f, list(line = line))))
    for (i in seq_along(e)) {
      arg <- tryCatch(e[[i]], error = function(err) NULL)
      if (!is.null(arg)) {
        acc <- .lint_walk(arg, line, idx, name_index, indexed, acc)
      }
    }
  }
  acc
}

#' Check a single call; returns a list of findings (possibly empty)
#' @noRd
.check_call <- function(cl, idx, name_index, indexed) {
  fn <- cl[[1L]]
  rec <- NULL
  if (is.call(fn) && length(fn) == 3L && identical(fn[[1L]], as.name("::"))) {
    pkg <- as.character(fn[[2L]])
    nm <- as.character(fn[[3L]])
    id <- paste0(pkg, "::", nm)
    rec <- idx$signatures[[id]]
    if (is.null(rec)) {
      if (pkg %in% indexed) {
        return(list(list(
          type = "unknown-function", call = id,
          message = sprintf("'%s' is not an exported function of %s.", nm, pkg)
        )))
      }
      return(list())
    }
  } else if (is.name(fn)) {
    ids <- name_index[[as.character(fn)]]
    if (length(ids) != 1L) return(list())  # unknown or ambiguous: skip
    rec <- idx$signatures[[ids]]
  } else {
    return(list())
  }

  findings <- list()
  if (rec$lifecycle %in% c("deprecated", "defunct")) {
    findings <- c(findings, list(list(
      type = paste0("lifecycle-", rec$lifecycle), call = rec$id,
      message = sprintf("%s is %s.", rec$id, rec$lifecycle)
    )))
  }
  formal_args <- vapply(rec$formals, function(f) f$arg, character(1))
  if (!("..." %in% formal_args)) {
    supplied <- names(cl)
    supplied <- supplied[!is.na(supplied) & nzchar(supplied)]
    unknown <- Filter(function(a) !any(startsWith(formal_args, a)), supplied)
    for (u in unknown) {
      findings <- c(findings, list(list(
        type = "unknown-argument", call = rec$id, argument = u,
        message = sprintf("'%s' is not an argument of %s.", u, rec$id)
      )))
    }
  }
  findings
}

.nyi <- function(what) stop(sprintf("tool '%s' not implemented yet", what))
