# Phase 6: sandboxed example execution.
#
# Running a function's documented @examples in a throwaway process does two jobs
# at once:
#   * freshness  -- an example that errors is a signal the API (or the example)
#                   has drifted; we record ok / error / timeout / none.
#   * return shape -- a *best-effort* hint at what the function yields, taken as
#                   the class/length/dim/names of the example's final value.
#                   It is labelled as "from the example's last value", not
#                   claimed as a canonical return contract, because an example's
#                   last expression is not always a call to the documented fn.
#
# Only the offline-runnable subset is executed: `\dontrun` and `\donttest`
# blocks (which routinely need CAVE/neuprint auth or the network) are commented
# out by Rd2ex before we ever parse the code. Everything runs in an isolated
# `callr` process with a wall-clock timeout and a null graphics device.

#' Runnable example code for one Rd topic, dontrun/donttest commented out
#'
#' @param rd A single parsed Rd object (element of `tools::Rd_db()`).
#' @return A string of runnable R code, or `NA_character_` if none.
#' @noRd
.runnable_example <- function(rd) {
  tmp <- tempfile(fileext = ".R")
  on.exit(unlink(tmp), add = TRUE)
  ok <- tryCatch({
    tools::Rd2ex(rd, out = tmp, commentDontrun = TRUE, commentDonttest = TRUE)
    TRUE
  }, error = function(e) FALSE)
  if (!isTRUE(ok) || !file.exists(tmp)) return(NA_character_)
  code <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  if (!nzchar(trimws(code))) return(NA_character_)
  code
}

#' Execute example code in an isolated process, capturing status + last shape
#'
#' @param pkg Package to attach in the child before evaluating.
#' @param code Runnable example code (see [.runnable_example()]).
#' @param timeout Wall-clock seconds before the child is killed.
#' @return A list: `status` (ok|error|timeout), `error` (message or NA) and
#'   `shape` (a shape record or `NULL`).
#' @noRd
.run_example_sandboxed <- function(pkg, code, timeout = 60) {
  res <- tryCatch(
    callr::r(
      function(pkg, code) {
        suppressWarnings(suppressPackageStartupMessages(
          library(pkg, character.only = TRUE)))
        grDevices::pdf(NULL)                    # swallow any plotting
        on.exit(try(grDevices::dev.off(), silent = TRUE), add = TRUE)
        exprs <- parse(text = code)
        last <- list(value = NULL)
        for (e in exprs) last <- withVisible(eval(e, envir = globalenv()))
        v <- last$value
        list(class = class(v), typeof = typeof(v), length = length(v),
             dim = dim(v), names = utils::head(names(v), 20L),
             n_names = length(names(v)))
      },
      args = list(pkg = pkg, code = code),
      timeout = timeout
    ),
    error = function(e) e
  )
  if (inherits(res, "condition")) {
    msg <- conditionMessage(res)
    status <- if (inherits(res, "callr_timeout_error") ||
                  grepl("timed out|timeout", msg, ignore.case = TRUE)) {
      "timeout"
    } else {
      "error"
    }
    return(list(status = status, error = msg, shape = NULL))
  }
  list(status = "ok", error = NA_character_, shape = .clean_shape(res))
}

#' Tidy a raw shape record from the child (drop empties, cap names)
#' @noRd
.clean_shape <- function(s) {
  out <- list(class = s$class, typeof = s$typeof, length = s$length)
  if (!is.null(s$dim)) out$dim <- s$dim
  if (length(s$names)) {
    out$names <- s$names
    if (isTRUE(s$n_names > length(s$names))) out$names_truncated <- TRUE
  }
  out
}

#' Run examples for every signature that has one; attach freshness + shape
#'
#' Deduplicates by example code (aliases share a topic) so each example runs
#' once. Requires `callr`; if absent, signatures are returned unchanged.
#'
#' @param signatures Named list of signature records.
#' @param timeout Per-example wall-clock timeout (seconds).
#' @return The signatures, each gaining `example_status` and (on success)
#'   `example_return_shape`.
#' @noRd
.capture_shapes <- function(signatures, timeout = 60) {
  if (!.is_installed("callr")) {
    cli::cli_alert_warning(
      "{.pkg callr} not installed; skipping example execution (Phase 6).")
    return(signatures)
  }
  cache <- new.env(parent = emptyenv())
  n_ok <- 0L
  n_stale <- 0L
  for (id in names(signatures)) {
    rec <- signatures[[id]]
    code <- rec$example_code
    if (is.null(code) || length(code) != 1L || is.na(code) || !nzchar(code)) {
      rec$example_status <- "none"
      signatures[[id]] <- rec
      next
    }
    key <- paste0(rec$package, "\r", code)
    res <- if (!is.null(cache[[key]])) {
      cache[[key]]
    } else {
      r <- .run_example_sandboxed(rec$package, code, timeout = timeout)
      assign(key, r, envir = cache)
      r
    }
    rec$example_status <- res$status
    if (identical(res$status, "ok")) {
      n_ok <- n_ok + 1L
      if (!is.null(res$shape)) rec$example_return_shape <- res$shape
    } else {
      n_stale <- n_stale + 1L
      rec$example_error <- res$error
    }
    signatures[[id]] <- rec
  }
  cli::cli_alert_success(
    "Ran examples: {n_ok} ok, {n_stale} stale/errored (freshness check)")
  signatures
}

#' Tally example_status across signatures for the manifest
#' @noRd
.freshness <- function(signatures) {
  st <- vapply(signatures, function(r) r$example_status %||% "none",
               character(1))
  lv <- c("ok", "error", "timeout", "none")
  as.list(table(factor(st, levels = lv)))
}
