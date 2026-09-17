tool_named <- function(tl, name) {
  Filter(function(t) t@name == name, tl)[[1]]
}

test_that("natmcp_tools returns all six ellmer tools", {
  tl <- natmcp_tools()
  expect_length(tl, 6)
  expect_true(all(vapply(tl, function(t) inherits(t, "ellmer::ToolDef"),
                         logical(1))))
  expect_setequal(
    vapply(tl, function(t) t@name, character(1)),
    c("natmcp_guide", "natmcp_find", "natmcp_signature", "natmcp_snippet",
      "natmcp_dataset", "natmcp_lint"))
})

test_that("natmcp_tools selects by group name and warns on unknown", {
  sel <- natmcp_tools(tools = c("signature", "lint"))
  expect_setequal(vapply(sel, function(t) t@name, character(1)),
                  c("natmcp_signature", "natmcp_lint"))
  expect_warning(natmcp_tools(tools = c("guide", "nope")), "nope")
})

test_that("tools invoke against a bound index", {
  od <- build_test_index()
  tl <- natmcp_tools(index = od)

  sig <- tool_named(tl, "natmcp_signature")
  expect_identical(sig(symbol = "jsonlite::fromJSON")$id, "jsonlite::fromJSON")

  guide <- tool_named(tl, "natmcp_guide")
  expect_true("flywire" %in% guide()$datasets)

  dataset <- tool_named(tl, "natmcp_dataset")
  expect_identical(dataset(name = "flywire")$id, "flywire")

  lint <- tool_named(tl, "natmcp_lint")
  expect_false(lint(code = "jsonlite::no_such_fn(1)")$ok)
})
