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

# Mirrors mcptools:::is_structured_content_result(): a fully-named list is
# emitted as JSON (structuredContent + JSON text) on MCP protocol >= 2025-06-18.
# If a handler returns an atomic/unnamed value it silently degrades to the
# newline-joined "free text" fallback, so guard every tool's return shape.
fully_named_list <- function(x) {
  is.list(x) && !is.null(names(x)) &&
    length(names(x)) == length(x) && all(nzchar(names(x)))
}

test_that("every tool returns a JSON-serialisable named list", {
  od <- build_test_index()
  tl <- natmcp_tools(index = od)
  results <- list(
    guide     = tool_named(tl, "natmcp_guide")(),
    find      = tool_named(tl, "natmcp_find")(task = "parse json"),
    signature = tool_named(tl, "natmcp_signature")(symbol = "jsonlite::fromJSON"),
    dataset   = tool_named(tl, "natmcp_dataset")(name = "flywire"),
    lint      = tool_named(tl, "natmcp_lint")(code = "jsonlite::fromJSON(x)")
  )
  for (nm in names(results)) {
    expect_true(fully_named_list(results[[nm]]),
                info = sprintf("tool %s must return a fully-named list", nm))
  }
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
