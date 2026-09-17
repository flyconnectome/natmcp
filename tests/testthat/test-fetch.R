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
