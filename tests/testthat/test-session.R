test_that("natmcp_run_r refuses unless the session opted in", {
  skip_if_not_installed("evaluate")
  tool <- .run_r_tool()
  expect_identical(tool@name, "natmcp_run_r")
  old <- options(natmcp.run_r = NULL)
  on.exit(options(old), add = TRUE)
  expect_error(tool(code = "1 + 1"), "natmcp_session\\(run_r = TRUE\\)")
  options(natmcp.run_r = TRUE)
  res <- tool(code = "1 + 1")
  expect_true(inherits(res, "ellmer::ContentToolResult"))
})

test_that("natmcp_session sets the run_r option and registers once", {
  skip_if_not_installed("evaluate")
  n <- 0
  local_mocked_bindings(.start_mcp_session = function() n <<- n + 1,
                        .pin_socket_dir = function() "pinned")
  old_state <- .natmcp_state$session
  .natmcp_state$session <- NULL
  old <- options(natmcp.run_r = NULL)
  on.exit({
    options(old)
    .natmcp_state$session <- old_state
  }, add = TRUE)
  suppressMessages(natmcp_session(run_r = TRUE))
  expect_true(getOption("natmcp.run_r"))
  suppressMessages(natmcp_session())
  expect_false(getOption("natmcp.run_r"))
  expect_equal(n, 1)
})
