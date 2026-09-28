entry <- list(command = "/x/Rscript", args = list("-e", .server_expr))

test_that(".add_mcp_server adds natmcp and preserves the rest of the file", {
  p <- tempfile(fileext = ".json")
  writeLines('{
  "theme": "dark",
  "ratio": 0.12345678901234567,
  "empty": {},
  "list": [],
  "one": ["a"],
  "nothing": null,
  "mcpServers": {"other": {"command": "foo", "args": [], "env": {}}}
}', p)
  before <- jsonlite::read_json(p, simplifyVector = FALSE)
  expect_equal(suppressMessages(.add_mcp_server(p, entry)), "added")
  after <- jsonlite::read_json(p, simplifyVector = FALSE)
  expect_identical(after$mcpServers$natmcp$command, "/x/Rscript")
  after$mcpServers$natmcp <- NULL
  expect_identical(after, before)
  # untouched values keep their JSON types
  txt <- paste(readLines(p), collapse = "\n")
  expect_match(txt, '"empty": {}', fixed = TRUE)
  expect_match(txt, '"one": \\[\\s*"a"\\s*\\]')
  expect_match(txt, '"nothing": null', fixed = TRUE)
  expect_length(Sys.glob(paste0(p, ".natmcp-backup-*")), 1)
})

test_that(".add_mcp_server is idempotent and only replaces on request", {
  p <- tempfile(fileext = ".json")
  expect_equal(suppressMessages(.add_mcp_server(p, entry)), "added")
  expect_false(file.exists(paste0(p, ".natmcp-backup-*")))
  expect_equal(suppressMessages(.add_mcp_server(p, entry)), "unchanged")
  other <- entry
  other$command <- "/y/Rscript"
  expect_equal(suppressMessages(.add_mcp_server(p, other)), "kept")
  expect_identical(
    jsonlite::read_json(p, simplifyVector = FALSE)$mcpServers$natmcp$command,
    "/x/Rscript")
  expect_equal(suppressMessages(.add_mcp_server(p, other, overwrite = TRUE)),
               "updated")
  expect_identical(
    jsonlite::read_json(p, simplifyVector = FALSE)$mcpServers$natmcp$command,
    "/y/Rscript")
})

test_that(".add_rprofile_session appends once", {
  p <- tempfile()
  writeLines("options(foo = 1)", p)
  expect_equal(suppressMessages(.add_rprofile_session(p)), "added")
  expect_equal(suppressMessages(.add_rprofile_session(p)), "unchanged")
  lines <- readLines(p)
  expect_identical(lines[1], "options(foo = 1)")
  expect_equal(sum(grepl(.rprofile_marker, lines, fixed = TRUE)), 1)
  expect_silent(parse(p))
})

test_that("natmcp_setup configures clients non-interactively", {
  home <- tempfile()
  dir.create(home)
  desk <- file.path(home, "claude_desktop_config.json")
  code <- file.path(home, ".claude.json")
  rp <- file.path(home, ".Rprofile")
  fetched <- FALSE
  local_mocked_bindings(
    .claude_desktop_config_path = function() desk,
    .claude_code_config_path = function() code,
    .rprofile_path = function() rp,
    fetch_index = function(...) fetched <<- TRUE
  )
  res <- suppressMessages(natmcp_setup(ask = FALSE, rprofile = TRUE))
  expect_true(fetched)
  expect_identical(res$index, "fetched")
  expect_identical(res$desktop, "added")
  expect_identical(res$code, "added")
  expect_identical(res$rprofile, "added")
  d <- jsonlite::read_json(desk, simplifyVector = FALSE)$mcpServers$natmcp
  expect_identical(d$args[[2]], .server_expr)
  expect_null(d$type)
  cc <- jsonlite::read_json(code, simplifyVector = FALSE)$mcpServers$natmcp
  expect_identical(cc$type, "stdio")
  expect_identical(cc$command, .rscript_path())

  res2 <- suppressMessages(natmcp_setup(clients = "code", index = "skip",
                                        ask = FALSE))
  expect_identical(res2$code, "unchanged")
  expect_identical(res2$desktop, "skipped")
})

test_that("natmcp_setup builds into the cache and tolerates fetch failure", {
  home <- tempfile()
  dir.create(home)
  out <- NULL
  local_mocked_bindings(
    .claude_desktop_config_path = function() NULL,
    .claude_code_config_path = function() file.path(home, ".claude.json"),
    build_index = function(out_dir, ...) out <<- out_dir,
    fetch_index = function(...) stop("offline")
  )
  res <- suppressMessages(natmcp_setup(index = "build", ask = FALSE))
  expect_identical(out, tools::R_user_dir("natmcp", "cache"))
  expect_identical(res$desktop, "unavailable")
  res <- suppressMessages(natmcp_setup(index = "fetch", ask = FALSE))
  expect_identical(res$index, "failed")
})
