test_that("timezone_out works with default", {
  con <- dbConnect(duckdb())
  on.exit(dbDisconnect(con, shutdown = TRUE))

  query <- "SELECT '1970-01-01 12:00:00'::TIMESTAMP AS ts"
  res <- dbGetQuery(con, query)
  expect_equal(res[[1]], as.POSIXct("1970-01-01 12:00:00", tz = "UTC"))
})

test_that("timezone_out works with UTC specified", {
  con <- dbConnect(duckdb(), timezone_out = "UTC")
  on.exit(dbDisconnect(con, shutdown = TRUE))

  query <- "SELECT '1970-01-01 12:00:00'::TIMESTAMP AS ts"
  res <- dbGetQuery(con, query)
  expect_equal(res[[1]], as.POSIXct("1970-01-01 12:00:00", tz = "UTC"))
})

test_that("timezone_out works with a specified timezone", {
  con <- dbConnect(duckdb(), timezone_out = "Pacific/Tahiti")
  on.exit(dbDisconnect(con, shutdown = TRUE))

  query <- "SELECT '1970-01-01 12:00:00'::TIMESTAMP AS ts"
  res <- dbGetQuery(con, query)
  expect_equal(res[[1]], as.POSIXct("1970-01-01 02:00:00", tz = "Pacific/Tahiti"))
})

test_that("timezone_out works with '' and converts to local timezime", {
  unlockBinding(".sys.timezone", baseenv())
  withr::local_timezone("Pacific/Tahiti")
  con <- dbConnect(duckdb(), timezone_out = "")
  on.exit(dbDisconnect(con, shutdown = TRUE))

  query <- "SELECT '1970-01-01 12:00:00'::TIMESTAMP AS ts"
  res <- dbGetQuery(con, query)
  expect_equal(res[[1]], as.POSIXct("1970-01-01 02:00:00", tz = "Pacific/Tahiti"))
})

test_that("timezone_out works with Sys.timezone", {
  unlockBinding(".sys.timezone", baseenv())
  withr::local_timezone("Pacific/Tahiti")
  con <- dbConnect(duckdb(), timezone_out = Sys.timezone())
  on.exit(dbDisconnect(con, shutdown = TRUE))

  query <- "SELECT '1970-01-01 12:00:00'::TIMESTAMP AS ts"
  res <- dbGetQuery(con, query)
  expect_equal(res[[1]], as.POSIXct("1970-01-01 02:00:00", tz = "Pacific/Tahiti"))
})

test_that("timezone_out works with UTC and tz_out_convert = 'force'", {
  con <- dbConnect(duckdb(), timezone_out = "UTC", tz_out_convert = "force")
  on.exit(dbDisconnect(con, shutdown = TRUE))

  query <- "SELECT '1970-01-01 12:00:00'::TIMESTAMP AS ts"
  res <- dbGetQuery(con, query)
  expect_equal(res[[1]], as.POSIXct("1970-01-01 12:00:00", tz = "UTC"))
})

test_that("timezone_out works with a specified timezone and tz_out_convert = 'force'", {
  con <- dbConnect(duckdb(), timezone_out = "Pacific/Tahiti", tz_out_convert = "force")
  on.exit(dbDisconnect(con, shutdown = TRUE))

  query <- "SELECT '1970-01-01 12:00:00'::TIMESTAMP AS ts"
  res <- dbGetQuery(con, query)
  expect_equal(res[[1]], as.POSIXct("1970-01-01 12:00:00", tz = "Pacific/Tahiti"))
})

test_that("timezone_out works with '' and tz_out_convert = 'force': forces local timezime", {
  unlockBinding(".sys.timezone", baseenv())
  withr::local_timezone("Pacific/Tahiti")
  con <- dbConnect(duckdb(), timezone_out = "", tz_out_convert = "force")
  on.exit(dbDisconnect(con, shutdown = TRUE))

  query <- "SELECT '1970-01-01 12:00:00'::TIMESTAMP AS ts"
  res <- dbGetQuery(con, query)
  expect_equal(res[[1]], as.POSIXct("1970-01-01 12:00:00", tz = "Pacific/Tahiti"))
})

test_that("timezone_out works with a specified local timezone and tz_out_convert = 'force': forces local timezime", {
  unlockBinding(".sys.timezone", baseenv())
  withr::local_timezone("Pacific/Tahiti")
  con <- dbConnect(duckdb(), timezone_out = Sys.timezone(), tz_out_convert = "force")
  on.exit(dbDisconnect(con, shutdown = TRUE))

  query <- "SELECT '1970-01-01 12:00:00'::TIMESTAMP AS ts"
  res <- dbGetQuery(con, query)
  expect_equal(res[[1]], as.POSIXct("1970-01-01 12:00:00", tz = "Pacific/Tahiti"))
})

test_that("timezone_out gives a warning with invalid timezone, and converts to UTC", {
  expect_warning(con <- dbConnect(duckdb(), timezone_out = "not_a_timezone"))
  on.exit(dbDisconnect(con, shutdown = TRUE))
  expect_equal(con@timezone_out, "UTC")
})

test_that("timezone_out gives a warning with NULL timezone, and converts to UTC", {
  expect_warning(con <- dbConnect(duckdb(), timezone_out = NULL))
  on.exit(dbDisconnect(con, shutdown = TRUE))
  expect_equal(con@timezone_out, "UTC")
})

test_that("dbConnect fails when tz_out_convert is misspecified", {
  drv <- duckdb()
  on.exit(duckdb_shutdown(drv))

  expect_error(dbConnect(drv, tz_out_convert = "nope"))
})

test_that("timezone_out and tz_out_convert = force with midnight times (#8547)", {
  con <- dbConnect(duckdb(), timezone_out = "Etc/GMT+8", tz_out_convert = "force")
  on.exit(dbDisconnect(con, shutdown = TRUE))

  dbExecute(
    con,
    "CREATE TABLE IF NOT EXISTS test( DATE_TIME TIMESTAMP );"
  )

  dbExecute(
    con,
    "INSERT INTO test(DATE_TIME) VALUES ('1975-01-01 00:00:00'),('1975-01-01 15:27:00');"
  )

  res <- dbGetQuery(con, "SELECT * FROM test;")
  expect_equal(res[[1]],
               as.POSIXct(c("1975-01-01 00:00:00", "1975-01-01 15:27:00"),
                          tz = "Etc/GMT+8"))
})

test_that("POSIXct with local time zone", {
  con <- dbConnect(duckdb(), timezone_out = "")
  on.exit(dbDisconnect(con))

  df1 <- data.frame(a = structure(1745781814.84963, class = c("POSIXct", "POSIXt")))
  rel <- rel_from_df(con, df1)
  expect_equal(rel_to_altrep(rel), df1)

  # With extra class
  df2 <- data.frame(a = structure(1745781814.84963, class = c("foo", "POSIXct", "POSIXt")))
  rel <- rel_from_df(con, df2, strict = FALSE)
  expect_equal(rel_to_altrep(rel), df1)

  expect_error(rel_from_df(con, df2), "convert")
})

test_that("POSIXct with local time zone and existing but empty attribute", {
  con <- dbConnect(duckdb(), timezone_out = "")
  on.exit(dbDisconnect(con))

  df1 <- data.frame(a = structure(1745781814.84963, class = c("POSIXct", "POSIXt"), tzone = ""))
  rel <- rel_from_df(con, df1)
  expect_equal(rel_to_altrep(rel), df1)

  # With extra class
  df2 <- data.frame(a = structure(1745781814.84963, class = c("foo", "POSIXct", "POSIXt"), tzone = ""))
  rel <- rel_from_df(con, df2, strict = FALSE)
  expect_equal(rel_to_altrep(rel), df1)

  expect_error(rel_from_df(con, df2), "convert")
})
