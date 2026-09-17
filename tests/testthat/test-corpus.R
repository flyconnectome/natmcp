test_that("nv_datasets ships as a documented package dataset", {
  df <- .load_datasets()
  expect_s3_class(df, "data.frame")
  expect_true(all(c("id", "organism", "id_type", "auth", "quirks") %in%
                    names(df)))
  expect_true("flywire" %in% df$id)
})

test_that(".datasets_records keys rows by id", {
  df <- .load_datasets()
  recs <- .datasets_records(df)
  expect_setequal(names(recs), df$id)
  expect_identical(recs[["flywire"]]$id, "flywire")
})

test_that(".package_roles seeds a title per installed package", {
  roles <- .package_roles(c("jsonlite", "not_a_real_pkg_xyz"))
  expect_true(nzchar(roles[["jsonlite"]]))
  expect_null(roles[["not_a_real_pkg_xyz"]])
})

test_that("build_index folds in guide, datasets and package roles", {
  od <- build_test_index()
  idx <- .load_index(od)
  expect_identical(idx$manifest$schema_version, "4")
  expect_gt(idx$manifest$n_datasets, 0)
  expect_true(!is.na(idx$guide) && nzchar(idx$guide))
  ok <- Filter(function(p) identical(p$status, "ok"), idx$manifest$packages)
  expect_true(!is.null(ok[[1]]$role))
})

test_that("tool_guide returns altitude map + rosters", {
  od <- build_test_index()
  g <- tool_guide(index = od)
  expect_true(nzchar(g$guide))
  expect_true("jsonlite" %in% vapply(g$packages, function(p) p$package,
                                     character(1)))
  expect_true("flywire" %in% g$datasets)
})

test_that("tool_dataset looks up by id case-insensitively", {
  od <- build_test_index()
  d <- tool_dataset("FlyWire", index = od)
  expect_identical(d$id, "flywire")
  expect_true(nzchar(d$quirks))
})

test_that("tool_dataset reports available names when unmatched", {
  od <- build_test_index()
  res <- tool_dataset("does-not-exist", index = od)
  expect_identical(res$error, "not-found")
  expect_true("flywire" %in% res$available)
})
