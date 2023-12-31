#' Outputs intensities for each analyte from aligned Targeted-MS runs
#'
#' This function expects osw and xics directories at dataPath. It first reads osw files and fetches chromatogram indices for each analyte.
#' It then align XICs of its reference XICs. Best peak, which has lowest m-score, about the aligned retention time is picked for quantification.
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2019) + GPL-3
#' Date: 2019-12-14
#' @importFrom data.table data.table setkeyv
#' @inheritParams checkParams
#' @param dataPath (string) path to xics and osw directory.
#' @param outFile (string) name of the output file.
#' @param oswMerged (logical) TRUE if merged file from pyprophet is used.
#' @param scoreFile (string) path to the peptide score file, needed when oswMerged is FALSE.
#' @param runs (string) names of xics file without extension.
#' @param peps (integer) ids of peptides to be aligned. If NULL, align all peptides.
#' @param refRun (string) reference for alignment. If no run is provided, m-score is used to select reference run.
#' @param applyFun (function) value must be either lapply or BiocParallel::bplapply.
#' @param saveAlignedPeaks (logical) Save a mapping table to track aligned feature ids against reference feature id
#' @return An output table with following columns: precursor, run, intensity, RT, leftWidth, rightWidth,
#'  peak_group_rank, m_score, alignment_rank, peptide_id, sequence, charge, group_label.
#'
#' @seealso \code{\link{getRunNames}, \link{getFeatures}, \link{setAlignmentRank}, \link{getMultipeptide}}
#' @examples
#' params <- paramsDIAlignR()
#' params[["context"]] <- "experiment-wide"
#' dataPath <- system.file("extdata", package = "DIAlignR")
#' BiocParallel::register(BiocParallel::MulticoreParam(workers = 4, progressbar = TRUE))
#' alignTargetedRuns(dataPath, outFile = "testDIAlignR", params = params, applyFun = BiocParallel::bplapply)
#' @references Gupta S, Ahadi S, Zhou W, Röst H. "DIAlignR Provides Precise Retention Time Alignment Across Distant Runs in DIA and Targeted Proteomics." Mol Cell Proteomics. 2019 Apr;18(4):806-817. doi: https://doi.org/10.1074/mcp.TIR118.001132 Epub 2019 Jan 31.
#'
#' @export
alignTargetedRuns <- function(dataPath, outFile = "DIAlignR", params = paramsDIAlignR(), oswMerged = TRUE,
                              scoreFile = NULL, runs = NULL, peps = NULL, refRun = NULL, applyFun = lapply,
                              saveAlignedPeaks = FALSE){
  #### Check if all parameters make sense.  #########
  params <- checkParams(params)

  #### Get filenames from .osw file and check consistency between osw and mzML files. #################
  fileInfo <- getRunNames(dataPath, oswMerged, params)
  fileInfo <- updateFileInfo(fileInfo, runs)
  runs <- rownames(fileInfo)
  fileInfo2 <- data.frame(fileInfo)
  if(!oswMerged) fileInfo2[["featureFile"]] <- scoreFile
  message("Following runs will be aligned:")
  print(fileInfo[, "runName"], sep = "\n")

  #### Get Precursors from the query and respectve chromatogram indices. ######
  # Get all the precursor IDs, transition IDs, Peptide IDs, Peptide Sequence Modified, Charge.
  start_time <- Sys.time()
  precursors <- getPrecursors(fileInfo2, oswMerged, params[["runType"]], params[["context"]], params[["maxPeptideFdr"]], params[["level"]], params[["useIdentifying"]])
  if(!is.null(peps)){
    precursors <- precursors[peptide_id %in% peps, ]
    if(nrow(precursors) == 0L) stop("No peptide IDs are found in osw files.")
    setkeyv(precursors, c("peptide_id", "transition_group_id"))
  }
  if(params[["fractionNum"]] > 1L){
    idx <- getPrecursorSubset(precursors, params)
    precursors <- precursors[idx[1]:idx[2],]
    setkeyv(precursors, c("peptide_id", "transition_group_id"))
    outFile <- paste(outFile, params[["fraction"]], params[["fractionNum"]], sep = "_")
  }
  outFile <- paste0(outFile,".tsv")
  end_time <- Sys.time()
  message("The execution time for getting precursors:")
  print(end_time - start_time)

  #### Get Peptide scores, pvalue and qvalues. ######
  # Some peptides may not be found due to using a subset of runs. Appends NA for them.
  # This translates as "Chromatogram indices for peptide ID are missing in NA"
  start_time <- Sys.time()
  peptideIDs <- precursors[, logical(1), keyby = peptide_id]$peptide_id
  peptideScores <- getPeptideScores(fileInfo2, peptideIDs, oswMerged, params[["runType"]], params[["context"]])
  peptideScores <- lapply(peptideIDs, function(pep) peptideScores[.(pep)])
  names(peptideScores) <- as.character(peptideIDs)
  end_time <- Sys.time()
  message("The execution time for fetching peptide scores:")
  print(end_time - start_time)

  #### Get reference run for each precursor ########
  start_time <- Sys.time()
  idx <- which(fileInfo$runName == refRun)
  if(length(idx) == 0){
    message("Calculating reference run for each peptide.")
    refRuns <- getRefRun(peptideScores)
  } else{
    run <- rownames(fileInfo)[idx]
    refRuns <- data.table("peptide_id" = peptideIDs, "run" = run, key = "peptide_id")
  }
  end_time <- Sys.time()
  message("The execution time for calculating a reference run:")
  print(end_time - start_time)
  rm(peptideScores)

  #### Get OpenSWATH peak-groups and their retention times. ##########
  start_time <- Sys.time()
  if(params[["transitionIntensity"]]){
    features <- getTransitions(fileInfo, params[["maxFdrQuery"]], params[["runType"]], applyFun)
  } else{
    features <- getFeatures(fileInfo, params[["maxFdrQuery"]], params[["maxIPFFdrQuery"]], params[["runType"]], applyFun)
  }
  end_time <- Sys.time()
  message("The execution time for fetching features:")
  print(end_time - start_time)

  #### Collect pointers for each mzML file. #######
  start_time <- Sys.time()
  message("Collecting metadata from mzML files.")
  mzPntrs <- getMZMLpointers(fileInfo)
  message("Metadata is collected from mzML files.")
  end_time <- Sys.time()
  message("The execution time for getting pointers:")
  print(end_time - start_time)

  #### Get chromatogram Indices of precursors across all runs. ############
  message("Collecting chromatogram indices for all precursors.")
  start_time <- Sys.time()
  prec2chromIndex <- getChromatogramIndices(fileInfo, precursors, mzPntrs, applyFun)
  end_time <- Sys.time()
  message("The execution time for getting chromatogram indices:")
  print(end_time - start_time)

  #### Convert features into multi-peptide #####
  message("Building multipeptide.")
  start_time <- Sys.time()
  multipeptide <- getMultipeptide(precursors, features, params[["runType"]], applyFun, NULL)
  message(length(multipeptide), " peptides are in the multipeptide.")
  end_time <- Sys.time()
  message("The execution time for building multipeptide:")
  print(end_time - start_time)

  #### Create a mapping for reference-experiment aligned features #####
  if ( saveAlignedPeaks )
  {
    multiFeatureAlignmentMap <- getRefExpFeatureMap(precursors, features, applyFun=lapply)
  }
  else
  {
    multiFeatureAlignmentMap <- NULL
  }
  #### Container to save Global alignments.  #######
  message("Calculating global alignments.")
  start_time <- Sys.time()
  globalFits <- getGlobalFits(refRuns, features, fileInfo, params[["globalAlignment"]],
                              params[["globalAlignmentFdr"]], params[["globalAlignmentSpan"]], applyFun)
  RSE <- applyFun(globalFits, getRSE, params[["globalAlignment"]])
  globalFits <- applyFun(globalFits, extractFit, params[["globalAlignment"]])
  rm(features)
  end_time <- Sys.time()
  message("The execution time for calculating global alignment:")
  print(end_time - start_time)

  # TODO: Check dimensions of multipeptide, PeptideIDs, precursors etc makes sense.
  #### Perform pairwise alignment ###########
  message("Performing reference-based alignment.")
  start_time <- Sys.time()
  num_of_batch <- ceiling(length(multipeptide)/params[["batchSize"]])
  invisible(
    lapply(1:num_of_batch, perBatch, peptideIDs, multipeptide, refRuns, precursors,
           prec2chromIndex, fileInfo, mzPntrs, params, globalFits, RSE, lapply, multiFeatureAlignmentMap)
  )

  #### Cleanup.  #######
  for(mz in mzPntrs){
    if(is(mz)[1] == "SQLiteConnection") DBI::dbDisconnect(mz)
    if(is(mz)[1] == "mzRpwiz") rm(mz)
  }
  rm(prec2chromIndex, globalFits, RSE)

  end_time <- Sys.time() # Report the execution time for hybrid alignment step.
  message("The execution time for alignment:")
  print(end_time - start_time)

  #### Write tables to the disk  #######
  finalTbl <- writeTables(fileInfo, multipeptide, precursors)
  if(params[["transitionIntensity"]]){
    finalTbl[,intensity := sapply(intensity,function(x) paste(round(x, 3), collapse=", "))]
  }
  if(params[["runType"]]=="DIA_IPF"){
    finalTbl <- ipfReassignFDR(finalTbl, refRuns, fileInfo, params)
  }
  utils::write.table(finalTbl, file = outFile, sep = "\t", row.names = FALSE, quote = FALSE)

  #### Write Reference-Experiment Feature Alignment mapping to disk
  if (saveAlignedPeaks){
    writeOutFeatureAlignmentMap(multiFeatureAlignmentMap, oswMerged, fileInfo)
  }

  message("Retention time alignment across runs is done.")
  message(paste0(outFile, " file has been written."))

  #### Cleanup.  #######
  rm(refRuns)

  #### Write alignment summary  #######
  alignmentStats(finalTbl, params)
}

#' AlignObj for analytes between a pair of runs
#'
#' This function expects osw and xics directories at dataPath. It first reads osw files and fetches chromatogram indices for each requested analyte.
#' It then align XICs of each analyte to its reference XICs. AlignObj is returned which contains aligned indices and cumulative score along the alignment path.
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2019) + GPL-3
#' Date: 2019-12-14
#' @importFrom rlang .data
#' @inheritParams alignTargetedRuns
#' @param analytes (vector of integers) transition_group_ids for which features are to be extracted.
#' @param objType (char) Must be selected from light, medium and heavy.
#' @return A list of fileInfo and AlignObjs. Each AlignObj is an S4 object. Three most-important slots are:
#' \item{indexA_aligned}{(integer) aligned indices of reference run.}
#' \item{indexB_aligned}{(integer) aligned indices of experiment run.}
#' \item{score}{(numeric) cumulative score of alignment.}
#' @seealso \code{\link{plotAlignedAnalytes}, \link{getRunNames}, \link{getFeatures}, \link{getXICs4AlignObj}, \link{getAlignObj}}
#' @examples
#' dataPath <- system.file("extdata", package = "DIAlignR")
#' params <- paramsDIAlignR()
#' params[["context"]] <- "experiment-wide"
#' runs <- c("hroest_K120808_Strep10%PlasmaBiolRepl1_R03_SW_filt",
#'  "hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt",
#'  "hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt")
#' analytes <- c(32L, 898L, 2474L)
#' AlignObjOutput <- getAlignObjs(analytes, runs, dataPath = dataPath)
#' plotAlignedAnalytes(AlignObjOutput)
#'
#' @references Gupta S, Ahadi S, Zhou W, Röst H. "DIAlignR Provides Precise Retention Time Alignment Across Distant Runs in DIA and Targeted Proteomics." Mol Cell Proteomics. 2019 Apr;18(4):806-817. doi: https://doi.org/10.1074/mcp.TIR118.001132 Epub 2019 Jan 31.
#'
#' @export
getAlignObjs <- function(analytes, runs, dataPath = ".", refRun = NULL, oswMerged = TRUE,
                         params = paramsDIAlignR(), objType = "light"){
  #### Check if all parameters make sense.  #########
  checkParams(params)

  ##### Get filenames from osw files and check if names are consistent between osw and mzML files. ######
  filenames <- getRunNames(dataPath, oswMerged, params)
  filenames <- updateFileInfo(filenames, runs)
  missingRun <- setdiff(runs, filenames$runName)
  if(length(missingRun) != 0){
    return(stop(missingRun, " runs are not found."))
  }
  message("Following runs will be aligned:")
  print(filenames[, "runName"], sep = "\n")

  ######### Collect pointers for each mzML file. #######
  message("Collecting metadata from mzML files.")
  mzPntrs <- getMZMLpointers(filenames)
  message("Metadata is collected from mzML files.")

  ######### Get Precursors from the query and respectve chromatogram indices. ######
  precursors <- getPrecursorByID(analytes, filenames)

  #### Precursors for which features are identified. ##############
  features <- getFeatures(filenames, params[["maxFdrQuery"]], params[["runType"]])

  ###### Report analytes that are not found ########
  refAnalytes <- analytesFromFeatures(features, analyteFDR = params[["analyteFDR"]], commonAnalytes = FALSE)
  analytesFound <- intersect(analytes, refAnalytes)
  analytesNotFound <- setdiff(analytes, analytesFound)
  if(length(analytesNotFound)>0){
    message(paste(analytesNotFound, "not found with FDR cut-off."))
  }
  analytes <- analytesFound
  precursors <- precursors[precursors[["transition_group_id"]] %in% analytes, ]
  if(nrow(precursors) == 0){
    stop("No precursors are found below ", params[["analyteFDR"]])
  }

  ############# Get chromatogram Indices of precursors across all runs. ############
  prec2chromIndex <- getChromatogramIndices(filenames, precursors, mzPntrs)

  #### Get Peptide scores, pvalue and qvalues. ######
  peptideIDs <- unique(precursors$peptide_id)
  peptideScores <- getPeptideScores(filenames, peptideIDs, oswMerged, params[["runType"]], params[["context"]])
  peptideScores <- lapply(peptideIDs, function(pep) dplyr::filter(peptideScores, .data$peptide_id == pep))
  names(peptideScores) <- as.character(peptideIDs)

  ############## Get reference run for each precursor ########
  idx <- which(filenames$runName == refRun)
  if(length(idx) == 0){
    print("Finding reference run using SCORE_PEPTIDE table")
    refRun <- data.frame("transition_group_id" = precursors$transition_group_id,
                         "run" = NA_character_)
    temp <- getRefRun(peptideScores)
    refRun$run <- temp$run[match(precursors$peptide_id, temp$peptide_id)]
  } else{
    run <- rownames(filenames)[idx]
    refRun <- data.frame("transition_group_id" = precursors$transition_group_id,
                            "run" = run)
  }

  ####################### Get XICs ##########################################
  # Get Chromatogram for each peptide in each run.
  message("Fetching Extracted-ion chromatograms from runs")
  XICs <- getXICs4AlignObj(mzPntrs, filenames, filenames[, "runName"], prec2chromIndex, analytes)
  for(mz in mzPntrs){
    if(is(mz)[1] == "SQLiteConnection") DBI::dbDisconnect(mz)
    if(is(mz)[1] == "mzRpwiz") rm(mz)
  }

  ####################### Perfrom alignment ##########################################
  AlignObjs <- vector("list", length(analytes))
  globalFits <- list()
  RSE <- list()
  runs <- rownames(filenames)
  message("Perfroming alignment")
  for(analyteIdx in seq_along(analytes)){
    analyte <- as.character(analytes[analyteIdx])
    ref <- refRun[["run"]][analyteIdx]
    AlignObjs[[analyteIdx]] <- list()

    # Get XIC_group from reference run
    XICs.ref <- XICs[[filenames[ref,"runName"]]][[analyte]]
    if(is.null(XICs.ref)){
      warning("Chromatogram indices for ", analyte, " are missing in ", filenames[ref, "runName"])
      message("Skipping ", analyte)
      AlignObjs[[analyteIdx]] <- NULL
      next
    }
    XICs.ref.s <- smoothXICs(XICs.ref, type = params[["XICfilter"]], kernelLen = params[["kernelLen"]],
                             polyOrd = params[["polyOrd"]])
    exps <- setdiff(runs, ref)

    # Align experiment run to reference run
    for(eXp in exps){
      pair <- paste(ref, eXp, sep = "_")
      AlignObjs[[analyteIdx]][[pair]] <- list()
      # Get XIC_group from experiment run
      XICs.eXp <- XICs[[filenames[eXp,"runName"]]][[analyte]]
      if(is.null(XICs.eXp)){
        warning("Chromatogram indices for ", analyte, " are missing in ", filenames[eXp, "runName"])
        message("Skipping ", analyte)
        AlignObjs[[analyteIdx]][[pair]] <- NULL
        next
      }
      XICs.eXp.s <- smoothXICs(XICs.eXp, type = params[["XICfilter"]], kernelLen = params[["kernelLen"]],
                               polyOrd = params[["polyOrd"]])
      # Get the loess fit for hybrid alignment
      if(any(pair %in% names(globalFits))){
        globalFit <- globalFits[[pair]]
      } else{
        globalFit <- getGlobalAlignment(features, ref, eXp, params[["globalAlignment"]],
                                        params[["globalAlignmentFdr"]], params[["globalAlignmentSpan"]])
        RSE[[pair]] <- getRSE(globalFit, params[["globalAlignment"]])
        globalFits[[pair]] <- extractFit(globalFit, params[["globalAlignment"]])
      }
      adaptiveRT <- params[["RSEdistFactor"]]*RSE[[pair]]

      # Fetch alignment object between XICs.ref and XICs.eXp
      AlignObj <- getAlignObj2(XICs.ref.s, XICs.eXp.s, globalFits[[pair]], adaptiveRT, params, objType)
      # Attach AlignObj for the analyte.
      AlignObjs[[analyteIdx]][[pair]][["AlignObj"]] <- AlignObj
      # Attach intensities of reference XICs.
      AlignObjs[[analyteIdx]][[pair]][["ref"]] <- XICs.ref
      # Attach intensities of experiment XICs.
      AlignObjs[[analyteIdx]][[pair]][["eXp"]] <- XICs.eXp
      # Attach peak boundaries to the object.
      AlignObjs[[analyteIdx]][[pair]][["peak"]] <- features[[ref]] %>%
        dplyr::filter(.data$transition_group_id == as.integer(analyte) & .data$peak_group_rank == 1) %>%
        dplyr::select(.data$leftWidth, .data$RT, .data$rightWidth) %>%
        as.vector()
    }
  }
  names(AlignObjs) <- as.character(analytes)

  ####################### Return AlignedObjs ##########################################
  message("Alignment done. Returning AlignObjs")
  list(filenames, AlignObjs)
}


#' Aligns an analyte across runs
#'
#' For the ith analyte in multipeptide, this function aligns all runs to the reference run. The result is
#' a dataframe that contains aligned features corresponding to the analyte across all runs.
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2020) + GPL-3
#' Date: 2020-07-26
#' @keywords internal
#' @importFrom data.table set
#' @inheritParams checkParams
#' @param rownum (integer) represnts the index of the multipepetide to be aligned.
#' @param peptides (integer) vector of peptide IDs.
#' @param multipeptide (list) contains multiple data-frames that are collection of features
#'  associated with analytes. This is an output of \code{\link{getMultipeptide}}.
#' @param refRuns (data-frame) output of \code{\link{getRefRun}}. Must have two columsn : transition_group_id and run.
#' @param precursors (data-frame) atleast two columns transition_group_id and transition_ids are required.
#' @param prec2chromIndex (list) a list of dataframes having following columns: \cr
#' transition_group_id: it is PRECURSOR.ID from osw file. \cr
#' chromatogramIndex: index of chromatogram in mzML file.
#' @param fileInfo (data-frame) output of \code{\link{getRunNames}}.
#' @param mzPntrs (list) a list of mzRpwiz.
#' @param globalFits (list) each element is either of class lm or loess. This is an output of \code{\link{getGlobalFits}}.
#' @param RSE (list) Each element represents Residual Standard Error of corresponding fit in globalFits.
#' @param multiFeatureAlignmentMap (list) contains multiple data-frames that are collection of experiment feature ids
#' mapped to corresponding reference feature id per analyte. This is an output of \code{\link{getRefExpFeatureMap}}.
#' @return invisible NULL
#' @seealso \code{\link{alignTargetedRuns}, \link{alignToRef}, \link{getAlignedTimesFast}, \link{getMultipeptide}}
#' @examples
#' dataPath <- system.file("extdata", package = "DIAlignR")
perBatch <- function(iBatch, peptides, multipeptide, refRuns, precursors, prec2chromIndex,
                     fileInfo, mzPntrs, params, globalFits, RSE, applyFun = lapply, multiFeatureAlignmentMap = NULL){
  # if(params[["chromFile"]] =="mzML") fetchXIC = extractXIC_group
  fetchXICs = extractXIC_group2
  message("Processing Batch ", iBatch)
  batchSize <- params[["batchSize"]]
  strt <- ((iBatch-1)*batchSize+1)
  stp <- min((iBatch*batchSize), length(peptides))
  runs <- rownames(fileInfo)

  ##### Get XICs into memory for the batch across all runs #####
  pIdx <- lapply(peptides[strt:stp], function(pep) which(precursors$peptide_id == pep))
  analytesA <- lapply(pIdx, function(i) .subset2(precursors, "transition_group_id")[i])
  chromIndices <- lapply(runs, function(run) lapply(pIdx, function(i) .subset2(prec2chromIndex[[run]], "chromatogramIndex")[i]))
  cons <- lapply(seq_along(runs), function(i) createTemp(mzPntrs[[runs[i]]], unlist(chromIndices[[i]])))
  names(cons) <- names(chromIndices) <- runs

  ##### Get aligned multipeptide for the batch #####
  invisible(applyFun(strt:stp, function(rownum){
    peptide <- peptides[rownum]
    DT <- multipeptide[[rownum]]
    ref <- refRuns[rownum, "run"][[1]]
    idx <- (rownum - (iBatch-1)*batchSize)
    analytes <- analytesA[[idx]]
    if ( is.null(multiFeatureAlignmentMap) )
    {
      feature_alignment_map <- NULL
    }
    else
    {
      feature_alignment_map <- multiFeatureAlignmentMap[[rownum]]
    }

    XICs <- lapply(seq_along(runs), function(i){
      cI <- chromIndices[[i]][[idx]]
      if(any(is.na(unlist(cI))) | is.null(unlist(cI))) return(NULL)
      temp <- lapply(cI, function(i1) fetchXICs(cons[[i]], i1))
      names(temp) <- as.character(analytes)
      temp
    })
    names(XICs) <- runs

    XICs.ref <- XICs[[ref]]
    if(is.null(XICs.ref) || any(vapply(XICs.ref, missingInXIC, FALSE, USE.NAMES = FALSE))){
      message("Chromatogram indices for peptide ", peptide, " are missing in ", fileInfo[ref, "runName"])
      message("Skipping peptide ", peptide, " across all runs.")
      return(invisible(NULL))
    }

    ##### Set alignment rank for all precrusors of the peptide in the reference run #####
    if(!any(DT[["run"]] == ref & DT[["alignment_rank"]] == 1L, na.rm = TRUE)){
      analytes <- as.integer(names(XICs.ref))
      refIdx <- which(DT[["run"]] == ref & DT[["peak_group_rank"]] == 1L)
      refIdx <- refIdx[which.min(DT$m_score[refIdx])]
      if(length(refIdx)==0) {
        message("Features for peptide ", peptide, " is missing in ", fileInfo[ref, "runName"])
        message("Skipping peptide ", peptide, " across all runs.")
        return(invisible(NULL))
      }
      set(DT, i = refIdx, 10L, 1L)
      setOtherPrecursors(DT, refIdx, XICs.ref, analytes, params)
    } else{
      refIdx <- which(DT[["run"]] == ref & DT[["alignment_rank"]] == 1L)
      refIdx <- refIdx[which.min(DT$m_score[refIdx])]
    }

    ##### Align all runs to reference run and set their alignment rank #####
    exps <- setdiff(rownames(fileInfo), ref)
    invisible(
      lapply(exps,  alignToRef, ref, refIdx, fileInfo, XICs, XICs.ref, params,
             DT, globalFits, RSE, feature_alignment_map)
    )

    ##### Return the dataframe with alignment rank set to TRUE #####
    updateOnalignTargetedRuns(rownum)
  })
  )
  for(con in cons) DBI::dbDisconnect(con)
  invisible(NULL)
}

#' Aligns an analyte from an experiment to the reference run
#'
#' df contains unaligned features for an analyte across multiple runs. This function aligns eXp run to
#' ref run and updates corresponding features.
#'
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2020) + GPL-3
#' Date: 2020-07-26
#' @keywords internal
#' @inheritParams perBatch
#' @inherit perBatch return
#' @param eXp (string) name of the run to be aligned to reference run. Must be in the rownames of fileInfo.
#' @param ref (string) name of the reference run. Must be in the rownames of fileInfo.
#' @param refIdx (integer) index of the reference feature in df.
#' @param XICs (list of dataframes) fragment-ion chromatograms of the analytes for all runs.
#' @param XICs.ref (list of dataframes) fragment-ion chromatograms of the analyte_chr from the reference run.
#' @param df (dataframe) a collection of features related to the peptide
#' @param feature_alignment_mapping (data.table)  contains experiment feature ids
#' mapped to corresponding reference feature id per analyte. This is an output of \code{\link{getRefExpFeatureMap}}.
#' @seealso \code{\link{alignTargetedRuns}, \link{perBatch}, \link{setAlignmentRank}, \link{getMultipeptide}, \link{getRefExpFeatureMap}}
#' @examples
#' dataPath <- system.file("extdata", package = "DIAlignR")
alignToRef <- function(eXp, ref, refIdx, fileInfo, XICs, XICs.ref, params,
                       df, globalFits, RSE, feature_alignment_map=NULL){
  # Get XIC_group from experiment run.
  XICs.eXp <- XICs[[eXp]]
  analytes <- as.integer(names(XICs.ref))
  eXpIdx <- which(df[["run"]] == eXp)
  ##### Check if any feature is below unaligned FDR. If present alignment_rank = 1. #####
  if(any(.subset2(df, "m_score")[eXpIdx] <=  params[["unalignedFDR"]], na.rm = TRUE)){
    tempi <- eXpIdx[which.min(df$m_score[eXpIdx])]
    set(df, tempi, 10L, 1L)
    if(is.null(XICs.eXp)) return(invisible(NULL))
    setOtherPrecursors(df, tempi, XICs.eXp, analytes, params)
    return(invisible(NULL))
  }

  # No high quality feature, hence, alignment is needed.
  ### if XICs are missing, go to next run. ####
  if(is.null(XICs.eXp)){
    message("Chromatogram indices for precursor ", analytes, " are missing in ", fileInfo[eXp, "runName"])
    message("Skipping precursor ", analytes, " in ", fileInfo[eXp, "runName"], ".")
    return(invisible(NULL))
  }

  # Select 1) all precursors OR 2) high quality precursor
  if(FALSE){
    # Turned off as precursor XICs have different time ranges.
    XICs.ref.pep <- unlist(XICs.ref, recursive = FALSE, use.names = FALSE)
    XICs.eXp.pep <- unlist(XICs.eXp, recursive = FALSE, use.names = FALSE)
  } else {
    analyte_chr <- as.character(.subset2(df, 1L)[[refIdx]])
    XICs.ref.pep <- XICs.ref[[analyte_chr]]
    XICs.eXp.pep <- XICs.eXp[[analyte_chr]]
  }

  ##### Get the aligned Indices #####
  pair <- paste(ref, eXp, sep = "_")
  globalFit <- globalFits[[pair]]
  adaptiveRT <- params[["RSEdistFactor"]]*RSE[[pair]]

  if(missingInXIC(XICs.eXp.pep)){
    message("Missing values in the chromatogram of ", paste0(analytes, sep = " "), "precursors in run ",
             fileInfo[eXp, "runName"])
    return(invisible(NULL)) # Missing values in chromatogram
  }

  tAligned <- tryCatch(expr = getAlignedTimesFast(XICs.ref.pep, XICs.eXp.pep, globalFit, adaptiveRT,
                                                  params),
             error = function(e){
             message("\nError in the alignment of ", paste0(analytes, sep = " "), "precursors in runs ",
                     fileInfo[ref, "runName"], " and ", fileInfo[eXp, "runName"])
             warning(e)
             return(NULL)
           })
  if(is.null(tAligned)) return(invisible(NULL))
  tryCatch(expr = setAlignmentRank(df, refIdx, eXp, tAligned, XICs.eXp, params, adaptiveRT),
             error = function(e){
             message("\nError in setting alignment rank of ", paste0(analytes, sep = " "), "precursors in runs ",
                     fileInfo[eXp, "runName"], " and ", fileInfo[eXp, "runName"])
             warning(e)
             return(invisible(NULL))
           })

  tempi <- eXpIdx[which(df$alignment_rank[eXpIdx] == 1L)]
  if(length(tempi) == 0L) return(invisible(NULL))
  setOtherPrecursors(df, tempi, XICs.eXp, analytes, params)
  if (not_null(feature_alignment_map))
  {
    # NOTE: This assumes the highest quality precursor is used, i.e. analyte_chr is defined
    populateReferenceExperimentFeatureAlignmentMap(df, feature_alignment_map, tAligned, ref, eXp, analyte_chr)
  }
  invisible(NULL)
}
