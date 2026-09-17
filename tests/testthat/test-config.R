test_that("packaged scrape config parses and has the expected shape", {
  cfg <- read_config()

  # orgs to enumerate
  expect_true(all(c("natverse", "flyconnectome") %in% names(cfg$orgs)))
  expect_false(cfg$orgs$flyconnectome$include_private)

  # classification rule that separates packages from corpus-only repos
  expect_identical(cfg$classification$package_marker, "DESCRIPTION")
  expect_identical(cfg$classification$non_package_coverage, "corpus-only")

  # core promoted set + adjacent allowlist tiers
  expect_true(all(c("nat", "coconatfly", "fafbseg") %in% cfg$tier_A_core))
  expect_true(all(c("rgl", "Rvcg", "Morpho", "igraph") %in% names(cfg$adjacent)))
  expect_identical(cfg$adjacent$igraph$coverage, "allowlist")
  expect_true(length(cfg$adjacent$Rvcg$functions) > 0)
})
