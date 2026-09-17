# Build a small offline index from one installed package for use in tests.
# jsonlite is a hard dependency, so it is always present and stable.
build_test_index <- function(pkg = "jsonlite", shapes = FALSE) {
  cfg <- list(
    classification = list(package_marker = "DESCRIPTION",
                          non_package_coverage = "corpus-only"),
    tier_A_core = list(pkg), adjacent = list(), exclude = list("base")
  )
  tc <- tempfile(fileext = ".yml")
  yaml::write_yaml(cfg, tc)
  od <- tempfile()
  suppressMessages(build_index(config = tc, out_dir = od, scope = "offline",
                               shapes = shapes))
  od
}
