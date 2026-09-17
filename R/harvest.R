# Tier-2 harvest: turn Rd examples and vignettes into snippet records, tag which
# indexed functions each snippet calls (static analysis), and build a lexical
# retrieval document (find_doc) over functions + snippets. Backs the find and
# snippet tools. Offline / installed-package sources only; pkgdown reference
# groups and source-first harvesting are deferred to the CI phase.

#' Snippet from a signature record's Rd \examples block
#' @noRd
.rd_example_snippet <- function(rec) {
  code <- rec$examples_text
  if (is.null(code) || is.na(code) || !nzchar(trimws(code))) return(NULL)
  list(
    id = paste0(rec$id, "#example"),
    title = rec$name,
    intent = .first_sentence(rec$description),
    code = trimws(code),
    packages = character(0),   # filled by .tag_snippet()
    functions = character(0),
    level = "example",
    kind = "rd-example",
    source_ref = rec$package
  )
}

#' Harvest vignette code from an installed package
#' @noRd
harvest_vignettes <- function(pkg) {
  info <- tryCatch(tools::getVignetteInfo(pkg), error = function(e) NULL)
  if (is.null(info) || !nrow(info)) return(list())
  docdir <- system.file("doc", package = pkg)
  cols <- colnames(info)
  out <- list()
  for (i in seq_len(nrow(info))) {
    rfile <- if ("R" %in% cols) info[i, "R"] else ""
    if (!nzchar(rfile)) next
    path <- file.path(docdir, rfile)
    if (!file.exists(path)) next
    code <- tryCatch(paste(readLines(path, warn = FALSE), collapse = "\n"),
                     error = function(e) "")
    if (!nzchar(trimws(code))) next
    title <- if ("Title" %in% cols) info[i, "Title"] else rfile
    out[[length(out) + 1L]] <- list(
      id = paste0(pkg, ":vignette:", rfile),
      title = title,
      intent = title,
      code = trimws(code),
      packages = character(0),
      functions = character(0),
      level = "vignette",
      kind = "vignette",
      source_ref = pkg
    )
  }
  out
}

#' Static-analysis tag: which indexed functions does this snippet call?
#'
#' Parses the code and resolves each called function name against the index's
#' name map. Ambiguous bare names prefer a match in the snippet's own package,
#' otherwise all candidates are kept (over-tagging is safe for retrieval).
#' @noRd
.tag_snippet <- function(snippet, name_index) {
  pd <- tryCatch(
    utils::getParseData(parse(text = snippet$code, keep.source = TRUE)),
    error = function(e) NULL
  )
  if (is.null(pd) || !nrow(pd)) return(snippet)
  calls <- unique(pd$text[pd$token == "SYMBOL_FUNCTION_CALL"])
  prefer <- snippet$source_ref
  ids <- character(0)
  for (nm in calls) {
    hit <- name_index[[nm]]
    if (is.null(hit)) next
    if (length(hit) > 1L) {
      pref <- hit[startsWith(hit, paste0(prefer, "::"))]
      if (length(pref)) hit <- pref
    }
    ids <- c(ids, hit)
  }
  ids <- unique(ids)
  snippet$functions <- ids
  snippet$packages <- unique(sub("::.*$", "", ids))
  snippet
}

#' Build the lexical retrieval document over functions + snippets
#' @noRd
.build_find_doc <- function(signatures, snippets) {
  fdoc <- vector("list", length(signatures) + length(snippets))
  k <- 0L
  for (rec in signatures) {
    txt <- paste(stats::na.omit(c(rec$name, rec$description, rec$value_text,
                                  paste(rec$concepts, collapse = " "))),
                 collapse = " ")
    k <- k + 1L
    fdoc[[k]] <- list(ref = rec$id, kind = "function", package = rec$package,
                      name = rec$name, text = tolower(txt))
  }
  for (sn in snippets) {
    txt <- paste(stats::na.omit(c(sn$title, sn$intent,
                                  paste(sn$functions, collapse = " "))),
                 collapse = " ")
    k <- k + 1L
    fdoc[[k]] <- list(ref = sn$id, kind = "snippet", package = sn$source_ref,
                      name = sn$title, text = tolower(txt))
  }
  fdoc
}

# --- retrieval + rendering (shared by find / snippet tools) ------------------

#' @noRd
.tokenize <- function(x) {
  toks <- unlist(strsplit(tolower(x), "[^a-z0-9_.]+"))
  unique(toks[nchar(toks) >= 2L])
}

#' @noRd
.first_sentence <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) return(NA_character_)
  sub("([.!?])\\s.*$", "\\1", x)
}

#' Lexical scoring over find_doc; higher score = better
#' @noRd
.score_find <- function(fdoc, query, package = NULL, kinds = NULL) {
  terms <- .tokenize(query)
  if (!length(terms)) return(list())
  scored <- lapply(fdoc, function(d) {
    if (!is.null(package) && !identical(d$package, package)) return(NULL)
    if (!is.null(kinds) && !(d$kind %in% kinds)) return(NULL)
    hits <- sum(vapply(terms, function(tm) grepl(tm, d$text, fixed = TRUE),
                       logical(1)))
    if (tolower(d$name) %in% terms) hits <- hits + 3L   # boost exact name
    if (hits == 0L) return(NULL)
    list(ref = d$ref, kind = d$kind, package = d$package, name = d$name,
         score = hits)
  })
  scored <- Filter(Negate(is.null), scored)
  scored[order(-vapply(scored, function(x) x$score, numeric(1)))]
}

#' @noRd
.render_snippet <- function(sn) {
  if (is.null(sn)) return(NULL)
  list(id = sn$id, title = sn$title, level = sn$level, code = sn$code,
       functions = sn$functions, packages = sn$packages)
}
