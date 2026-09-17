test_that("runnable example extraction comments out dontrun/donttest", {
  skip_if_not_installed("jsonlite")
  db <- tools::Rd_db("jsonlite")
  codes <- vapply(db, function(rd) {
    x <- .runnable_example(rd)
    if (is.na(x)) "" else x
  }, character(1))
  expect_true(any(nzchar(codes)))
  # Rd2ex renders skipped blocks as "## Not run:" / "## Don't ..." comments.
  joined <- paste(codes, collapse = "\n")
  expect_false(grepl("(?m)^\\s*\\\\dontrun", joined, perl = TRUE))
})

test_that("sandboxed run captures ok status and a shape", {
  skip_if_not_installed("callr")
  res <- .run_example_sandboxed(
    "base", "x <- toupper(letters[1:3])\nx", timeout = 30)
  expect_identical(res$status, "ok")
  expect_identical(res$shape$class, "character")
  expect_identical(res$shape$length, 3L)
})

test_that("sandboxed run reports errors as stale, not a crash", {
  skip_if_not_installed("callr")
  res <- .run_example_sandboxed("base", "stop('boom')", timeout = 30)
  expect_identical(res$status, "error")
  expect_match(res$error, "boom")
  expect_null(res$shape)
})

test_that("build_index(shapes = TRUE) attaches freshness + surfaces shape", {
  skip_if_not_installed("callr")
  skip_if_not_installed("jsonlite")
  od <- build_test_index("jsonlite", shapes = TRUE)
  idx <- .load_index(od)
  expect_false(is.null(idx$manifest$examples))
  statuses <- vapply(idx$signatures,
                     function(r) r$example_status %||% "none", character(1))
  expect_true(all(statuses %in% c("ok", "error", "timeout", "none")))
  expect_true(any(statuses == "ok"))

  # a signature that ran ok and carries a shape surfaces it via tool_signature
  with_shape <- Filter(
    function(r) !is.null(r$example_return_shape), idx$signatures)
  skip_if(length(with_shape) == 0L, "no example produced a shape")
  sig <- tool_signature(with_shape[[1]]$id, index = od)
  expect_false(is.null(sig$return_shape))
  expect_match(sig$return_shape$from, "example")
})

test_that("example_code is stripped from the served index", {
  skip_if_not_installed("jsonlite")
  od <- build_test_index("jsonlite", shapes = FALSE)
  idx <- .load_index(od)
  has_code <- vapply(idx$signatures,
                     function(r) !is.null(r$example_code), logical(1))
  expect_false(any(has_code))
})
