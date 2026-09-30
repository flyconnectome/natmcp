test_that("loading natmcp does not load mcptools", {
  # .pin_socket_dir() relies on mcptools loading lazily (via ::) after it.
  ns <- readLines(system.file("NAMESPACE", package = "natmcp"))
  expect_false(any(grepl("mcptools", ns)))
})

test_that(".pin_socket_dir sets the dir only when it is unset and in time", {
  old <- Sys.getenv("MCPTOOLS_SOCKET_DIR", unset = NA)
  on.exit(if (is.na(old)) Sys.unsetenv("MCPTOOLS_SOCKET_DIR") else
    Sys.setenv(MCPTOOLS_SOCKET_DIR = old), add = TRUE)

  Sys.unsetenv("MCPTOOLS_SOCKET_DIR")
  expect_identical(.pin_socket_dir(NULL, loaded = FALSE), "default")
  expect_identical(.pin_socket_dir("/x/mcptools", loaded = TRUE), "late")
  expect_identical(Sys.getenv("MCPTOOLS_SOCKET_DIR"), "")
  expect_identical(.pin_socket_dir("/x/mcptools", loaded = FALSE), "pinned")
  expect_identical(Sys.getenv("MCPTOOLS_SOCKET_DIR"), "/x/mcptools")
  expect_identical(.pin_socket_dir("/y/mcptools", loaded = FALSE), "user")
  expect_identical(Sys.getenv("MCPTOOLS_SOCKET_DIR"), "/x/mcptools")
})

test_that(".warn_socket_mismatch warns only on a real mismatch", {
  expect_silent(.warn_socket_mismatch(NULL, "/a/mcptools"))
  expect_silent(.warn_socket_mismatch("/a/T//mcptools/", "/a/T/mcptools"))
  expect_warning(.warn_socket_mismatch("/tmp/Rtmp1/mcptools", "/a/T/mcptools"),
                 "MCPTOOLS_SOCKET_DIR")
})

test_that(".canonical_socket_dir is the per-user temp dir on macOS", {
  d <- .canonical_socket_dir()
  if (identical(Sys.info()[["sysname"]], "Darwin")) {
    expect_match(d, "/T/mcptools$")
  } else {
    expect_null(d)
  }
})
