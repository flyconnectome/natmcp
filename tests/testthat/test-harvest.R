test_that(".tokenize and .first_sentence behave", {
  expect_setequal(.tokenize("Find partner NEURONS!"),
                  c("find", "partner", "neurons"))
  expect_identical(.first_sentence("Do a thing. And more."), "Do a thing.")
  expect_true(is.na(.first_sentence(NA_character_)))
})

test_that(".tag_snippet resolves called functions against the index", {
  ni <- list(fromJSON = "jsonlite::fromJSON", toJSON = "jsonlite::toJSON")
  sn <- list(code = "x <- fromJSON(txt)\ntoJSON(x)\nunknownfn(1)",
             source_ref = "jsonlite", functions = character(0),
             packages = character(0))
  out <- .tag_snippet(sn, ni)
  expect_setequal(out$functions, c("jsonlite::fromJSON", "jsonlite::toJSON"))
  expect_identical(out$packages, "jsonlite")
})

test_that(".tag_snippet prefers the snippet's own package when ambiguous", {
  ni <- list(plot3d = c("rgl::plot3d", "nat::plot3d"))
  sn <- list(code = "plot3d(x)", source_ref = "nat",
             functions = character(0), packages = character(0))
  out <- .tag_snippet(sn, ni)
  expect_identical(out$functions, "nat::plot3d")
})

test_that(".score_find ranks by term overlap and filters by package", {
  fdoc <- list(
    list(ref = "a::f", kind = "function", package = "a", name = "f",
         text = "convert json to a data frame"),
    list(ref = "b::g", kind = "function", package = "b", name = "g",
         text = "plot neurons in 3d")
  )
  s <- .score_find(fdoc, "json data frame")
  expect_identical(s[[1]]$ref, "a::f")
  s2 <- .score_find(fdoc, "json data frame", package = "b")
  expect_length(s2, 0)
})

test_that("build_index harvests snippets and a find_doc", {
  od <- build_test_index()
  idx <- .load_index(od)
  expect_gt(idx$manifest$n_snippets, 0)
  expect_gt(length(idx$find_doc), idx$manifest$n_signatures)  # +snippets
  expect_true(any(vapply(idx$find_doc, function(d) d$kind == "snippet",
                         logical(1))))
})

test_that("tool_find returns candidate functions and a snippet", {
  od <- build_test_index()
  res <- tool_find("convert json text to r objects", index = od)
  ids <- vapply(res$candidates, function(c) c$id, character(1))
  expect_true("jsonlite::fromJSON" %in% ids)
  expect_true(!is.null(res$snippet$code))
})

test_that("tool_find can restrict to a package", {
  od <- build_test_index()
  res <- tool_find("json", index = od, package = "jsonlite")
  pkgs <- unique(sub("::.*$", "", vapply(res$candidates,
                                         function(c) c$id, character(1))))
  expect_true(all(pkgs == "jsonlite") || length(pkgs) == 0)
})

test_that("tool_snippet fetches by id, by task, and reports not-found", {
  od <- build_test_index()
  byid <- tool_snippet(id = "jsonlite::fromJSON#example", index = od)
  expect_identical(byid$id, "jsonlite::fromJSON#example")
  expect_true(nzchar(byid$code))

  bytask <- tool_snippet(task = "parse json into a data frame", index = od)
  expect_true(!is.null(bytask$code) || identical(bytask$error, "no-snippet"))

  missing <- tool_snippet(id = "jsonlite::nope#example", index = od)
  expect_identical(missing$error, "not-found")

  expect_error(tool_snippet(index = od), "task.*id|id.*task")
})
