context("get_peak_chromatograms")

test_that("test_extractXIC_group", {
  mzmlName <- file.path(system.file("extdata", package = "DIAlignR"), "xics", "hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt.chrom.mzML")
  mz <- mzR::openMSfile(filename = mzmlName, backend = "pwiz")
  chromIndices <- c(37L, 38L, 39L, 40L, 41L, 42L)
  outData <- extractXIC_group(mz, chromIndices)
  rm(mz)
  data(XIC_QFNNTDIVLLEDFQK_3_DIAlignR, package="DIAlignR")
  XICs <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR[["hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]]
  expect_identical(length(outData), 6L)
  expect_equal(outData[[2]][,1], XICs[[2]][,1], tolerance = 1e-04)
  expect_equal(outData[[1]][,2], XICs[[1]][,2], tolerance = 1e-04)
})

test_that("test_extractXIC_group2", {
  sqName <- file.path(system.file("extdata", package = "DIAlignR"), "xics", "hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt.chrom.sqMass")
  con <- DBI::dbConnect(RSQLite::SQLite(), dbname = sqName)
  chromIndices <- c(36L, 37L, 38L, 39L, 40L, 41L)
  outData <- extractXIC_group2(con, chromIndices)
  DBI::dbDisconnect(con)
  data(XIC_QFNNTDIVLLEDFQK_3_DIAlignR, package="DIAlignR")
  XICs <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR[["hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]]
  expect_identical(length(outData), 6L)
  expect_equal(outData[[2]][,1], XICs[[2]][,1], tolerance = 1e-04)
  expect_equal(outData[[1]][,2], XICs[[1]][,2], tolerance = 1e-04)
})

test_that("test_getXICs4AlignObj", {
  dataPath <- system.file("extdata", package = "DIAlignR")
  runs <- c("run1" = "hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt",
            "run0" =  "hroest_K120808_Strep10%PlasmaBiolRepl1_R03_SW_filt")
  analytes <- c(32L, 898L, 4618L)
  params <- paramsDIAlignR()
  params[["chromFile"]] <- "mzML"

  fileInfo <- getRunNames(dataPath, oswMerged = TRUE, params)
  precursors <- getPrecursorByID(analytes,fileInfo)
  mzPntrs <- getMZMLpointers(fileInfo)
  prec2chromIndex <- getChromatogramIndices(fileInfo, precursors, mzPntrs)
  expect_warning(outData <- getXICs4AlignObj(mzPntrs, fileInfo, runs, prec2chromIndex, analytes))
  rm(mzPntrs)

  data(XIC_QFNNTDIVLLEDFQK_3_DIAlignR, package="DIAlignR")
  XICs <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR
  expect_identical(names(outData), c("hroest_K120808_Strep10%PlasmaBiolRepl1_R03_SW_filt","hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt"))
  expect_identical(names(outData[["hroest_K120808_Strep10%PlasmaBiolRepl1_R03_SW_filt"]]), c("32", "898", "4618"))
  expect_equal(outData[["hroest_K120808_Strep10%PlasmaBiolRepl1_R03_SW_filt"]][["4618"]], lapply(XICs[[runs[["run0"]]]][["4618"]], as.matrix), tolerance = 1e-03)
  expect_equal(outData[["hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]], lapply(XICs[[runs[["run1"]]]][["4618"]], as.matrix), tolerance = 1e-03)

  expect_equal(outData[["hroest_K120808_Strep10%PlasmaBiolRepl1_R03_SW_filt"]][["32"]], NULL, tolerance = 1e-03)
  expect_equal(outData[["hroest_K120808_Strep10%PlasmaBiolRepl1_R03_SW_filt"]][["898"]], NULL, tolerance = 1e-03)
  expect_equal(outData[["hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt"]][["32"]], NULL, tolerance = 1e-03)
  expect_equal(outData[["hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt"]][["898"]], NULL, tolerance = 1e-03)

})

test_that("test_getXICs", {
  dataPath <- system.file("extdata", package = "DIAlignR")
  runs <- c("run0" = "hroest_K120808_Strep10%PlasmaBiolRepl1_R03_SW_filt",
            "run2" = "hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt")
  params <- paramsDIAlignR()
  params[["chromFile"]] <- "mzML"
  outData <- getXICs(analytes = 4618L, runs = runs, dataPath = dataPath,
          maxFdrQuery = 1.0, runType = "DIA_Proteomics", oswMerged = TRUE, params)
  data(XIC_QFNNTDIVLLEDFQK_3_DIAlignR, package="DIAlignR")
  XICs <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR
  expect_equal(outData[["hroest_K120808_Strep10%PlasmaBiolRepl1_R03_SW_filt"]][["4618"]],
               lapply(XICs[["hroest_K120808_Strep10%PlasmaBiolRepl1_R03_SW_filt"]][["4618"]], as.matrix), tolerance = 1e-03)
  expect_equal(outData[["hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]],
               lapply(XICs[["hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]], as.matrix), tolerance = 1e-03)
})
