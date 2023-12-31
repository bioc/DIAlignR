context("Rmain.cpp")

test_that("test_getSeqSimMatCpp",{
  seq1 <- "GCAT"
  seq2 <- "CAGTG"
  outData <- getSeqSimMatCpp(seq1, seq2, match = 10, misMatch = -2)
  expData <- matrix(c(-2, 10, -2, -2, -2, -2, 10, -2, 10, -2, -2,
                      -2, -2, -2, -2, 10, 10, -2, -2, -2), 4, 5, byrow = FALSE)
  expect_equal(outData, expData)
})

test_that("test_getChromSimMatCpp",{
  r1 <- list(c(1.0,3.0,2.0,4.0), c(0.0,0.0,0.0,1.0), c(4.0,4.0,4.0,5.0))
  r2 <- list(c(1.4,2.0,1.5,4.0), c(0.0,0.5,0.0,0.0), c(2.0,3.0,4.0,0.9))
  outData <- round(getChromSimMatCpp(r1, r2, "L2", "dotProductMasked"), 3)
  expData <- matrix(c(0.125, 0.162, 0.144, 0.208, 0.186, 0.240,0.213, 0.313, 0.233,
           0.273, 0.253, 0.346, 0.101, 0.208, 0.154, 0.273), 4, 4, byrow = FALSE)
  expect_equal(outData, expData)

  outData <- round(getChromSimMatCpp(r1, r2, "L2", "dotProduct"), 3)
  expData <- matrix(c(0.125, 0.162, 0.144, 0.208, 0.186,0.240, 0.213, 0.313,
                      0.233, 0.273, 0.253, 0.346, 0.101, 0.208, 0.154, 0.273), 4, 4, byrow = FALSE)
  expect_equal(outData, expData)

  outData <- round(getChromSimMatCpp(r1, r2, "L2", "cosineAngle"), 3)
  expData <- matrix(c(0.934, 0.999, 0.989, 0.986, 0.933, 0.989, 0.983, 0.996,
                      0.994, 0.960, 0.995, 0.939, 0.450, 0.761, 0.633, 0.772), 4, 4, byrow = FALSE)
  expect_equal(outData, expData)

  outData <- round(getChromSimMatCpp(r1, r2, "L2", "cosine2Angle"), 3)
  expData <- matrix(c(0.744, 0.998, 0.957, 0.944, 0.740, 0.956, 0.932, 0.985,
                      0.974, 0.842, 0.978, 0.764, -0.596, 0.158, -0.200, 0.190), 4, 4, byrow = FALSE)

  outData <- round(getChromSimMatCpp(r1, r2, "mean", "euclideanDist"), 3)
  expData <- matrix(c(0.608, 0.614, 0.680, 0.434, 0.530, 0.742, 0.659, 0.641,
                      0.520, 0.541, 0.563, 0.511, 0.298,0.375, 0.334, 0.355), 4, 4, byrow = FALSE)
  expect_equal(outData, expData)

  outData <- round(getChromSimMatCpp(r1, r2, "L2", "covariance"), 3)
  expData <- matrix(c(0.025, 0.028, 0.027, 0.028, 0.032, 0.034, 0.033, 0.034,
                      0.055, 0.051, 0.053, 0.051, -0.004, 0.028, 0.012, 0.028), 4, 4, byrow = FALSE)
  expect_equal(outData, expData)

  outData <- round(getChromSimMatCpp(r1, r2, "L2", "correlation"), 3)
  expData <- matrix(c(0.874, 0.999, 0.974, 0.999, 0.923, 0.986, 0.993, 0.986, 0.991, 0.911,
         0.990, 0.911, -0.065, 0.477, 0.214, 0.477), 4, 4, byrow = FALSE)
  expect_equal(outData, expData)
})

test_that("test_getGlobalAlignMaskCpp",{
  tA <- c(1707.6, 1711, 1714.5, 1717.9, 1721.3, 1724.7, 1728.1, 1731.5, 1734.9, 1738.4)
  tB <- c(1765.7, 1769.1, 1772.5, 1775.9, 1779.3, 1782.7, 1786.2, 1789.6, 1793, 1796.4)
  tBp <- c(1786.9, 1790.35, 1793.9, 1797.36, 1800.81, 1804.26, 1807.71, 1811.17, 1814.62, 1818.17)
  noBeef <- 1
  mask <- getGlobalAlignMaskCpp(tA, tB, tBp, noBeef, FALSE)
  outData <- round(mask, 3)
  expData <- matrix(c(5.215,4.218,3.221,2.225,1.228,0,0,0,0.788, 1.785,
           6.226,5.230,4.233,3.236,2.239,1.243,0,0,0, 0.774), nrow = 2, ncol = 10, byrow = TRUE)
  expect_equal(outData[1:2,], expData)
  expect_equal(sum(mask), 549.5987)
})

test_that("test_constrainSimCpp",{
  sim <- matrix(c(-2, 10, -2, -2, -2, -2, 10, -2, 10, -2, -2, -2, -2,
                  -2, -2, 10, 10, -2,-2, -2), 4, 5, byrow = FALSE)
  MASK <- matrix(c(0.000, 0.000, 0.707, 1.414, 0.000, 0.000, 0.000, 0.707, 0.707,
                   0.000, 0.000, 0.000, 1.414, 0.707, 0, 0, 2.121, 1.414, 0, 0), 4, 5, byrow = FALSE)
  outData <- constrainSimCpp(sim, MASK, 10)
  expData <-matrix(c(-2, 10, -3.414, -4.828, -2, -2, 10, -3.414, 8.586, -2, -2, -2, -4.828,
            -3.414, -2, 10, 5.758, -4.828, -2, -2), 4, 5, byrow = FALSE)
  expect_equal(outData, expData)
})

test_that("test_getBaseGapPenaltyCpp",{
  sim <- matrix(c(-12, 1.0, 12, -2.3, -2, -2, 1.07, -2, 1.80,
                  2, 22, 42, -2, -1.5, -2, 10), 4, 4, byrow = FALSE)
  expect_equal(getBaseGapPenaltyCpp(sim, "dotProductMasked", 0.5), 0.01)
})

test_that("test_sgolayCpp",{
  data(XIC_QFNNTDIVLLEDFQK_3_DIAlignR, package="DIAlignR")
  XICs <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR[["hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]]
  outData <- sgolayCpp(as.matrix(XICs[[1]]), kernelLen = 11L, polyOrd = 4L)
  expData <- signal::sgolayfilt(XICs[[1]][,2], n = 11L, p = 4L)
  expData[expData<0] <- 0
  expect_equal(outData[,1], XICs[[1]][,1])
  expect_equal(outData[,2], expData, tolerance = 1e-03)

  outData <- sgolayCpp(as.matrix(XICs[[1]]), kernelLen = 9L, polyOrd = 3L)
  expData <- signal::sgolayfilt(XICs[[1]][,2], n = 9L, p = 3L)
  expData[expData<0] <- 0
  expect_equal(outData[,2], expData, tolerance = 1e-03)

  outData <- sgolayCpp(as.matrix(XICs[[1]]), kernelLen = 7L, polyOrd = 4L)
  expData <- signal::sgolayfilt(XICs[[1]][,2], n = 7L, p = 4L)
  expData[expData<0] <- 0
  expect_equal(outData[,2], expData, tolerance = 1e-03)
})

test_that("test_getAlignedTimesCpp",{
  data(XIC_QFNNTDIVLLEDFQK_3_DIAlignR, package="DIAlignR")
  data(oswFiles_DIAlignR, package="DIAlignR")
  run1 <- "hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt"
  run2 <- "hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt"
  XICs.ref <- lapply(XIC_QFNNTDIVLLEDFQK_3_DIAlignR[[run1]][["4618"]], as.matrix)
  XICs.eXp <- lapply(XIC_QFNNTDIVLLEDFQK_3_DIAlignR[[run2]][["4618"]], as.matrix)
  RUNS_RT <- getRTdf(oswFiles_DIAlignR, ref = "run2", eXp = "run0", maxFdrGlobal = 0.05)
  globalFit <- getLOESSfit(RUNS_RT, spanvalue = 0.1)
  tVec.ref <- XICs.ref[[1]][, "time"] # Extracting time component
  tVec.eXp <- XICs.eXp[[1]][, "time"] # Extracting time component
  len <- length(tVec.ref)
  lfun <- stats::approxfun(globalFit)
  Bp <- lfun(tVec.ref)
  outData <- getAlignedTimesCpp(XICs.ref, XICs.eXp, kernelLen = 0L, polyOrd = 4L, alignType = "hybrid",
                  adaptiveRT = 77.82315, normalization = "mean", simType = "dotProductMasked", Bp = Bp,
                  goFactor = 0.125, geFactor = 40, cosAngleThresh = 0.3, OverlapAlignment = TRUE,
                  dotProdThresh = 0.96, gapQuantile = 0.5, kerLen = 9, hardConstrain = FALSE, samples4gradient = 100)

  expect_equal(outData[1:3,1], c(4978.4, 4981.8, 4985.2), tolerance = 1e-03)
  expect_equal(outData[1:3,2], c(NA_real_, NA_real_, NA_real_), tolerance = 1e-03)
  expect_equal(outData[17:19,2], c(NA_real_, NA_real_, 4988.60), tolerance = 1e-03)
  expect_equal(outData[174:176,1], c(5569.0, 5572.4, 5575.8), tolerance = 1e-03)
  expect_equal(outData[174:176,2], c(5572.40, 5575.80, 5582.60), tolerance = 1e-03)
  expect_identical(dim(outData), c(176L, 2L))
})

test_that("test_areaIntegrator",{
  time <- c( 2.23095,2.239716667,2.248866667,2.25765,2.266416667,
             2.275566667,2.2847,2.293833333,2.304066667,2.315033333,2.325983333,2.336566667,
             2.3468,2.357016667,2.367283333,2.377183333,2.387083333,2.39735,2.40725,2.4175,
             2.4274,2.4373,2.44755,2.45745,2.4677,2.477966667,2.488216667,2.498516667,2.5084,
             2.5183,2.5282,2.538466667,2.548366667,2.558266667,2.568516667,2.578783333,
             2.588683333,2.59895,2.6092,2.619466667,2.630066667,2.64065,2.65125,2.662116667,
             2.672716667,2.6833,2.6939,2.7045,2.715083333,2.725683333,2.736266667,2.746866667,
             2.757833333,2.768416667,2.779016667,2.789616667,2.8002,2.810116667,2.820033333,
             2.830316667,2.840216667,2.849766667,2.859316667,2.868866667,2.878783333,2.888683333,
             2.898233333,2.907783333,2.916033333,2.924266667,2.93215,2.940383333,2.947933333,
             2.955816667,2.964066667,2.97195,2.979833333,2.987716667,2.995616667,3.003516667,
             3.011416667,3.01895,3.026833333,3.034366667,3.042266667,3.0498,3.05735,3.065233333,
             3.073133333,3.080666667,3.0882,3.095733333,3.103633333,3.111533333,3.119066667,
             3.126966667,3.134866667,3.14275,3.15065,3.15855,3.166433333,3.174333333,3.182233333,
             3.190133333,3.198016667,3.205916667,3.213166667
  )

  intensity <- c(
    1447,2139,1699,755,1258,1070,944,1258,1573,1636,
    1762,1447,1133,1321,1762,1133,1447,2391,692,1636,2957,1321,1573,1196,1258,881,
    1384,2076,1133,1699,1384,692,1636,1133,1573,1825,1510,2391,4342,10382,17618,
    51093,153970,368094,632114,869730,962547,966489,845055,558746,417676,270942,
    184865,101619,59776,44863,31587,24036,20450,20324,11074,9879,10508,7928,7110,
    6733,6481,5726,6921,6670,5537,4971,4719,4782,5097,5789,4279,5411,4530,3524,
    2139,3335,3083,4342,4279,3083,3649,4216,4216,3964,2957,2202,2391,2643,3524,
    2328,2202,3649,2706,3020,3335,2580,2328,2894,3146,2769,2517
  )
  left <- 2.472833334
  right <- 3.022891666
  outData <- areaIntegrator(list(time), list(intensity), left, right, integrationType = "intensity_sum",
                                baselineType = "base_to_base", fitEMG = FALSE, baseSubtraction = TRUE)
  expect_equal(outData, 6645331.33866)

  outData <- areaIntegrator(list(time, time), list(intensity, intensity), left, right, integrationType = "trapezoid",
                                baselineType = "vertical_division_min", fitEMG = FALSE, baseSubtraction = TRUE)
  expect_equal(outData, rep(71063.59368, 2), tolerance = 0.01)

  outData <- areaIntegrator(list(time, time), list(intensity, intensity), left, right, integrationType = "trapezoid",
                            baselineType = "vertical_division_min", fitEMG = FALSE, baseSubtraction = TRUE,
                            kernelLen = 9L, polyOrd = 3L)
  expect_equal(outData, rep(70984.23, 2), tolerance = 0.01)

  outData <- areaIntegrator(list(time, time), list(intensity, intensity), right, left, integrationType = "trapezoid",
                            baselineType = "vertical_division_min", fitEMG = FALSE, baseSubtraction = TRUE)
  expect_identical(outData, NA_real_)
})

test_that("test_alignChromatogramsCpp",{
  data(XIC_QFNNTDIVLLEDFQK_3_DIAlignR, package="DIAlignR")
  XICs <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR
  data(oswFiles_DIAlignR, package="DIAlignR")
  oswFiles <- oswFiles_DIAlignR
  RUNS_RT <- getRTdf(oswFiles, ref = "run1", eXp = "run2", maxFdrGlobal = 0.05)
  Loess.fit <- getLOESSfit(RUNS_RT, spanvalue = 0.1)
  XICs.ref <- XICs[["hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]]
  XICs.ref <- smoothXICs(XICs.ref, type = "sgolay", kernelLen = 13, polyOrd = 4)
  XICs.eXp <- XICs[["hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]]
  XICs.eXp <- smoothXICs(XICs.eXp, type = "sgolay", kernelLen = 13, polyOrd = 4)
  tVec.ref <- XICs.ref[[1]][,"time"] # Extracting time component
  tVec.eXp <- XICs.eXp[[1]][,"time"] # Extracting time component
  lfun <- stats::approxfun(Loess.fit)
  B1p <- lfun(tVec.ref[1])
  B2p <- lfun(tVec.ref[length(tVec.ref)])
  noBeef <- 38.6594179136227/3.414
  l1 <- lapply(XICs.ref, `[`, i=, j =2)
  l2 <- lapply(XICs.eXp, `[`, i=, j =2)
  outData <- alignChromatogramsCpp(l1, l2, alignType = "hybrid",
                                   tA = tVec.ref, tB = tVec.eXp, normalization = "mean", simType = "dotProductMasked",
                                   B1p = B1p, B2p = B2p, noBeef = noBeef,
                         goFactor = 0.125, geFactor = 40,
                         cosAngleThresh = 0.3, OverlapAlignment = TRUE,
                         dotProdThresh = 0.96, gapQuantile = 0.5, hardConstrain = FALSE,
                         samples4gradient = 100, objType = "light")
  expData <- testAlignObj()
  expect_equal(outData, expData, tolerance = 1e-03)

  l1 <- list(rnorm(100), rnorm(101))
  l2 <- list(rnorm(100), rnorm(100))
  expect_error(alignChromatogramsCpp(l1, l2, alignType = "hybrid",
                                   tA = 1:100, tB = 1:100, normalization = "mean", simType = "dotProductMasked",
                                   B1p = 1, B2p = 90, noBeef = 10,
                                   goFactor = 0.125, geFactor = 40,
                                   cosAngleThresh = 0.3, OverlapAlignment = TRUE,
                                   dotProdThresh = 0.96, gapQuantile = 0.5, hardConstrain = FALSE,
                                   samples4gradient = 100, objType = "light"))
})

test_that("test_doAlignmentCpp",{
  s <- getSeqSimMatCpp(seq1 = "GCAT", seq2 = "CAGTG", match = 10, misMatch = -2)
  outData <- doAlignmentCpp(s, 22, FALSE)
  expData <- c(-2, -4, -6, 4, -18)
  expect_equal(outData@score, expData)
  outData <- doAlignmentCpp(s, 22, TRUE)
  expData <- c(0, 10, 20, 18, 18, 18)
  expect_equal(outData@score, expData)

  s <- getSeqSimMatCpp(seq1 = "TTTC", seq2 = "TGC", match = 1, misMatch = -1)
  outData <- doAlignmentCpp(s, 2, FALSE)
  expData <- matrix(data = c(1,1,1,1,1,1,1,1,1,2,1,2,1,
                             3,3,1,1,3,6,3), nrow = 5, ncol =4, byrow = TRUE)
  expect_equal(outData@optionalPaths, expData)
  expData <- matrix(data = c(0,-2,-4,-6,-2,-7,-22,-45,-4,-20,-72,-184,-6,-41,-178,-547,-8,-72,-366,-1274), nrow = 5, ncol =4, byrow = TRUE)
  expect_equal(outData@M_forw, expData)
})

test_that("test_doAffineAlignmentCpp",{
  Match <- 10
  MisMatch <- -2
  s <- getSeqSimMatCpp(seq1 = "GCAT", seq2=  "CAGTG", Match, MisMatch)
  outData <- doAffineAlignmentCpp(s, 22, 7, FALSE)
  expData <- c(-2, -4, -6, 4, -18)
  expect_equal(outData@score, expData)
  outData <- doAffineAlignmentCpp(s, 22, 7, TRUE)
  expData <- c(0, 10, 20, 18, 18, 18)
  expect_equal(outData@score, expData)

  s <- getSeqSimMatCpp(seq1 = "CAT", seq2 = "CAGTG", Match, MisMatch)
  outData <- doAffineAlignmentCpp(s, 22, 7, FALSE)
  expData <- c(10, 20, -2, -9, -11)
  expect_equal(outData@score, expData)
  outData <- doAffineAlignmentCpp(s, 22, 7, TRUE)
  expData <- c(10, 20, 18, 18, 18)
  expect_equal(outData@score, expData)
})

test_that("test_splineFillCpp",{
  time <- seq(from = 3003.4, to = 3048, by = 3.4)
  y <- c(0.2050595, 0.8850070, 2.2068768, 3.7212677, 5.1652605, 5.8288915, 5.5446804,
        4.5671360, 3.3213154, 1.9485889, 0.9520709, 0.3294218, 0.2009581, 0.1420923)
  y[c(1,6)] <- NA_real_
  idx <- !is.na(y)
  outData <- splineFillCpp(time[idx], y[idx], time[!idx])
  expData <- c(0.0, 5.8075496)
  expect_equal(outData, expData)
})

test_that("test_getChildXICpp", {
  data(XIC_QFNNTDIVLLEDFQK_3_DIAlignR, package="DIAlignR")
  XICs <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR
  XICs.ref <- lapply(XICs[["hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]], as.matrix)
  XICs.eXp <- lapply(XICs[["hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]], as.matrix)
  Bp <- seq(4964.752, 5565.462, length.out = nrow(XICs.ref[[1]]))
  outData <- getChildXICpp(XICs.ref, XICs.eXp, 0, 4, alignType = "hybrid", adaptiveRT = 77.82315,
                         normalization = "mean", simType = "dotProductMasked", Bp = Bp,
                         goFactor = 0.125, geFactor = 40, cosAngleThresh = 0.3, OverlapAlignment = TRUE,
                         dotProdThresh = 0.96, gapQuantile = 0.5, hardConstrain = FALSE, samples4gradient = 100,
                         wRef = 0.5, keepFlanks= TRUE, splineMethod = "natural", mergeStrategy = "avg")
  expect_identical(length(outData), 2L)
  expect_identical(dim(outData[[1]][[6]]), c(177L, 2L))

  data(masterXICs_DIAlignR, package="DIAlignR")
  expData <- masterXICs_DIAlignR
  for(i in 1:3) expect_equal(outData[[2]][,i], expData[[2]][, i+2])
  for(i in 1:6) expect_equal(outData[[1]][[i]][,1], expData[[1]][[i]][,1])
  for(i in 1:6) expect_equal(outData[[1]][[i]][,2], expData[[1]][[i]][,2])
})

test_that("test_otherChildXICpp", {
  data(XIC_QFNNTDIVLLEDFQK_3_DIAlignR, package="DIAlignR")
  XICs <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR
  XICs.ref <- lapply(XICs[["hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]], as.matrix)
  XICs.eXp <- lapply(XICs[["hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]], as.matrix)
  data(masterXICs_DIAlignR, package="DIAlignR")
  expData <- masterXICs_DIAlignR
  outData <- otherChildXICpp(XICs.ref, XICs.eXp, 0L, 4L, as.matrix(expData[[2]][, 3:5]),
                  expData[[1]][[1]][,1], wRef = 0.5, splineMethod = "natural")
  for(i in 1:6) expect_equal(outData[[i]][,1], expData[[1]][[i]][,1])
  for(i in 1:6) expect_equal(outData[[i]][,2], expData[[1]][[i]][,2])
})
