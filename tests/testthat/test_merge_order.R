context("Hierarchical clustering.")

test_that("test_nrDesc", {
  tree <- ape::read.tree(text = "((run1:0.5,run2:0.5)master2:0.5,(run3:0.5,run4:0.5)master3:0.5)master1;")
  outData <- nrDesc(tree)
  expect_identical(outData, c(1, 1, 1, 1, 4, 2, 2))
})

test_that("test_getTree", {
  m <- matrix(c(0,1,2,3, 1,0,1.5,1.5, 2,1.5,0,1, 3,1.5,1,0), byrow = TRUE,
              ncol = 4, dimnames = list(c("run1", "run2", "run3", "run4"),
                                        c("run1", "run2", "run3", "run4")))
  distMat <- as.dist(m, diag = FALSE, upper = FALSE)
  expect_message(outData <- getTree(distMat, method = "single"))
  expect_equal(outData,
          ape::read.tree(text = "((run1:0.5,run2:0.5)master2:0.25,(run3:0.5,run4:0.5)master3:0.25)master1;")
               )
})

test_that("test_getNodeIDs", {
  tree <- ape::read.tree(text = "((run1:0.5,run2:0.5)master2:0.5,(run3:0.5,run4:0.5)master3:0.5)master1;")
  outData <- getNodeIDs(tree)
  expData <- c("run1" = 1L, "run2" = 2L, "run3" = 3L, "run4" = 4L,
               "master1" = 5L, "master2" = 6L, "master3" = 7L)
  expect_identical(outData, expData)
})

test_that("test_traverseUp", {
  dataPath <- system.file("extdata", package = "DIAlignR")
  params <- paramsDIAlignR()
  params[["keepFlanks"]] <- TRUE
  params[["XICfilter"]] <- "none"; params[["kernelLen"]] <- 0L
  params[["globalAlignmentFdr"]] <- 0.05
  params[["globalAlignment"]] <- "loess"
  params[["context"]] <- "experiment-wide"
  params[["baseSubtraction"]] <- TRUE
  fileInfo <- getRunNames(dataPath = dataPath, params = params)
  mzPntrs <- list2env(getMZMLpointers(fileInfo))
  precursors <- data.table(transition_group_id = 4618L, peptide_id = 14383L,
                           sequence = "QFNNTDIVLLEDFQK", charge = 3L,
                           group_label = "14299_QFNNTDIVLLEDFQK/3",
                           transition_ids	= list(27706:27711), key = c("peptide_id", "transition_group_id"))
  peptideIDs <- 14383L
  peptideScores <- getPeptideScores(fileInfo, peptides = peptideIDs, TRUE, "DIA_Proteomics", "experiment-wide")
  masters <- paste("master", 1:(nrow(fileInfo)-1), sep = "")
  peptideScores <- lapply(peptideIDs, function(pep) {x <- peptideScores[.(pep)][,-c(1L)]
  x <- rbindlist(list(x, data.table("run" = masters, "score" = NA_real_, "pvalue" = NA_real_,
                                    "qvalue" = NA_real_)), use.names=TRUE)
  setkeyv(x, "run"); x})
  names(peptideScores) <- as.character(peptideIDs)

  features <- getFeatures(fileInfo, maxFdrQuery = 0.05, runType = "DIA_Proteomics")
  masterFeatures <- dummyFeatures(precursors, masters, FALSE)
  features <- do.call(c, list(features, masterFeatures))

  prec2chromIndex <- getChromatogramIndices(fileInfo, precursors, mzPntrs)
  masterChromIndex <- dummyChromIndex(precursors, masters)
  prec2chromIndex <- do.call(c, list(prec2chromIndex, masterChromIndex))
  adaptiveRTs <- new.env()
  refRuns <- new.env()
  multipeptide <- getMultipeptide(precursors, features, masters = NULL)

  tree <- ape::read.tree(text = "(run1:7,run2:2)master1;")
  tree <- ape::reorder.phylo(tree, "postorder")
  msg <- capture_messages(traverseUp(tree, dataPath, fileInfo, features, mzPntrs, prec2chromIndex, precursors,
                                     params, adaptiveRTs, refRuns, multipeptide, peptideScores, NULL))
  expect_equal(msg, c("run1 + run2 = master1\n",
                    "Getting merged chromatograms for run master1\n",
                    "Geting global alignment of run1 and run2,",
                    " n = 150\n",
                    "Geting global alignment of run2 and run1,",
                    " n = 150\n",
                    "Getting merged features for run master1\n",
                    "Created a child run: master1\n",
                    "Created all master runs.\n"))

  expect_setequal(ls(mzPntrs), c("run0", "run1", "run2", "master1"))
  expect_is(mzPntrs[["master1"]], "SQLiteConnection")
  expect_equal(features$master1[1,],  data.table(transition_group_id = 4618L,
                    feature_id = bit64::as.integer64(7675762503084486466),
                    RT = 5237.8, intensity = 229.707813, leftWidth = 5217.35, rightWidth = 5261.7,
                    peak_group_rank = 1L, m_score = 5.692e-05, key = "transition_group_id"), tolerance = 1e-04)
  expect_identical(fileInfo["master1", "chromatogramFile"], file.path(dataPath, "xics", "master1.chrom.sqMass"))
  expect_identical(fileInfo["master1", "runName"], "master1")
  expect_identical(prec2chromIndex$master1[,"transition_group_id"][[1]], 4618L)
  expect_identical(prec2chromIndex$master1[,"chromatogramIndex"][[1]][[1]], 0:5)
  expect_equal(adaptiveRTs[["run1_run2"]], 77.0036, tolerance = 1e-04)
  expect_equal(adaptiveRTs[["run2_run1"]], 76.25354, tolerance = 1e-04)
  expect_identical(refRuns[["master1"]][[1]], 1L)
  expect_identical(refRuns[["master1"]][[2]], "4618")

  data(masterXICs_DIAlignR, package="DIAlignR")
  outData <- extractXIC_group2(mzPntrs[["master1"]], 0:5)
  for(run in names(mzPntrs)) DBI::dbDisconnect(mzPntrs[[run]])
  for(i in seq_along(outData)){
    expect_equal(outData[[i]][,1], masterXICs_DIAlignR[[1]][[i]][[1]], tolerance = 1e-04)
    expect_equal(outData[[i]][,2], masterXICs_DIAlignR[[1]][[i]][[2]], tolerance = 1e-04)
  }
  outData <- readRDS(file.path(dataPath, "master1_av.rds"), refhook = NULL)
  for(i in 1:3) expect_equal(outData[[1]][,i], masterXICs_DIAlignR[[2]][,i+2], tolerance = 1e-04)
  file.remove(file.path(dataPath, "master1_av.rds"))
  file.remove(file.path(dataPath, "xics", "master1.chrom.sqMass"))
})

test_that("test_setRootRank_traverseDown", {
  dataPath <- system.file("extdata", package = "DIAlignR")
  params <- paramsDIAlignR()
  params[["maxPeptideFdr"]] <- 0.05
  params[["keepFlanks"]] <- TRUE
  params[["XICfilter"]] <- "none"; params[["kernelLen"]] <- 0L
  params[["globalAlignmentFdr"]] <- 0.05
  params[["globalAlignment"]] <- "loess"
  params[["context"]] <- "experiment-wide"
  params[["baseSubtraction"]] <- TRUE
  fileInfo <- getRunNames(dataPath = dataPath, params = params)
  mzPntrs <- list2env(getMZMLpointers(fileInfo))
  precursors <- getPrecursors(fileInfo, oswMerged = TRUE, params[["runType"]], params[["context"]], params[["maxPeptideFdr"]])
  precursors <- precursors[precursors$peptide_id %in% c("7040", "9861", "14383"),]
  peptideIDs <-  c(7040L, 9861L, 14383L)
  peptideScores <- getPeptideScores(fileInfo, peptides = peptideIDs, TRUE, "DIA_Proteomics", "experiment-wide")
  masters <- paste("master", 1:(nrow(fileInfo)-1), sep = "")
  peptideScores <- lapply(peptideIDs, function(pep) {x <- peptideScores[.(pep)][,-c(1L)]
  x <- rbindlist(list(x, data.table("run" = masters, "score" = NA_real_, "pvalue" = NA_real_,
                                    "qvalue" = NA_real_)), use.names=TRUE)
  setkeyv(x, "run"); x})
  names(peptideScores) <- as.character(peptideIDs)

  features <- getFeatures(fileInfo, maxFdrQuery = 0.05, runType = "DIA_Proteomics")
  masterFeatures <- dummyFeatures(precursors, masters, FALSE)
  features <- do.call(c, list(features, masterFeatures))

  prec2chromIndex <- getChromatogramIndices(fileInfo, precursors, mzPntrs)
  masterChromIndex <- dummyChromIndex(precursors, masters)
  prec2chromIndex <- do.call(c, list(prec2chromIndex, masterChromIndex))
  adaptiveRTs <- new.env()
  refRuns <- new.env()
  multipeptide <- getMultipeptide(precursors, features, masters = NULL)

  tree <- ape::read.tree(text = "(run1:7,run2:2)master1;")
  tree <- ape::reorder.phylo(tree, "postorder")
  expect_warning(traverseUp(tree, dataPath, fileInfo, features, mzPntrs, prec2chromIndex, precursors,
             params, adaptiveRTs, refRuns, multipeptide, peptideScores, NULL))

  df1 <- data.table::copy(multipeptide[["7040"]])
  df2 <- data.table::copy(multipeptide[["9861"]])
  df3 <- data.table::copy(multipeptide[["14383"]])

  # setRootRank
  expect_message(setRootRank(tree, dataPath, fileInfo, multipeptide, prec2chromIndex, mzPntrs, precursors,params),
                 "master1 has set alignment ranks.", all = TRUE)
  expect_equal(multipeptide[["7040"]], df1)
  expect_equal(multipeptide[["9861"]][1:2,],
               data.table(transition_group_id = c(9719L, 9720L), feature_id = bit64::as.integer64(c("6462000664077079508", "5135268764240690321")), RT = 2594.85,
                          intensity = c(14.62899, 20.94301), leftWidth = c(2581.15, 2576.05), rightWidth = c(2625.55, 2622.15),
                          peak_group_rank = 1L, m_score = c(1.041916e-03, 5.692077e-05), run = "master1", alignment_rank = 1L, key = "run"),
               tolerance = 1e-06)
  expect_equal(multipeptide[["14383"]][13:18, alignment_rank], rep(NA_integer_, 6L))

  # traverseDown
  expect_message(traverseDown(tree, dataPath, fileInfo, multipeptide, prec2chromIndex, mzPntrs, precursors,
                              adaptiveRTs, refRuns, params, lapply),
               ("Mapping peaks from master1 to run1 and run2.\n|run1 has been aligned to master1.\n|run2 has been aligned to master1.\n|master1 run has been propagated to all parents."),
               all = TRUE)
  df3$alignment_rank[c(15L, 17L)] <- 1L
  df3$alignment_rank[which(df3$run == "master1")[1]] <- 1L
  expect_equal(multipeptide[["14383"]], df3)

  for(run in names(mzPntrs)) DBI::dbDisconnect(mzPntrs[[run]])
  df2$alignment_rank[c(29L, 30L, 33L, 34L)] <- 1L
  df2$alignment_rank[which(df2$run == "master1")[1:2]] <- 1L
  expect_equal(multipeptide[["9861"]][-33L,], df2[-33L,])
  expect_equal(multipeptide[["9861"]][33L,], data.table(transition_group_id = 9719L, feature_id = bit64::NA_integer64_,
      RT = 2607.05, intensity = 11.80541, leftWidth = 2591.431, rightWidth = 2625.569,
      peak_group_rank = NA_integer_, m_score = NA_real_, run = "run2", alignment_rank = 1L, key = "run"),
      tolerance = 1e-06)

  expect_equal(multipeptide[["7040"]], df1)
  file.remove(file.path(dataPath, "master1_av.rds"))
  file.remove(file.path(dataPath, "xics", "master1.chrom.sqMass"))
})

test_that("test_alignToMaster", {
  dataPath <- system.file("extdata", package = "DIAlignR")
  params <- paramsDIAlignR()
  params[["keepFlanks"]] <- TRUE
  params[["XICfilter"]] <- "none"; params[["kernelLen"]] <- 0L
  params[["globalAlignmentFdr"]] <- 0.05
  fileInfo <- getRunNames(dataPath = dataPath, params = params)
  mzPntrs <- list2env(getMZMLpointers(fileInfo))
  precursors <- data.table(transition_group_id = 4618L, peptide_id = 14383L,
                           sequence = "QFNNTDIVLLEDFQK", charge = 3L,
                           group_label = "14299_QFNNTDIVLLEDFQK/3",
                           transition_ids	= list(27706:27711), key = c("peptide_id", "transition_group_id"))
  peptideIDs <- 14383L
  peptideScores <- getPeptideScores(fileInfo, peptides = peptideIDs, TRUE, "DIA_Proteomics", "experiment-wide")
  masters <- paste("master", 1:(nrow(fileInfo) + 1), sep = "")
  peptideScores <- lapply(peptideIDs, function(pep) {x <- peptideScores[.(pep)][,-c(1L)]
  x <- rbindlist(list(x, data.table("run" = masters, "score" = NA_real_, "pvalue" = NA_real_,
                                    "qvalue" = NA_real_)), use.names=TRUE)
  setkeyv(x, "run"); x})
  names(peptideScores) <- as.character(peptideIDs)

  features <- getFeatures(fileInfo, maxFdrQuery = 0.05, runType = "DIA_Proteomics")
  masterFeatures <- dummyFeatures(precursors, masters, FALSE)
  features <- do.call(c, list(features, masterFeatures))

  prec2chromIndex <- getChromatogramIndices(fileInfo, precursors, mzPntrs)
  masterChromIndex <- dummyChromIndex(precursors, masters)
  prec2chromIndex <- do.call(c, list(prec2chromIndex, masterChromIndex))
  adaptiveRTs <- new.env()
  refRuns <- new.env()
  multipeptide <- getMultipeptide(precursors, features, masters = NULL)
  tree <- ape::reorder.phylo(ape::read.tree(text = "(run1:7,run2:2)master1;"), "postorder")

  traverseUp(tree, dataPath, fileInfo, features, mzPntrs, prec2chromIndex, precursors, params,
    adaptiveRTs, refRuns, multipeptide, peptideScores, NULL)
  alignedVecs <- readRDS(file = file.path(dataPath, "master1_av.rds"))
  adaptiveRT <- max(adaptiveRTs[["run1_run2"]], adaptiveRTs[["run2_run1"]])
  multipeptide[["14383"]]$alignment_rank[which(multipeptide[["14383"]]$run == "master1")[1]] <- 1L
  df <- data.table::copy(multipeptide[["14383"]])

  alignToMaster(ref = "master1", eXp = "run1", alignedVecs, 1L, adaptiveRT,
    multipeptide, prec2chromIndex, mzPntrs, fileInfo, precursors, params)
  df$alignment_rank[which(df$run == "run1")[1]] <- 1L
  expect_equal(multipeptide[["14383"]], df)

  alignToMaster(ref = "master1", eXp = "run2", alignedVecs, 2L, adaptiveRT,
                multipeptide, prec2chromIndex, mzPntrs, fileInfo, precursors, params)
  df$alignment_rank[which(df$run == "run2")[1]] <- 1L
  expect_equal(multipeptide[["14383"]], df)

  for(run in names(mzPntrs)) DBI::dbDisconnect(mzPntrs[[run]])
  file.remove(file.path(dataPath, "master1_av.rds"))
  file.remove(file.path(dataPath, "xics", "master1.chrom.sqMass"))
})
