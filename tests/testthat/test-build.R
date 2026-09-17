# jsonlite is a hard dependency, so it is always installed in the test env and
# gives us a small, stable package to introspect offline.

test_that("resolve_packages expands core + adjacent and honours exclude", {
  cfg <- list(
    tier_A_core = list("nat", "fafbseg", "dplyr"),
    adjacent = list(igraph = list(coverage = "allowlist",
                                  functions = list("degree", "V"))),
    exclude = list("dplyr")
  )
  targets <- resolve_packages(cfg)
  pkgs <- vapply(targets, function(t) t$package, character(1))
  expect_setequal(pkgs, c("nat", "fafbseg", "igraph"))
  ig <- Filter(function(t) t$package == "igraph", targets)[[1]]
  expect_identical(ig$coverage, "allowlist")
  expect_setequal(ig$allowlist, c("degree", "V"))
})

test_that(".formals_records captures defaults, missing args and dots", {
  f <- function(x, y = 1, z = c("a", "b"), ...) NULL
  fr <- .formals_records(f)
  args <- vapply(fr, function(r) r$arg, character(1))
  expect_identical(args, c("x", "y", "z", "..."))
  byarg <- stats::setNames(fr, args)
  expect_true(is.na(byarg[["x"]]$default))       # no default
  expect_identical(byarg[["y"]]$default, "1")
  expect_true(grepl("a", byarg[["z"]]$default))
})

test_that(".detect_lifecycle flags deprecated/defunct bodies", {
  dep <- function(x) {
    .Deprecated("newfn")
    x
  }
  def <- function(x) .Defunct("newfn")
  ok <- function(x) x
  expect_identical(.detect_lifecycle(dep), "deprecated")
  expect_identical(.detect_lifecycle(def), "defunct")
  expect_identical(.detect_lifecycle(ok), "stable")
})

test_that("extract_signatures introspects a real package", {
  recs <- extract_signatures("jsonlite", coverage = "full")
  expect_gt(length(recs), 0)
  fj <- recs[["jsonlite::fromJSON"]]
  expect_identical(fj$package, "jsonlite")
  expect_identical(fj$name, "fromJSON")
  expect_true("txt" %in% vapply(fj$formals, function(f) f$arg, character(1)))
  expect_true(is.character(fj$usage) && nzchar(fj$usage))
  expect_false(is.na(fj$description))       # gloss/description came from Rd
})

test_that("allowlist coverage restricts to named functions", {
  recs <- extract_signatures("jsonlite", coverage = "allowlist",
                             allowlist = c("fromJSON", "toJSON", "not_a_fn"))
  expect_setequal(names(recs), c("jsonlite::fromJSON", "jsonlite::toJSON"))
})

test_that("build_index writes a loadable index + manifest", {
  cfg <- list(
    classification = list(package_marker = "DESCRIPTION",
                          non_package_coverage = "corpus-only"),
    tier_A_core = list("jsonlite"), adjacent = list(), exclude = list("base")
  )
  tc <- tempfile(fileext = ".yml")
  yaml::write_yaml(cfg, tc)
  od <- tempfile()
  out <- suppressMessages(build_index(config = tc, out_dir = od,
                                      scope = "offline"))
  expect_identical(out, od)
  expect_true(file.exists(file.path(od, "index.rds")))
  expect_true(file.exists(file.path(od, "manifest.json")))

  idx <- .load_index(od)
  expect_identical(idx$manifest$scope, "offline")
  expect_identical(idx$manifest$schema_version, .schema_version)
  expect_gt(idx$manifest$n_signatures, 0)
  expect_true("jsonlite::fromJSON" %in% names(idx$signatures))
  expect_true("jsonlite" %in% .indexed_packages(idx))
})

test_that("build_index rejects the online scope for now", {
  expect_error(build_index(scope = "online"), "online")
})
