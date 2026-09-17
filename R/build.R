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
#' @param shapes If `TRUE`, run each function's offline-runnable `@examples` in
#'   a sandboxed [callr] process to capture a freshness status and a best-effort
#'   return shape (Phase 6). Off by default; CI turns it on. Requires `callr`.
#' @param shape_timeout Per-example wall-clock timeout in seconds when
#'   `shapes = TRUE`.
#' @return Invisibly, the path to the written index directory.
#' @export
build_index <- function(config = system.file("config", "packages.yml",
                                              package = "natmcp"),
                        out_dir = file.path("inst", "index"),
                        scope = c("offline", "online"),
                        shapes = FALSE, shape_timeout = 60) {
  scope <- match.arg(scope)
  if (identical(scope, "online")) {
    stop("online enrichment scope is not implemented yet (Phase 6/7). ",
         "See PLAN.md.")
  }
  cfg <- read_config(config)
  targets <- resolve_packages(cfg)

  signatures <- list()
  sources <- list()
  pkgmeta <- list()

  for (t in targets) {
    p <- t$package
    if (!.is_installed(p)) {
      pkgmeta[[p]] <- list(name = p, coverage = t$coverage, installed = FALSE,
                           version = NA_character_, n_signatures = 0L,
                           status = "not-installed")
      cli::cli_alert_warning("{.pkg {p}} not installed; skipped.")
      next
    }
    ver <- as.character(utils::packageVersion(p))
    recs <- tryCatch(
      extract_signatures(p, coverage = t$coverage, allowlist = t$allowlist),
      error = function(e) {
        cli::cli_alert_warning("Failed to introspect {.pkg {p}}: {conditionMessage(e)}")
        NULL
      }
    )
    signatures <- c(signatures, recs)
    sources[[p]] <- list(
      id = p, package = p, pkg_version = ver, kind = "installed-namespace",
      lib_path = dirname(system.file(package = p)), git_sha = NA_character_,
      fetched_at = as.character(Sys.time()),
      extractor_version = .extractor_version
    )
    pkgmeta[[p]] <- list(name = p, coverage = t$coverage, installed = TRUE,
                         version = ver, n_signatures = length(recs),
                         status = "ok")
    cli::cli_alert_success("{.pkg {p}} {ver}: {length(recs)} signature{?s}")
  }

  # Phase 6: run offline-runnable examples for freshness + return shapes.
  if (isTRUE(shapes)) {
    signatures <- .capture_shapes(signatures, timeout = shape_timeout)
  }
  # example_code is a build-time artifact (snippets carry runnable code); drop it
  # so it never bloats the served index.
  signatures <- lapply(signatures, function(r) {
    r$example_code <- NULL
    r
  })

  # Tier-2 harvest: snippets (Rd examples + vignettes), tagged against the full
  # signature set, plus a lexical retrieval document.
  name_index <- .name_index(list(signatures = signatures))
  snippets <- list()
  for (rec in signatures) {
    sn <- .rd_example_snippet(rec)
    if (!is.null(sn)) snippets[[sn$id]] <- .tag_snippet(sn, name_index)
  }
  for (p in names(sources)) {
    for (sn in harvest_vignettes(p)) {
      snippets[[sn$id]] <- .tag_snippet(sn, name_index)
    }
  }
  find_doc <- .build_find_doc(signatures, snippets)
  cli::cli_alert_success("Harvested {length(snippets)} snippet{?s}")

  # Tier-3 curated corpus: guide, dataset facts, auto-seeded package roles.
  guide <- .load_guide()
  datasets <- .datasets_records(.load_datasets())
  roles <- .package_roles(names(sources))
  for (p in names(roles)) pkgmeta[[p]]$role <- roles[[p]]
  cli::cli_alert_success("Folded in guide + {length(datasets)} dataset{?s}")

  manifest <- list(
    schema_version = .schema_version,
    extractor_version = .extractor_version,
    scope = scope,
    built_at = as.character(Sys.time()),
    n_packages = length(pkgmeta),
    n_signatures = length(signatures),
    n_snippets = length(snippets),
    n_datasets = length(datasets),
    examples = if (isTRUE(shapes)) .freshness(signatures) else NULL,
    packages = unname(pkgmeta)
  )
  index <- list(manifest = manifest, signatures = signatures,
                snippets = snippets, find_doc = find_doc,
                guide = guide, datasets = datasets, sources = sources)
  .write_index(index, out_dir)
  cli::cli_alert_info("Wrote index ({length(signatures)} signatures, \\
                      {length(snippets)} snippets) to {.path {out_dir}}")
  invisible(out_dir)
}

#' Resolve the packages to index from the scrape config
#'
#' Tier-1 (offline) works from the *installed* namespaces of the explicit
#' `tier_A_core` list (full coverage) plus the `adjacent` allowlist packages.
#' Live org enumeration (all natverse/flyconnectome repos) and source-first
#' SHA resolution are deferred to the CI/online phases; here the reproducible
#' set is the config's curated lists intersected with what is installed.
#'
#' @param cfg Parsed config (see [read_config()]).
#' @return A list of target descriptors, each a list with `package`, `tier`,
#'   `coverage` and `allowlist`.
#' @noRd
resolve_packages <- function(cfg) {
  targets <- lapply(unlist(cfg$tier_A_core, use.names = FALSE), function(p) {
    list(package = p, tier = "core", coverage = "full", allowlist = NULL)
  })
  adj <- cfg$adjacent
  for (p in names(adj)) {
    targets[[length(targets) + 1L]] <- list(
      package = p, tier = "adjacent",
      coverage = adj[[p]]$coverage %||% "allowlist",
      allowlist = unlist(adj[[p]]$functions, use.names = FALSE)
    )
  }
  excl <- unlist(cfg$exclude, use.names = FALSE)
  Filter(function(t) !(t$package %in% excl), targets)
}

#' Extract signature records for one installed package
#'
#' Introspects the package namespace: exported functions, their `formals()`
#' (arg + default), and the matching Rd help (description, `\value`, per-arg
#' glosses, examples, keywords/concepts). `coverage = "allowlist"` restricts to
#' the interop surface passed in `allowlist` (Tier B adjacent foundations).
#'
#' @param pkg Installed package name.
#' @param coverage `"full"` (all exports) or `"allowlist"`.
#' @param allowlist Character vector of function names (allowlist coverage).
#' @return A named list of signature records keyed by `pkg::fn`.
#' @noRd
extract_signatures <- function(pkg, coverage = "full", allowlist = NULL) {
  ns <- asNamespace(pkg)
  exports <- getNamespaceExports(pkg)
  if (identical(coverage, "allowlist") && length(allowlist)) {
    exports <- intersect(allowlist, exports)
  }
  alias_map <- .rd_index(pkg)

  recs <- list()
  for (nm in sort(exports)) {
    obj <- tryCatch(get(nm, envir = ns), error = function(e) NULL)
    if (!is.function(obj)) next
    entry <- alias_map[[nm]]
    glosses <- if (!is.null(entry)) entry$arguments else list()
    fr <- .formals_records(obj, glosses)
    id <- paste0(pkg, "::", nm)
    recs[[id]] <- list(
      id = id, package = pkg, name = nm, exported = TRUE, coverage = coverage,
      usage = .usage(nm, fr), formals = fr,
      description = if (!is.null(entry)) entry$description else NA_character_,
      value_text = if (!is.null(entry)) entry$value else NA_character_,
      examples_text = if (!is.null(entry)) entry$examples else NA_character_,
      example_code = if (!is.null(entry)) entry$example_code else NA_character_,
      concepts = if (!is.null(entry)) {
        unique(c(entry$keywords, entry$concepts))
      } else character(0),
      lifecycle = .detect_lifecycle(obj),
      source_ref = pkg
    )
  }
  recs
}

# --- formals -> records ------------------------------------------------------

#' @noRd
.formals_records <- function(fn, glosses = list()) {
  fmls <- formals(fn)
  if (is.null(fmls) && is.primitive(fn)) fmls <- formals(args(fn))
  if (is.null(fmls)) return(list())
  # Pass each formal in as a function argument (do not extract-then-assign, which
  # forces the empty-arg marker and errors); identical()/deparse() are safe here.
  unname(Map(function(nm, d) {
    default <- if (identical(d, quote(expr = ))) {
      NA_character_
    } else {
      paste(deparse(d), collapse = " ")
    }
    list(arg = nm, default = default, gloss = glosses[[nm]] %||% NA_character_)
  }, names(fmls), fmls))
}

#' @noRd
.usage <- function(name, formals_records) {
  parts <- vapply(formals_records, function(f) {
    if (is.na(f$default)) f$arg else paste0(f$arg, " = ", f$default)
  }, character(1))
  paste0(name, "(", paste(parts, collapse = ", "), ")")
}

#' @noRd
.detect_lifecycle <- function(fn) {
  body_txt <- paste(deparse(fn), collapse = "\n")
  if (grepl("\\.Defunct\\(", body_txt)) return("defunct")
  if (grepl("\\.Deprecated\\(|lifecycle::deprecate", body_txt)) {
    return("deprecated")
  }
  "stable"
}

# --- Rd parsing --------------------------------------------------------------

#' Build an alias -> parsed-Rd-entry map for a package
#' @noRd
.rd_index <- function(pkg) {
  db <- tryCatch(tools::Rd_db(pkg), error = function(e) NULL)
  if (is.null(db) || !length(db)) return(list())
  alias_map <- list()
  for (rd in db) {
    entry <- tryCatch(.parse_rd(rd), error = function(e) NULL)
    if (is.null(entry)) next
    for (a in entry$aliases) alias_map[[a]] <- entry
  }
  alias_map
}

#' @noRd
.parse_rd <- function(rd) {
  tags <- .rd_tags(rd)
  aliases <- trimws(vapply(rd[tags == "\\alias"], .rd_flatten, character(1)))
  list(
    aliases = aliases,
    description = .rd_section(rd, tags, "\\description"),
    value = .rd_section(rd, tags, "\\value"),
    examples = .rd_section(rd, tags, "\\examples", clean = FALSE),
    example_code = .runnable_example(rd),
    arguments = .rd_arguments(rd, tags),
    keywords = trimws(vapply(rd[tags == "\\keyword"], .rd_flatten,
                             character(1))),
    concepts = trimws(vapply(rd[tags == "\\concept"], .rd_flatten,
                             character(1)))
  )
}

#' @noRd
.rd_tags <- function(x) {
  vapply(x, function(el) {
    t <- attr(el, "Rd_tag")
    if (is.null(t)) "" else t
  }, character(1))
}

#' Flatten an Rd fragment to plain text
#' @noRd
.rd_flatten <- function(x) {
  if (is.null(x)) return("")
  tag <- attr(x, "Rd_tag")
  if (!is.null(tag) && tag == "\\dots") return("...")
  if (is.character(x)) return(paste0(x, collapse = ""))
  if (is.list(x)) {
    return(paste0(vapply(x, .rd_flatten, character(1)), collapse = ""))
  }
  paste0(as.character(x), collapse = "")
}

#' @noRd
.rd_section <- function(rd, tags, tag, clean = TRUE) {
  idx <- which(tags == tag)
  if (!length(idx)) return(NA_character_)
  txt <- .rd_flatten(rd[[idx[1]]])
  txt <- if (clean) trimws(gsub("[[:space:]]+", " ", txt)) else trimws(txt)
  if (!nzchar(txt)) NA_character_ else txt
}

#' Per-argument glosses from an Rd \arguments block
#' @noRd
.rd_arguments <- function(rd, tags) {
  idx <- which(tags == "\\arguments")
  if (!length(idx)) return(list())
  block <- rd[[idx[1]]]
  btags <- .rd_tags(block)
  items <- block[btags == "\\item"]
  out <- list()
  for (it in items) {
    nm <- trimws(gsub("[[:space:]]+", " ", .rd_flatten(it[[1]])))
    desc <- trimws(gsub("[[:space:]]+", " ", .rd_flatten(it[[2]])))
    for (a in strsplit(nm, "\\s*,\\s*")[[1]]) {
      a <- trimws(a)
      if (nzchar(a)) out[[a]] <- desc
    }
  }
  out
}

#' Fetch a published natmcp index
#'
#' The server-side half of the deployment split: pulls the index artifact
#' published by CI (see [build_index()]) to a local cache and verifies schema
#' compatibility from its manifest. Serving needs no natverse toolchain, so this
#' runs the same for a local stdio server or a hosted HTTP endpoint. Once
#' fetched, the cached index is picked up automatically by
#' [natmcp_mcp_server()] / the tools when `index = NULL`.
#'
#' @details
#' `source` is a base URL (the directory holding `index.rds` + `manifest.json`)
#' or a direct `index.rds` URL. When `NULL` it is taken from the
#' `natmcp.index_url` option, then the `NATMCP_INDEX_URL` environment variable,
#' then the default GitHub Pages location. The manifest is fetched first; if its
#' `schema_version` does not match the installed package the download is refused
#' with an upgrade hint. A re-fetch is skipped when the cached copy already has
#' the same `built_at`, unless `force = TRUE`.
#'
#' @param source Base URL or direct `index.rds` URL to fetch from (see details).
#' @param cache_dir Local cache directory (default:
#'   `tools::R_user_dir("natmcp", "cache")`).
#' @param force Re-download even when the cached copy is already current.
#' @return Invisibly, the path to the local index directory.
#' @export
fetch_index <- function(source = NULL, cache_dir = NULL, force = FALSE) {
  source <- source %||% getOption("natmcp.index_url") %||%
    Sys.getenv("NATMCP_INDEX_URL", unset = .default_index_url)
  base <- sub("/index\\.rds$", "", source)
  base <- sub("/$", "", base)
  manifest_url <- paste0(base, "/manifest.json")
  index_url <- paste0(base, "/index.rds")
  cache_dir <- cache_dir %||% tools::R_user_dir("natmcp", "cache")

  manifest <- tryCatch(
    suppressWarnings(jsonlite::read_json(manifest_url, simplifyVector = TRUE)),
    error = function(e) {
      cli::cli_abort(c("Could not read index manifest from {.url {manifest_url}}.",
                       x = conditionMessage(e)))
    })
  remote_schema <- as.character(manifest$schema_version)
  if (!identical(remote_schema, .schema_version)) {
    cli::cli_abort(c(
      "Index schema mismatch.",
      i = "Published index is schema {.val {remote_schema}}; this natmcp expects \\
           {.val {.schema_version}}.",
      i = "Update natmcp (or point {.arg source} at a matching index)."))
  }

  fs::dir_create(cache_dir)
  local_manifest <- file.path(cache_dir, "manifest.json")
  if (!isTRUE(force) && file.exists(file.path(cache_dir, "index.rds")) &&
      file.exists(local_manifest)) {
    cur <- tryCatch(jsonlite::read_json(local_manifest, simplifyVector = TRUE),
                    error = function(e) NULL)
    if (!is.null(cur) && identical(cur$built_at, manifest$built_at)) {
      cli::cli_alert_info("Index already current ({manifest$built_at}); \\
                          cached at {.path {cache_dir}}.")
      return(invisible(cache_dir))
    }
  }

  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)
  ok <- tryCatch({
    if (file.exists(index_url)) {
      file.copy(index_url, tmp, overwrite = TRUE)       # local / mounted source
    } else {
      utils::download.file(index_url, tmp, mode = "wb", quiet = TRUE)
    }
    TRUE
  }, error = function(e) {
    cli::cli_abort(c("Could not fetch index from {.url {index_url}}.",
                     x = conditionMessage(e)))
  })
  # Validate before committing to cache.
  idx <- tryCatch(readRDS(tmp), error = function(e) {
    cli::cli_abort("Downloaded index is not a valid .rds: {conditionMessage(e)}")
  })
  if (!is.list(idx) || is.null(idx$manifest) || is.null(idx$signatures)) {
    cli::cli_abort("Downloaded index is missing expected fields.")
  }
  file.copy(tmp, file.path(cache_dir, "index.rds"), overwrite = TRUE)
  jsonlite::write_json(manifest, local_manifest, auto_unbox = TRUE,
                       pretty = TRUE, null = "null")
  cli::cli_alert_success(
    "Fetched index ({manifest$n_signatures} signatures, built {manifest$built_at}) \\
     to {.path {cache_dir}}.")
  invisible(cache_dir)
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
