test_that("fetch_index copies a local index into the cache and validates it", {
  src <- build_test_index("jsonlite")           # a built index directory
  cache <- tempfile()
  suppressMessages(fetch_index(source = src, cache_dir = cache))
  expect_true(file.exists(file.path(cache, "index.rds")))
  expect_true(file.exists(file.path(cache, "manifest.json")))
  idx <- .load_index(cache)
  expect_identical(idx$manifest$schema_version, .schema_version)
})

test_that("fetch_index skips re-fetch when already current", {
  src <- build_test_index("jsonlite")
  cache <- tempfile()
  suppressMessages(fetch_index(source = src, cache_dir = cache))
  # second call with the same source is a no-op (same built_at)
  msg <- cli::cli_fmt(fetch_index(source = src, cache_dir = cache))
  expect_match(paste(msg, collapse = " "), "already current")
})

test_that("fetch_index refuses a schema mismatch", {
  src <- build_test_index("jsonlite")
  # rewrite the manifest to an incompatible schema
  mf <- jsonlite::read_json(file.path(src, "manifest.json"),
                            simplifyVector = TRUE)
  mf$schema_version <- "999"
  jsonlite::write_json(mf, file.path(src, "manifest.json"),
                       auto_unbox = TRUE, pretty = TRUE, null = "null")
  cache <- tempfile()
  expect_error(
    suppressMessages(fetch_index(source = src, cache_dir = cache)),
    "schema")
})

test_that("fetch_index errors clearly on an unreachable source", {
  cache <- tempfile()
  expect_error(
    suppressMessages(fetch_index(
      source = file.path(tempfile(), "nowhere"), cache_dir = cache)),
    "manifest")
})

test_that(".load_index fetches the published index on first use", {
  src <- build_test_index("jsonlite")
  cache <- tempfile()
  local_mocked_bindings(
    .index_path = function(index = NULL) {
      p <- file.path(cache, "index.rds")
      if (file.exists(p)) p else ""
    },
    fetch_index = function(...) {
      fs::dir_create(cache)
      file.copy(file.path(src, "index.rds"), cache)
    }
  )
  idx <- .load_index()
  expect_identical(idx$manifest$schema_version, .schema_version)
  expect_true(file.exists(file.path(cache, "index.rds")))
})

test_that(".load_index reports why an automatic fetch failed", {
  local_mocked_bindings(
    .index_path = function(index = NULL) "",
    fetch_index = function(...) stop("offline")
  )
  expect_error(.load_index(), "Automatic fetch failed: offline")
  old <- options(natmcp.auto_fetch = FALSE)
  on.exit(options(old), add = TRUE)
  expect_error(.load_index(), "No natmcp index found")
})

test_that(".maybe_refresh_index only re-checks a stale cached index", {
  cache <- tempfile()
  dir.create(cache)
  on.exit(unlink(cache, recursive = TRUE), add = TRUE)
  file.create(file.path(cache, c("index.rds", "manifest.json")))
  n <- 0
  local_mocked_bindings(
    .index_path = function(index = NULL) file.path(cache, "index.rds"),
    fetch_index = function(...) n <<- n + 1)
  local_mocked_bindings(R_user_dir = function(...) cache, .package = "tools")
  old <- options(natmcp.auto_fetch = NULL, natmcp.refresh_days = NULL)
  on.exit(options(old), add = TRUE)

  expect_identical(.maybe_refresh_index("some/index"), "skipped")
  expect_identical(.maybe_refresh_index(), "fresh")
  Sys.setFileTime(file.path(cache, "manifest.json"), Sys.time() - 8 * 86400)
  expect_identical(.maybe_refresh_index(), "checked")
  expect_equal(n, 1)
  options(natmcp.auto_fetch = FALSE)
  expect_identical(.maybe_refresh_index(), "skipped")
  options(natmcp.auto_fetch = NULL)
  local_mocked_bindings(fetch_index = function(...) stop("offline"))
  expect_identical(.maybe_refresh_index(), "failed")
})

test_that(".maybe_refresh_index leaves a packaged or dev index alone", {
  cache <- tempfile()
  dir.create(cache)
  on.exit(unlink(cache, recursive = TRUE), add = TRUE)
  file.create(file.path(cache, "manifest.json"))
  Sys.setFileTime(file.path(cache, "manifest.json"), Sys.time() - 8 * 86400)
  local_mocked_bindings(.index_path = function(index = NULL) "inst/index/index.rds",
                        fetch_index = function(...) stop("should not fetch"))
  local_mocked_bindings(R_user_dir = function(...) cache, .package = "tools")
  expect_identical(.maybe_refresh_index(), "skipped")
})

test_that("fetch_index records the check when already current", {
  src <- build_test_index("jsonlite")
  cache <- tempfile()
  suppressMessages(fetch_index(source = src, cache_dir = cache))
  mf <- file.path(cache, "manifest.json")
  Sys.setFileTime(mf, Sys.time() - 8 * 86400)
  suppressMessages(fetch_index(source = src, cache_dir = cache))
  expect_lt(as.numeric(difftime(Sys.time(), file.mtime(mf), units = "days")), 1)
})
