context("Post alignment analysis")

# mzML and osw files are not required.

test_that("test_pickNearestFeature", {
  data(oswFiles_DIAlignR, package="DIAlignR")
  oswFiles <- oswFiles_DIAlignR
  outData <- pickNearestFeature(eXpRT = 5237.8, analyte = 4618L, oswFiles,
                                runname = "run2", adaptiveRT = 77.82315,
                                featureFDR = 0.05)
  expData <- list("leftWidth" = c(5217.361),
                           "rightWidth" = c(5275.395),
                           "RT" = c(5240.79),
                           "intensity" = c(255.496),
                           "peak_group_rank" = c(1L),
                           "m_score" = c(5.692077e-05))
  expect_equal(outData, expData, tolerance = 1e-05)
})

test_that("test_mapIdxToTime", {
  timeVec <- c(1.3,5.6,7.8)
  idx <- c(NA, NA, 1L, 2L, NA, NA, 3L, NA)
  outData <- mapIdxToTime(timeVec, idx)
  expData <- c(NA, NA, 1.3, 5.6, 6.333333, 7.066667, 7.8, NA)
  expect_equal(outData, expData, tolerance = 1e-04)
})

test_that("test_mappedRTfromAlignObj", {
  AlignObj <- testAlignObj()
  data(XIC_QFNNTDIVLLEDFQK_3_DIAlignR, package="DIAlignR")
  XICs <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR
  tVec.ref <-  XICs[["hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]][[1]][, "time"]
  tVec.eXp <-  XICs[["hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]][[1]][, "time"]
  expect_equal(mappedRTfromAlignObj(refRT= 5238.35, tVec.ref, tVec.eXp, AlignObj), 5241.3)
})

test_that("test_setAlignmentRank", {
  data(multipeptide_DIAlignR, package="DIAlignR")
  data(XIC_QFNNTDIVLLEDFQK_3_DIAlignR, package="DIAlignR")
  params <- paramsDIAlignR()
  params[["baseSubtraction"]] <- TRUE
  adaptiveRT <- 38.66
  df <- data.table::data.table(multipeptide_DIAlignR[["14383"]])
  setkeyv(df, "run")
  df[3, alignment_rank := 1L]
  XICs.ref <- XICs.eXp <- list()
  XICs.ref[["4618"]] <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR[["hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]]
  XICs.eXp[["4618"]] <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR[["hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]]
  alignObj <- testAlignObj()
  tAligned <- alignedTimes2(alignObj, XICs.ref[["4618"]], XICs.eXp[["4618"]])
  setAlignmentRank(df, refIdx = 3L, eXp = "run2", tAligned, XICs.eXp, params, adaptiveRT)
  expect_equal(c(NA_integer_, NA_integer_, 1L, NA_integer_, 1L, NA_integer_), df[,alignment_rank])

  # 2nd case
  df <- data.table::data.table(multipeptide_DIAlignR[["14383"]])
  df$alignment_rank[1] <- 1L; df$m_score[5] <- 0.03
  setAlignmentRank(df, refIdx = 1L, eXp = "run2", tAligned, XICs.eXp, params, adaptiveRT)
  expect_equal(c(1L, NA_integer_, NA_integer_, NA_integer_, 1L, NA_integer_), df[,alignment_rank])

  # case 3
  setAlignmentRank(df, refIdx = 1L, eXp = "run1", tAligned, XICs.eXp, params, adaptiveRT)
  expect_equal(c(1L, NA_integer_, 1L, NA_integer_, 1L, NA_integer_), df[,alignment_rank])

  # case 4
  df <- data.table::data.table(multipeptide_DIAlignR[["14383"]])
  df$alignment_rank[3] <- 1L; df$m_score[5] <- 0.06
  setAlignmentRank(df, refIdx = 3L, eXp = "run2", tAligned, XICs.eXp, params, adaptiveRT)
  expect_equal(df[,alignment_rank], c(NA_integer_, NA_integer_, 1L, NA_integer_, NA_integer_, 1L))
  expect_equal(df[6,], data.table("transition_group_id" = 4618L, feature_id = bit64::NA_integer64_,
                                       RT = 5241.30, intensity = 189.304,  leftWidth = 5224.2, rightWidth = 5265.2, peak_group_rank = NA_integer_,
                                       m_score = NA_real_, run = "run2", alignment_rank = 1, key = "run"), tolerance = 1e-06)

  # case 5
  df <- data.table::data.table(multipeptide_DIAlignR[["14383"]])
  df$m_score[5] <- 0.06
  setAlignmentRank(df, refIdx = 1L, eXp = "run2", tAligned, XICs.eXp, params, adaptiveRT)
  expect_equal(df[6,], data.table("transition_group_id" = 4618L, feature_id = bit64::NA_integer64_,
                                  RT = 5224.20, intensity = 99.77859,  leftWidth = 5203.7, rightWidth = 5251.5, peak_group_rank = NA_integer_,
                                  m_score = NA_real_, run = "run2", alignment_rank = 1, key = "run"), tolerance = 1e-06)


  # case 6
  df <- data.table::data.table(multipeptide_DIAlignR[["14383"]])
  df$alignment_rank[3] <- 1L; df$m_score[5] <- NA_real_
  setAlignmentRank(df, refIdx = 3L, eXp = "run2", tAligned, XICs.eXp, params, adaptiveRT)
  expect_equal(df[6,], data.table("transition_group_id" = 4618L, feature_id = bit64::NA_integer64_,
                                       RT = 5241.30, intensity = 189.304,  leftWidth = 5224.2, rightWidth = 5265.2, peak_group_rank = NA_integer_,
                                       m_score = NA_real_, run = "run2", alignment_rank = 1, key = "run"),
               tolerance = 1e-06)

  # case 7
  df <- data.table::data.table(multipeptide_DIAlignR[["14383"]])
  df$alignment_rank[3] <- 1L; df$m_score[3] <- NA_real_; df$m_score[5] <- 0.03
  setAlignmentRank(df, refIdx = 3L, eXp = "run2", tAligned, XICs.eXp, params, adaptiveRT)
  expect_equal(c(NA_integer_, NA_integer_, 1L, NA_integer_, 1L, NA_integer_), df[,alignment_rank])

  # case 8
  df <- data.table::data.table(multipeptide_DIAlignR[["14383"]])
  df$alignment_rank[3] <- 1L; df$m_score[1:6] <- NA_real_
  setAlignmentRank(df, refIdx = 3L, eXp = "run2", tAligned, XICs.eXp, params, adaptiveRT)
  expect_equal(df[6,], data.table("transition_group_id" = 4618L, feature_id = bit64::NA_integer64_,
                                       RT = 5241.30, intensity = 189.304,  leftWidth = 5224.2, rightWidth = 5265.2, peak_group_rank = NA_integer_,
                                       m_score = NA_real_, run = "run2", alignment_rank = 1, key = "run"),
              tolerance = 1e-06)

  # case 9
  df <- data.table::data.table(multipeptide_DIAlignR[["14383"]])
  df$m_score[1:6] <- NA_real_
  params$fillMissing <- FALSE
  setAlignmentRank(df, refIdx = 3L, eXp = "run2", tAligned, XICs.eXp, params, adaptiveRT)
  expect_equal(df$alignment_rank, rep(NA_integer_, 6))

  # case 10
  # bit64 does not return NA, instead returns 9218868437227407266 https://stackoverflow.com/a/27283100/6484844
  expect_error(setAlignmentRank(df, refIdx = integer(0), eXp = "run2", tAligned, XICs.eXp, params, adaptiveRT))

  # case 11
  df <- data.table::data.table(multipeptide_DIAlignR[["14383"]])
  df$alignment_rank[1] <- 1L; df$m_score[5] <- 0.03
  params$recalIntensity <- TRUE
  setAlignmentRank(df, refIdx = 1L, eXp = "run2", tAligned, XICs.eXp, params, adaptiveRT)
  expect_equal(df[5,c(3:6, 10)], data.table(RT = 5240.79, intensity = 99.77859, leftWidth = 5203.7, rightWidth = 5251.5, alignment_rank = 1L),
               tolerance = 1e-06)

  # case 12
  df <- data.table::data.table(multipeptide_DIAlignR[["14383"]])
  df$alignment_rank[1] <- 1L; df$m_score[5] <- 0.03
  df$RT[5] <- 5175; df$leftWidth[5] <- 5150; df$rightWidth[5] <- 5200
  params$recalIntensity <- TRUE
  setAlignmentRank(df, refIdx = 1L, eXp = "run2", tAligned, XICs.eXp, params, adaptiveRT)
  expect_equal(df[5,c(3:6, 10)], data.table(RT = 5175, intensity = 255.496, leftWidth = 5150, rightWidth = 5200, alignment_rank = 1L),
               tolerance = 1e-06)
})

test_that("test_setOtherPrecursors", {
  data(multipeptide_DIAlignR, package="DIAlignR")
  data(XIC_QFNNTDIVLLEDFQK_3_DIAlignR, package="DIAlignR")
  params <- paramsDIAlignR()
  params[["baseSubtraction"]] <- TRUE

  df <- data.table::data.table(multipeptide_DIAlignR[["14383"]])
  XICs.eXp <- list()
  XICs.eXp[["4618"]] <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR[["hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]]

  setOtherPrecursors(df, 5L, XICs.eXp, analytes = 4618L, params)
  expect_equal(df[,alignment_rank], rep(NA_integer_, 6))

  dataPath <- system.file("extdata", package = "DIAlignR")
  mz <- mzR::openMSfile(file.path(dataPath, "xics","hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt.chrom.mzML"))
  df <- data.table::data.table(multipeptide_DIAlignR[["9861"]])
  chromIndices <- list(c(43, 44, 45, 46, 47, 48), c(49, 50, 51, 52, 53, 54))
  XICs.eXp <- lapply(chromIndices, function(i) extractXIC_group(mz, chromIndices = i))
  names(XICs.eXp) <- c("9719", "9720")
  df[10L, alignment_rank := 1L]
  setOtherPrecursors(df, 10L, XICs.eXp, analytes = c(9719L, 9720L), params)
  expect_equal(df[9L,], data.table("transition_group_id" = 9719L, feature_id = bit64::NA_integer64_,
       RT = 2607.05, intensity = 11.80541,  leftWidth = 2591.431, rightWidth = 2625.569, peak_group_rank = NA_integer_,
       m_score = NA_real_, run = "run2", alignment_rank = 1, key = "run"),
   tolerance = 1e-06)

  df <- data.table::data.table(multipeptide_DIAlignR[["9861"]])
  setOtherPrecursors(df, 10L, XICs.eXp, analytes = c(9719L, 9720L), params)
  expect_equal(df[,alignment_rank], c(rep(NA_integer_, 8), 1L, rep(NA_integer_, 3)))

  mz <- mzR::openMSfile(file.path(dataPath, "xics","hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt.chrom.mzML"))
  chromIndices <- list(c(43, 44, 45, 46, 47, 48), c(49, 50, 51, 52, 53, 54))
  XICs.eXp <- lapply(chromIndices, function(i) extractXIC_group(mz, chromIndices = i))
  names(XICs.eXp) <- c("9719", "9720")

  df[6L, alignment_rank := 1L]
  setOtherPrecursors(df, 6L, XICs.eXp, analytes = c(9719L, 9720L), params)
  expect_equal(df[,alignment_rank], c(rep(NA_integer_, 4), 1L, 1L, NA_integer_, NA_integer_, 1L, rep(NA_integer_, 3)))

  params$recalIntensity <- TRUE
  data.table::set(df, i = 5L, 10L, NA_integer_)
  setOtherPrecursors(df, 6L, XICs.eXp, analytes = c(9719L, 9720L), params)
  expect_equal(df[5,c(3:6, 10)], data.table(RT = 2586.12, intensity = 19.30421, leftWidth = 2564.094, rightWidth = 2605.06, alignment_rank = 1L),
               tolerance = 1e-06)
})


test_that("test_populateReferenceExperimentFeatureAlignmentMap",
          {
            #### Prepare Data and Output ####

            # Runs and Analyte
            ref <- "run0"
            eXp <- "run1"
            analyte_chr <- "17186"

            # Subset of Feature alignment map table
            feature_alignment_map <- data.table("reference_feature_id" = rep(bit64::as.integer64(0), 15), "experiment_feature_id" = rep(bit64::as.integer64(0), 15))
            setkeyv(feature_alignment_map, "reference_feature_id")

            # Subset of multipeptide for current eXp aligned to Ref
            dt <- structure(list(transition_group_id = c(17186L, 17186L, 17186L,
                                                         17186L, 17186L, 17186L, 17186L, 17186L, 17186L, 17186L, 17186L,
                                                         17186L, 17186L, 17186L, 17186L, 17186L, 17186L, 17186L),
                                 feature_id = structure(c(4.75292059933946e+94,
                                                          5.52612460272647e-11, 3.59272034753732e+234, 3.74370892823184e+230,
                                                          2.34380646139584e+234, 0, 2.04161779709829e+87, 1.60545397951231e+66,
                                                          5.20548354836881e-89, 2.66188671607728e-167, 4.57942078616298e+306,
                                                          0, 1.89738801704963e+63, 7.46666102909777e-250, 1.01955111889378e-75,
                                                          1.29960826886799e-188, 5.12280305276836e+252, 0), class = "integer64"),
                                 RT = c(4649.7, 4604.19, 4715.68, 4370.9, 4880.38, NA, 4681.37,
                                        4628.26, 4741.25, 4873.31, 4484.56, NA, 4676.93, 4638.36,
                                        4735.13, 4347.61, 4425.08, NA),
                                 intensity = c(396.068, 48.3087,
                                               54.6872, 60.1767, 57.5545, NA, 933.868, 96.0476, 100.972,
                                               78.625, 15.4901, NA, 412.235, 44.3814, 46.9198, 15.0419,
                                               64.7877, NA),
                                 leftWidth = c(4620.22119140625, 4582.669921875,
                                                4698.740234375, 4347.1201171875, 4879.6767578125, NA, 4637.30078125,
                                                4613.40380859375, 4722.64599609375, 4838.7158203125, 4473.43994140625,
                                                NA, 4647.56005859375, 4616.8359375, 4726.078125, 4336.90380859375,
                                                4401.77001953125, NA),
                                 rightWidth = c(4691.91015625, 4620.22119140625,
                                                4743.1220703125, 4388.0849609375, 4906.98779296875, NA, 4708.98876953125,
                                                4644.1279296875, 4767.02587890625, 4889.923828125, 4487.09521484375,
                                                NA, 4709.009765625, 4647.56005859375, 4760.216796875, 4353.97412109375,
                                                4446.14697265625, NA),
                                 peak_group_rank = c(1L, 2L, 3L, 4L,
                                                     5L, NA, 1L, 2L, 3L, 4L, 5L, NA, 1L, 2L, 3L, 4L, 5L, NA),
                                 m_score = c(5.69207721480095e-05, 0.0157610817708339, 0.224875109435837,
                                             0.281696713296988, 0.30530712857306, NA, 5.69207721480095e-05,
                                             0.00535845032028004, 0.0219196954403725, 0.318687030402833,
                                             0.383338141620706, NA, 5.69207721480095e-05, 0.0273833236082787,
                                             0.140154915469226, 0.213467945793095, 0.327528954268794,
                                             NA),
                                 run = c("run0", "run0", "run0", "run0", "run0", "run0",
                                         "run1", "run1", "run1", "run1", "run1", "run1", "run2", "run2",
                                         "run2", "run2", "run2", "run2"),
                                 alignment_rank = c(1L, NA,
                                                    NA, NA, NA, NA, 1L, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA,
                                                    NA)), row.names = c(NA, -18L), class = c("data.table", "data.frame"
                                                    ), sorted = "run")
            # Aligned RT axes
            tAligned <- testtAligned()

            # Populate alignment map table
            populateReferenceExperimentFeatureAlignmentMap(dt, feature_alignment_map, tAligned, ref, eXp, analyte_chr)

            ##### Expected Data ####
            expData <- structure(list(reference_feature_id = structure(c(4.75292059933946e+94,
                                                                         5.52612460272647e-11, 3.59272034753732e+234, 3.74370892823184e+230,
                                                                         2.34380646139584e+234, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), class = "integer64"),
                                      experiment_feature_id = structure(c(2.04161779709829e+87,
                                                                          1.60545397951231e+66, 5.20548354836881e-89, 4.57942078616298e+306,
                                                                          2.66188671607728e-167, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), class = "integer64")), row.names = c(NA,
                                                                                                                                                                     -15L), class = c("data.table", "data.frame"))

            ##### Test Expectations ####
            expect_equal(feature_alignment_map, expData, tolerance = 1e-06)
          })
