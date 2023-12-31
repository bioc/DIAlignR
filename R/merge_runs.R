#' Create a child run from two parent runs
#'
#' Get merged features and merged chromatograms from parent runs. Chromatograms are written on the disk
#' at dataPath/xics. For each precursor aligned parent time-vectors and corresponding child time-vector
#' are also calculated and written as *_av.rda at dataPath.
#'
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2020) + GPL-3
#' Date: 2020-06-06
#' @importFrom data.table data.table set
#' @import RSQLite DBI
#' @inherit getChildXICs params
#' @inheritParams traverseUp
#' @param mergeName (string) name of the node that is generated with merging of runA and runB.
#' @param adaptiveRTs (environment) an empty environment used to store data for downstream analysis.
#' @param refRuns (environment) an empty environment used to store data for downstream analysis.
#' @return (None)
#' @keywords internal
#' @seealso \code{\link{childXICs}, \link{getChildXICs}, \link{traverseUp}}
#' @examples
#' library(data.table)
#' dataPath <- system.file("extdata", package = "DIAlignR")
#' params <- paramsDIAlignR()
#' fileInfo <- getRunNames(dataPath = dataPath)
#' mzPntrs <- list2env(getMZMLpointers(fileInfo))
#' precursors <- getPrecursors(fileInfo, oswMerged = TRUE, runType = params[["runType"]],
#'  context = "experiment-wide", maxPeptideFdr = params[["maxPeptideFdr"]])
#' peptideIDs <- unique(precursors$peptide_id)
#' peptideScores <- getPeptideScores(fileInfo, peptideIDs, oswMerged = TRUE, params[["runType"]], params[["context"]])
#' masters <- paste("master", 1:(nrow(fileInfo)-1), sep = "")
#' peptideScores <- lapply(peptideIDs, function(pep) {x <- peptideScores[.(pep)][,-c(1L)]
#'   x <- rbindlist(list(x, data.table("run" = masters, "score" = NA_real_, "pvalue" = NA_real_,
#'     "qvalue" = NA_real_)), use.names=TRUE)
#'   setkeyv(x, "run"); x})
#' names(peptideScores) <- as.character(peptideIDs)
#' features <- getFeatures(fileInfo, maxFdrQuery = 1.00, runType = "DIA_Proteomics")
#' \dontrun{
#' masterFeatures <- dummyFeatures(precursors, nrow(fileInfo)-1, 1L)
#' features <- do.call(c, list(features, masterFeatures))
#' multipeptide <- getMultipeptide(precursors, features, numMerge = 0L, startIdx = 1L)
#' prec2chromIndex <- getChromatogramIndices(fileInfo, precursors, mzPntrs)
#' masterChromIndex <- dummyChromIndex(precursors, nrow(fileInfo)-1, 1L)
#' prec2chromIndex <- do.call(c, list(prec2chromIndex, masterChromIndex))
#' mergeName <- "master1"
#' adaptiveRTs <- new.env()
#' refRuns <- new.env()
#' getNodeRun(runA = "run2", runB = "run0", mergeName = mergeName, dataPath = ".", fileInfo, features,
#'  mzPntrs, prec2chromIndex, precursors, params, adaptiveRTs, refRuns, multipeptide, peptideScores, ropenms = NULL)
#' file.remove(file.path(".", "xics", paste0(mergeName, ".chrom.sqMass")))
#' file.remove(list.files(".", pattern = "*_av.rds", full.names = TRUE))
#' }
#' for(run in names(mzPntrs)) DBI::dbDisconnect(mzPntrs[[run]])
getNodeRun <- function(runA, runB, mergeName, dataPath, fileInfo, features, mzPntrs, prec2chromIndex,
                       precursors, params, adaptiveRTs, refRuns, multipeptide, peptideScores, ropenms, applyFun = lapply){
  peptides <- unique(precursors$peptide_id)
  wFunc <- params[["wF"]]
  ##### Select reference for each peptide and update peptideScores. #####
  var1 <- rep(NA_integer_, length(peptides))
  var2 <- rep(NA_integer_, length(peptides))
  for(i in seq_along(peptides)){
    temp <- peptideScores[[i]]
    iA <- which(temp[["run"]] == runA)
    pvalA <- ifelse(length(iA) == 0, NA_real_, .subset2(temp, "pvalue")[[iA]])
    iB <- which(temp[["run"]] == runB)
    pvalB <- ifelse(length(iB) == 0, NA_real_, .subset2(temp, "pvalue")[[iB]])
    if(is.na(pvalA)) pvalA <- 1
    if(is.na(pvalB)) pvalB <- 1
    var1[i] <- ifelse(pvalA > pvalB, 2L, 1L)
    idx <- which(temp[["run"]] == mergeName)
    if(length(iA)+length(iB) > 0){
      set(temp, idx, c(2L, 3L, 4L),
          list(max(temp$score[c(iA, iB)], -1000, na.rm = TRUE),
               wFunc(temp$pvalue[c(iA, iB)], 0.99, na.rm = TRUE), min(temp$qvalue[c(iA, iB)], 0.99, na.rm = TRUE)))}
    temp <- multipeptide[[i]]
    iA <- which(temp[["run"]] == runA)
    iB <- which(temp[["run"]] == runB)
    idx <- which.min(.subset2(temp, "m_score")[c(iA, iB)])
    idx <- ifelse(length(idx)==0, c(iA, iB)[1], c(iA, iB)[idx])
    var2[i] <- .subset2(temp, "transition_group_id")[[idx]]
  }
  refRun <- data.table("var1" = var1, "var2" = as.character(var2))

  ##### Get childXICs #####
  message("Getting merged chromatograms for run ", mergeName)
  mergedXICs_alignedVec <- getChildXICs(runA, runB, fileInfo, features, mzPntrs, precursors, prec2chromIndex,
                                        refRun, peptideScores, params, applyFun)
  mergedXICs <- mergedXICs_alignedVec[[1]]
  alignedVecs <- mergedXICs_alignedVec[[2]]
  adaptiveRT <- mergedXICs_alignedVec[[3]]

  ##### Get merged features, calculate intensities, left width, right width, m-score. #####
  # we can also run pyopenms feature finder on new chromatogram.
  message("Getting merged features for run ", mergeName)
  childFeatures <- applyFun(seq_along(peptides), function(i){
    analytes <- as.integer(names(mergedXICs[[i]]))
    alignedVec <- alignedVecs[[i]]
    childFeature <- lapply(seq_along(mergedXICs[[i]]), function(j){
      if(is.null(mergedXICs[[i]][[j]])) return(NULL)
      XICs <- mergedXICs[[i]][[j]]
      analyte <- analytes[j]
      idxA <- which(features[[runA]][["transition_group_id"]] == analyte)
      idxA <- idxA[!is.na(.subset2(features[[runA]], "RT")[idxA])]
      idxB <- which(features[[runB]][["transition_group_id"]] == analyte)
      idxB <- idxB[!is.na(.subset2(features[[runB]], "RT")[idxB])]
      if(.subset2(refRun, 1L)[[i]] == 1L) {
        df.ref <- features[[runA]]
        i.ref <- idxA
        i.eXp <- idxB
        df.eXp <- features[[runB]]
      } else{
        df.ref <- features[[runB]]
        i.ref <- idxB
        i.eXp <- idxA
        df.eXp <- features[[runA]]
      }
      if((length(i.ref) + length(i.eXp)) == 0) return(NULL)
      getChildFeature(XICs, alignedVec, df.ref, df.eXp, i.ref, i.eXp, params)
    })
    rbindlist(childFeature, use.names = FALSE)
  })

  ##### Add features to multipeptide #####
  invisible(lapply(seq_along(peptides), function(i){
    peptide_chr <- as.character(peptides[i])
    temp <- multipeptide[[i]]
    rowIdx <- which(temp[["run"]] == mergeName)
    df <- childFeatures[[i]]
    j = nrow(df)
    cols <- c("transition_group_id", "feature_id", "RT", "intensity", "leftWidth", "rightWidth", "peak_group_rank", "m_score")
    if(j != 0L){
      j = min(j, length(rowIdx))
      for(k in 1:j) set(temp, rowIdx[k], cols, df[k,])
    }
    invisible(NULL)
  })
  )

  rm(temp)
  ##### Add node features #####
  childFeatures <- rbindlist(childFeatures)
  N <- nrow(childFeatures)
  for(i in seq_along(childFeatures)){
    set(features[[mergeName]], 1:N, i, childFeatures[[i]])
  }
  setkeyv(features[[mergeName]], "transition_group_id")

  ##### Write node mzML file #####
  mergedXICs <- unlist(mergedXICs, recursive = FALSE, use.names = FALSE)
  if(params[["chromFile"]] =="mzML"){
    fileName <- file.path(dataPath, "xics", paste0(mergeName, ".chrom.mzML"))
    createMZML(ropenms, fileName, mergedXICs, precursors$transition_ids)
  } else if(params[["chromFile"]] =="sqMass"){
    fileName <- file.path(dataPath, "xics", paste0(mergeName, ".chrom.sqMass"))
    createSqMass(fileName, mergedXICs, precursors$transition_ids, params[["lossy"]])
  }

  ##### Add node run to fileInfo #####
  row <- data.frame(runName = mergeName, spectraFile = NA_character_, spectraFileID = NA_character_,
                    featureFile = NA_character_, chromatogramFile = fileName, row.names = mergeName)
  df <- dplyr::bind_rows(fileInfo, row)
  assign("temp", df, envir = parent.frame(n = 1))
  with(parent.frame(n = 1), fileInfo <- temp)

  ##### Add node run to mzPntrs #####
  if(params[["chromFile"]] =="mzML"){
    mzPntr <- mzR::openMSfile(fileName, backend = "pwiz")
    chromHead <- mzR::chromatogramHeader(mzPntr) #TODO: Make sure that chromatogramIndex is read as integer64
  } else if(params[["chromFile"]] =="sqMass"){
    mzPntr <- DBI::dbConnect(RSQLite::SQLite(), dbname = fileName)
    chromHead <- readSqMassHeader(mzPntr)
  }
  assign("temp", mzPntr, envir = parent.frame(n = 1))
  with(parent.frame(n = 1), mzPntrs[[mergeName]] <- temp)

  ##### Add node run to prec2chromIndex #####
  prec2transition <- dplyr::select(precursors, 'transition_group_id', 'transition_ids') %>%
    tidyr::unnest('transition_ids') %>% as.data.frame()
  chromatogramIdAsInteger(chromHead) # Select only chromatogramId, chromatogramIndex
  df <- mapPrecursorToChromIndices(prec2transition, chromHead) # Get chromatogram Index for each precursor.
  df <- df[match(precursors$transition_group_id, df$transition_group_id),]
  set(prec2chromIndex[[mergeName]], NULL,"chromatogramIndex",  df[["chromatogramIndex"]])

  ##### Write AlignedVecs #####
  filename <- file.path(dataPath, paste0(mergeName, "_av.rds"))
  saveRDS(alignedVecs, file = filename)

  ##### Add adaptiveRT to adaptiveRTs #####
  ab <- paste(runA, runB, sep = "_")
  ba <- paste(runB, runA, sep = "_")
  adaptiveRTs[[ab]] <- adaptiveRT[["ab"]]
  adaptiveRTs[[ba]] <- adaptiveRT[["ba"]]

  ##### Add refRun to refRuns #####
  refRuns[[mergeName]] <- refRun

  ##### Done #####
  message("Created a child run: ", mergeName)
  invisible(NULL)
}


#' Transform features to child time-domain
#'
#' This function transforms the peaks' times to child run's time-domain. The feature intensity is
#' calculated with appropriate method stated in params.
#' Internal missing values are not allowed in timeParent.
#' @inheritParams checkParams
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2020) + GPL-3
#' Date: 2020-07-17
#' @param XICs (list of data-frames) extracted ion chromatograms from the child run.
#' @param alignedVec (data-frame) aligned parent time-vectors. Must have five columns
#' @param df.ref (data-frame) contains reference-run features to be transformed. It has a format of \code{\link{getFeatures}} output.
#' @param df.eXp (data-frame) contains experiment-run features to be transformed. It has a format of \code{\link{getFeatures}} output.
#' @return (data-frame) this has a format of \code{\link{getFeatures}} output.
#' @keywords internal
#' @seealso \code{\link{trfrParentFeature}, \link{getNodeRun}}
#' @examples
#' data(masterXICs_DIAlignR, package="DIAlignR")
#' newXICs <- masterXICs_DIAlignR
#' params <- paramsDIAlignR()
#' dataPath <- system.file("extdata", package = "DIAlignR")
#' fileInfo <- DIAlignR::getRunNames(dataPath = dataPath)
#' features <- getFeatures(fileInfo, maxFdrQuery = 1.00, runType = "DIA_Proteomics")
#' df.ref <- features$run1[features$run1$transition_group_id == 4618L, ]
#' df.eXp <- features$run2[features$run2$transition_group_id == 4618L, ]
#' \dontrun{
#' getChildFeature(newXICs[[1]], newXICs[[2]], df.ref, df.eXp, params)
#' }
getChildFeature <- function(XICs, alignedVec, df.ref, df.eXp, i.ref, i.eXp, params){
  # Find top five features from both runs combined
  # RT intensity left right m-score
  f <- rbind(trfrParentFeature(XICs, alignedVec[, c(1L, 3L)], df.ref, i.ref, params),
             trfrParentFeature(XICs, alignedVec[, c(2L, 3L)], df.eXp, i.eXp, params))
  fid <- c(.subset2(df.ref, "feature_id")[i.ref], .subset2(df.eXp, "feature_id")[i.eXp])
  peak_rank <- rep(NA_integer_, nrow(f)) # peak-rank
  mutate_score <- as.numeric(f[, 5L])
  k1 <- sapply(f[, 2L], function(k) any(is.na(k))) # index of missing intensity
  mutate_score[k1] <- NA_real_ # Missing intensity.
  inten <- sapply(f[, 2L], sum)
  inten[k1] <- NA_real_ # Missing intensity.

  r <- 0L
  while(any(is.na(peak_rank)) & !all(is.na(mutate_score)) & r < 5L) {
    minM <- min(mutate_score, na.rm = TRUE)
    idx <- which(abs(mutate_score - minM) <= 0)
    idx <- idx[which.max(inten[idx])]
    #idx <- which.min(mutate_score)
    r <- r+1L
    mutate_score[idx] <- NA_real_
    inten[idx] <- NA_real_
    peak_rank[idx] <- r
    pk <- c(f[idx, 3L][[1]], f[idx, 4L][[1]])
    # Remove other peaks that have conflicting boundaries
    rmv <- sapply(1:nrow(f), function(i) checkOverlap(pk, c(f[i, 3L][[1]], f[i, 4L][[1]])))
    rmv[idx] <- FALSE
    mutate_score[rmv] <- NA_real_
    inten[rmv] <- NA_real_
  }

  if(r == 0L) return(NULL) # No peak group can be ranked hence return NULL
  # Create data.frame from these top five features
  analyte <- ifelse(length(i.ref) !=0, .subset2(df.ref, 1L)[i.ref[1]], .subset2(df.eXp, 1L)[i.eXp[1]])
  o <- order(peak_rank, na.last = NA)
  f <- f[o,, drop = FALSE]
  list("transition_group_id" = rep(analyte, nrow(f)), "feature_id" = fid[o],
       "RT" = as.numeric(f[,1]), "intensity"= f[,2],
       "leftWidth" = as.numeric(f[,3]), "rightWidth"  = as.numeric(f[,4]),
       "peak_group_rank" = peak_rank[o], "m_score" = as.numeric(f[,5]))
}

#' Transform features to child time-domain
#'
#' This function transforms the peaks' times to child run's time-domain. The feature intensity is
#' calculated with appropriate method stated in params.
#' Internal missing values are not allowed in timeParent.
#' @inheritParams checkParams
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2020) + GPL-3
#' Date: 2020-07-17
#' @param XICs (list of data-frames) extracted ion chromatograms from the child run.
#' @param timeParent (data-frame) has two columns: tAligned and alignedChildTime. tAligned is time vector from one of the parent run.
#' @param df (data-frame) contains features to be transformed. It has a format of \code{\link{getFeatures}} output.
#' @return (data-frame) this has a format of \code{\link{getFeatures}} output.
#' @keywords internal
#' @seealso \code{\link{getChildFeature}}
#' @examples
#' data(masterXICs_DIAlignR, package="DIAlignR")
#' newXICs <- masterXICs_DIAlignR
#' timeParent <- newXICs[[2]][, c("tAligned.ref", "alignedChildTime")]
#' colnames(timeParent) <- c("tAligned", "alignedChildTime")
#' params <- paramsDIAlignR()
#' dataPath <- system.file("extdata", package = "DIAlignR")
#' fileInfo <- DIAlignR::getRunNames(dataPath = dataPath)
#' features <- getFeatures(fileInfo, maxFdrQuery = 1.00, runType = "DIA_Proteomics")
#' df <- features$run1[features$run1$transition_group_id == 4618L, ]
#' \dontrun{
#' trfrParentFeature(newXICs[[1]], timeParent, df, params)
#' }
trfrParentFeature <- function(XICs, timeParent, df, i, params){
  if(length(i) == 0L) return (NULL)
  # Transform the left boundary
  idx <- sapply(.subset2(df, "leftWidth")[i], function(t) which.min(abs(timeParent[, 1L] - t)))
  left <- timeParent[idx, 2L]

  # Transform the right boundary
  idx <- sapply(.subset2(df, "rightWidth")[i], function(t) which.min(abs(timeParent[, 1L] - t)))
  right <- timeParent[idx, 2L]

  # Transform the retention time
  idx <- sapply(.subset2(df, "RT")[i], function(t) which.min(abs(timeParent[, 1L] - t)))
  RT <- timeParent[idx, 2L]

  # Calculate peak area
  area <- lapply(seq_along(i), function(j) calculateIntensity(XICs, left[j], right[j], params))
  if(!params[["transitionIntensity"]]) area <- unlist(area)

  matrix(c(RT, area, left, right, .subset2(df, "m_score")[i]), ncol = 5L)
}

#' Develop child XICs for precursors
#'
#' This function performs the chromatogram alignment of all precursors across runA and runB. Aligned
#' chromatograms are merged into a child chromatogram. Aligned time vector and resulting child time
#' vector for each precursor is also returned.
#' @inherit traverseUp params
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2020) + GPL-3
#' Date: 2020-06-06
#' @param runA (string) name of a run to be merged with runB. Must be in the rownames of fileInfo.
#' @param runB (string) name of a run to be merged with runA. Must be in the rownames of fileInfo.
#' @param refRun (integer) must be of the same length as of precursors. 1: reference is runA, 2: reference is runB.
#' @return (list) has three elements. The first element has child XICs for all the precursors.
#' The second element has corresponding aligned time vectors. Third element contains Residual Standard
#' Errors (RSE) of global fits amongst runA and runB.
#' @seealso \code{\link{childXICs}, \link{getNodeRun}}
#' @examples
#' dataPath <- system.file("extdata", package = "DIAlignR")
#' params <- paramsDIAlignR()
#' fileInfo <- DIAlignR::getRunNames(dataPath = dataPath)
#' mzPntrs <- getMZMLpointers(fileInfo)
#' features <- getFeatures(fileInfo, maxFdrQuery = 1.00, runType = "DIA_Proteomics")
#' precursors <- getPrecursors(fileInfo, oswMerged = TRUE, runType = "DIA_Proteomics",
#'  context = "experiment-wide", maxPeptideFdr = 0.05)
#' precursors <- dplyr::arrange(precursors, .data$peptide_id, .data$transition_group_id)
#' peptideIDs <- unique(precursors$peptide_id)
#' peptideScores <- getPeptideScores(fileInfo, peptideIDs, oswMerged = TRUE, params[["runType"]], params[["context"]])
#' peptideScores <- lapply(peptideIDs, function(pep) dplyr::filter(peptideScores, .data$peptide_id == pep))
#' names(peptideScores) <- as.character(peptideIDs)
#' prec2chromIndex <- getChromatogramIndices(fileInfo, precursors, mzPntrs)
#' var2 <- as.character(sapply(peptideIDs, function(p) precursors$transition_group_id[which(precursors$peptide_id == p)[1]]))
#' refRun <- data.frame(rep(1L, length(peptideIDs)), var2)
#' mergedXICs <- getChildXICs(runA = "run1", runB = "run2", fileInfo, features, mzPntrs,
#'   precursors, prec2chromIndex, refRun, peptideScores, params)
#' for(con in mzPntrs) DBI::dbDisconnect(con)
#' @export
getChildXICs <- function(runA, runB, fileInfo, features, mzPntrs, precursors, prec2chromIndex, refRun,
                         peptideScores, params, applyFun = lapply){
  peptides <- unique(precursors$peptide_id)

  #### Get global alignment between runs ####
  pair <- paste(runA, runB, sep = "_")
  globalFit1 <- getGlobalAlignment(features, runA, runB,
                                   params[["globalAlignment"]], params[["globalAlignmentFdr"]], params[["globalAlignmentSpan"]])
  adaptiveRT1 <-  params[["RSEdistFactor"]]*getRSE(globalFit1, params[["globalAlignment"]])
  globalFit1 <- extractFit(globalFit1, params[["globalAlignment"]])
  globalFit2 <- getGlobalAlignment(features, runB, runA,
                                   params[["globalAlignment"]], params[["globalAlignmentFdr"]], params[["globalAlignmentSpan"]])
  adaptiveRT2 <-  params[["RSEdistFactor"]]*getRSE(globalFit2, params[["globalAlignment"]])
  globalFit2 <- extractFit(globalFit2, params[["globalAlignment"]])

  #### Get merged XICs ####
  num_of_batch <- ceiling(length(peptides)/params[["batchSize"]])
  temp <- lapply(1:num_of_batch, parFUN1, runA, runB, peptides, precursors, prec2chromIndex, mzPntrs,
                 params, peptideScores, refRun, globalFit1, globalFit2, adaptiveRT1, adaptiveRT2, applyFun)
  temp <- unlist(temp, recursive = FALSE)
  mergedXICs <- lapply(temp, `[[`, 1)
  alignedVecs <- lapply(temp, `[[`, 2)
  list(mergedXICs, alignedVecs, adaptiveRT = list(ab= adaptiveRT1, ba = adaptiveRT2))
}

parFUN1 <- function(iBatch, runA, runB, peptides, precursors, prec2chromIndex, mzPntrs, params,
                    peptideScores, refRun, globalFit1, globalFit2, adaptiveRT1, adaptiveRT2, applyFun){
  batchSize <- params[["batchSize"]]
  #if(params[["chromFile"]] =="mzML") fetchXIC = extractXIC_group
  fetchXIC = extractXIC_group2
  strt <- ((iBatch-1)*batchSize+1)
  stp <- min((iBatch*batchSize), length(peptides))
  cons <- vector(mode = "list", length = 2L)
  #### Create a temporary database to store chromatogram for the batch ####
  pIdx <- lapply(peptides[strt:stp], function(pep) which(precursors$peptide_id == pep))
  analytes <- lapply(pIdx, function(i) .subset2(precursors, "transition_group_id")[i])
  chromIndices.A <- lapply(pIdx, function(i) prec2chromIndex[[runA]][["chromatogramIndex"]][i])
  chromIndices.B <- lapply(pIdx, function(i) prec2chromIndex[[runB]][["chromatogramIndex"]][i])
  cons[[1]] <- createTemp(mzPntrs[[runA]], unlist(chromIndices.A))
  cons[[2]] <- createTemp(mzPntrs[[runB]], unlist(chromIndices.B))

  ##### Get child XICs for the batch from both runs #####
  cluster <- applyFun(strt:stp, function(rownum){
    peptide <- peptides[rownum]
    idx <- (rownum - (iBatch-1)*batchSize)
    ##### Get XIC_group from runA and runB. If missing, add NULL #####
    cI.A <- chromIndices.A[[idx]]
    cI.B <- chromIndices.B[[idx]]
    nope <- any(is.na(c(unlist(cI.A), unlist(cI.B))))
    nope <- nope | is.null(unlist(cI.A)) | is.null(unlist(cI.B))
    if(nope) {
      warning("Chromatogram indices for ", peptide, " are missing.")
      message("Skipping peptide ", peptide, ".")
      return(list(vector(mode = "list", length = length(analytes[[idx]])), NULL))
    }
    XICs.A <- lapply(cI.A, function(i1) fetchXIC(cons[[1]], i1))
    XICs.B <- lapply(cI.B, function(i1) fetchXIC(cons[[2]], i1))
    names(XICs.A) <- names(XICs.B) <- as.character(analytes[[idx]])

    ##### Calculate the weights of XICs from runA and runB #####
    temp <- peptideScores[[rownum]]
    pA <- temp$pvalue[which(temp$run == runA)]
    pB <- temp$pvalue[which(temp$run == runB)]
    wA <- ifelse(length(pA) == 0 || is.na(pA), 0.004, -log10(pA)) # || allows short-circuit
    wB <- ifelse(length(pB) == 0 || is.na(pB), 0.004, -log10(pB)) # || allows short-circuit
    wA <- wA/(wA + wB)

    ##### Decide the reference run from runA and runB. #####
    if(.subset2(refRun, 1L)[[rownum]] == 1L){
      XICs.ref <- XICs.A
      XICs.eXp <- XICs.B
      globalFit <- globalFit1
      adaptiveRT <- adaptiveRT1
      wRef <- wA
    } else{
      XICs.ref <- XICs.B
      XICs.eXp <- XICs.A
      globalFit <- globalFit2
      adaptiveRT <- adaptiveRT2
      wRef <- (1-wA)
    }

    ##### Select 1) all precursors OR 2) high quality precursor. #####
    analytes_chr <- names(XICs.A)
    analyte_chr <- .subset2(refRun, 2L)[[rownum]]
    if(FALSE){
      # Turned off as precursor XICs have different time ranges.
      XICs.ref.pep <- unlist(XICs.ref, recursive = FALSE, use.names = FALSE)
      XICs.eXp.pep <- unlist(XICs.eXp, recursive = FALSE, use.names = FALSE)
    } else {
      XICs.ref.pep <- XICs.ref[[analyte_chr]]
      XICs.eXp.pep <- XICs.eXp[[analyte_chr]]
    }

    nope <- is.null(XICs.ref.pep) || is.null(XICs.eXp.pep)
    nope <- nope || any(sapply(seq_along(XICs.ref.pep), function(i) any(is.na(XICs.ref.pep[[i]])))) ||
            any(sapply(seq_along(XICs.eXp.pep), function(i) any(is.na(XICs.eXp.pep[[i]]))))
    if(nope){
      message("Missing values in the chromatogram of ", paste0(analytes_chr, sep = " "), "in ",
              runA, " or ", runB)
      return(list(vector(mode = "list", length = length(analytes_chr)), NULL)) # Missing values in chromatogram
    }
    Bp <- getPredict(globalFit, XICs.ref.pep[[1]][,1], params[["globalAlignment"]])
    if(any(is.na(Bp) | Bp <=0 | is.nan(Bp))){
      Bp <- seq(XICs.eXp.pep[[1]][1,1], XICs.eXp.pep[[1]][nrow(XICs.eXp.pep[[1]]),1], length.out = length(Bp))
    }

    #### Merge chromatograms  ####
    merged_xics <- getChildXICpp(XICs.ref.pep, XICs.eXp.pep, params[["kernelLen"]], params[["polyOrd"]],
                  params[["alignType"]], adaptiveRT, params[["normalization"]],
                  params[["simMeasure"]], Bp, params[["goFactor"]], params[["geFactor"]],
                  params[["cosAngleThresh"]], params[["OverlapAlignment"]],
                  params[["dotProdThresh"]], params[["gapQuantile"]], params[["kerLen"]],
                  params[["hardConstrain"]], params[["samples4gradient"]], wRef,
                  params[["splineMethod"]], params[["mergeTime"]], params[["keepFlanks"]])
    if(is.null(merged_xics[[1]])) return(list(vector(mode = "list", length = length(analytes_chr)), NULL))
    merged_xics[[1]] <- list(merged_xics[[1]])
    names(merged_xics[[1]]) <- analyte_chr
    otherPrecs <- setdiff(analytes_chr, analyte_chr)
    if(length(otherPrecs) !=0){
      for(name in otherPrecs){
        # Check for NaN, NA or NULL
        nope <- is.null(XICs.ref[[name]]) || is.null(XICs.eXp[[name]])
        nope <- nope || any(sapply(seq_along(XICs.ref[[name]]), function(i) any(is.na(XICs.ref[[name]][[i]])))) ||
          any(sapply(seq_along(XICs.eXp[[name]]), function(i) any(is.na(XICs.eXp[[name]][[i]]))))
        if(nope){
          merged_xics[[1]][name] <- list(NULL)
        } else{
          merged_xics[[1]][[name]] <- otherChildXICpp(XICs.ref[[name]], XICs.eXp[[name]], 0L,
              params[["polyOrd"]], merged_xics[[2]], merged_xics[[1]][[1]][[1]][,1],
              wRef, params[["splineMethod"]])
        }
      }
    }
    merged_xics[[1]] <- merged_xics[[1]][match(analytes_chr, names(merged_xics[[1]]))]
    merged_xics # 1st element has list of precursors. 2nd element has aligned time vectors.
  })
  for(con in cons) DBI::dbDisconnect(con)
  cluster
}
