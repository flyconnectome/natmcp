test_that("sitrep reports config, index and socket state", {
  d <- tempfile()
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  code <- file.path(d, ".claude.json")
  writeLines('{"mcpServers": {"other": {"command": "x", "env": {"TOKEN": "s3cret"}},
    "natmcp": {"command": "/no/Rscript", "args": ["-e", "natmcp::natmcp_mcp_server()"],
    "env": {"MCPTOOLS_SOCKET_DIR": "/a/T/mcptools"}}}}', code)
  local_mocked_bindings(
    .claude_desktop_config_path = function() NULL,
    .claude_code_config_path = function() code,
    .canonical_socket_dir = function() "/a/T/mcptools",
    .socket_dir_in_use = function() "/tmp/Rtmp1/mcptools",
    .pin_socket_dir = function(...) "late")
  x <- .sitrep(sessions = FALSE)
  expect_s3_class(x, "natmcp_sitrep")
  expect_false(x$socket_dir_ok)
  txt <- format(x)
  expect_true(any(grepl("MISMATCH", txt)))
  expect_true(any(grepl("command not found", txt)))
  expect_true(any(grepl("MCPTOOLS_SOCKET_DIR = /a/T/mcptools", txt, fixed = TRUE)))
  expect_true(any(grepl("not available on this OS", txt)))
  expect_false(any(grepl("s3cret", txt)))
  expect_false(any(grepl("R sessions visible", txt)))
})

test_that(".sitrep_config handles missing files and entries", {
  expect_match(.sitrep_config(tempfile(), "Rscript"), "file not found")
  f <- tempfile(fileext = ".json")
  on.exit(unlink(f), add = TRUE)
  writeLines("{}", f)
  expect_match(.sitrep_config(f, "Rscript"), "no natmcp entry")
})

test_that("the server offers the natmcp_sitrep tool", {
  tool <- .sitrep_tool()
  expect_identical(tool@name, "natmcp_sitrep")
})
