# build_test_index() is defined in helper-index.R.

test_that("tool_signature returns the ground-truth signature", {
  od <- build_test_index()
  sig <- tool_signature("jsonlite::fromJSON", index = od)
  expect_identical(sig$id, "jsonlite::fromJSON")
  expect_true(any(vapply(sig$arguments, function(a) a$arg == "txt", logical(1))))
  expect_identical(sig$lifecycle, "stable")
  expect_match(sig$note, "btw_tool_docs_help_page")
})

test_that("tool_signature resolves an unambiguous bare name", {
  od <- build_test_index()
  sig <- tool_signature("fromJSON", index = od)
  expect_identical(sig$id, "jsonlite::fromJSON")
})

test_that("tool_signature reports not-found with suggestions", {
  od <- build_test_index()
  res <- tool_signature("frmJSON", index = od)
  expect_identical(res$error, "not-found")
  expect_true("jsonlite::fromJSON" %in% res$did_you_mean)
})

test_that("tool_lint flags an unknown named argument", {
  od <- build_test_index()
  res <- tool_lint("jsonlite::base64_dec(input = x, nope = 1)", index = od)
  expect_false(res$ok)
  types <- vapply(res$findings, function(f) f$type, character(1))
  expect_true("unknown-argument" %in% types)
})

test_that("tool_lint passes clean code and respects ...", {
  od <- build_test_index()
  # fromJSON takes ..., so an extra named arg is legitimate
  res <- tool_lint("jsonlite::fromJSON(txt = x, anything = 1)", index = od)
  expect_true(res$ok)
})

test_that("tool_lint flags a non-existent function in an indexed package", {
  od <- build_test_index()
  res <- tool_lint("jsonlite::no_such_fn(1)", index = od)
  expect_false(res$ok)
  expect_identical(res$findings[[1]]$type, "unknown-function")
})

test_that("tool_lint ignores calls to non-indexed packages", {
  od <- build_test_index()
  res <- tool_lint("base::sum(1, 2)\nmean(1:10)", index = od)
  expect_true(res$ok)
})

test_that("tool_lint reports a parse error", {
  od <- build_test_index()
  res <- tool_lint("jsonlite::fromJSON(", index = od)
  expect_false(res$ok)
  expect_identical(res$findings[[1]]$type, "parse-error")
})
