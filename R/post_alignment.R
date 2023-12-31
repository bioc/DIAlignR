#' Pick feature closest to reference peak
#'
#' It picks a feature that is within adaptiveRT window across eXpRT and has lowest m-score.
#' Feature's m-score also has to be smaller than featureFDR.
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2019) + GPL-3
#' Date: 2019-12-13
#' @param eXpRT (numeric) retention time in experiment run.
#' @param analyte (integer) vector of precursor IDs.
#' @param oswFiles (list of data-frames) it is output from getFeatures function.
#' @param runname (string) must be a combination of "run" and an iteger e.g. "run2".
#' @param adaptiveRT (numeric) half-width of retention time window. Feature, if found, is picked from within this window.
#' @param featureFDR (numeric) upper m-score cut-off for a feature to be picked.
#' @return (list) Following elements are present in the list:
#' \item{leftWidth}{(numeric) as in FEATURE.LEFT_WIDTH of osw files.}
#' \item{rightWidth}{(numeric) as in FEATURE.RIGHT_WIDTH of osw files.}
#' \item{RT}{(numeric) retention time as in FEATURE.EXP_RT of osw files.}
#' \item{Intensity}{(numeric) peak intensity as in FEATURE_MS2.AREA_INTENSITY of osw files.}
#' \item{peak_group_rank}{(integer) rank of each feature associated with transition_group_id.}
#' \item{m_score}{(numeric) q-value of each feature associated with transition_group_id.}
#'
#' @seealso \code{\link{getFeatures}}
#' @keywords internal
#' @examples
#' data(oswFiles_DIAlignR, package="DIAlignR")
#' \dontrun{
#' pickNearestFeature(eXpRT = 5237.8, analyte = 4618L, oswFiles = oswFiles_DIAlignR,
#'  runname = "run2", adaptiveRT = 77.82315, featureFDR = 0.05)
#' }
pickNearestFeature <- function(eXpRT, analyte, oswFiles, runname, adaptiveRT, featureFDR){
  # Fetch features for an analyte.
  df <- oswFiles[[runname]] %>% dplyr::filter(.data$transition_group_id == analyte) %>%
    dplyr::select('leftWidth', 'rightWidth', 'RT', 'intensity', 'peak_group_rank', 'm_score')
  # select features which are within adaptive RT of mapped retention time.
  df <- df %>% dplyr::filter(abs(.data$RT - eXpRT) <= adaptiveRT)
  # select highest peak_group_rank feature.
  df <- df %>% dplyr::filter(.data$m_score < featureFDR & .data$peak_group_rank == min(.data$peak_group_rank))
  if(df %>% nrow() == 0){
    return(NULL)
  }
  df <-  df %>% as.list()
  df
}


#' Establishes mapping from index to time
#'
#' Takes a time vector and index vector of same length. This function create a
#' new time vector given indices specified in \code{idx}.
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2019) + GPL-3
#' Date: 2019-12-13
#' @param timeVec A numeric vector
#' @param idx An integer vector
#' @return A mutated time vector
#' @examples
#' timeVec <- c(1.3,5.6,7.8)
#' idx <- c(NA, NA, 1L, 2L, NA, NA, 3L, NA)
#' mapIdxToTime(timeVec, idx) # c(NA, NA, 1.3, 5.6, 6.333, 7.067, 7.8, NA)
#'
#' @importFrom zoo na.approx
#' @export
mapIdxToTime <- function(timeVec, idx){
  mutateT <- na.approx(timeVec[idx], na.rm = FALSE)
  return(mutateT)
}


#' Map reference run time on the experiment run.
#'
#' Retention time from reference run is mapped to experiment run using AlignObj.
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2019) + GPL-3
#' Date: 2019-12-13
#'
#' @param refRT (numeric) retention time in reference run.
#' @param tVec.ref (numeric) time vector of refernce run.
#' @param tVec.eXp (numeric) time vector of experiment run.
#' @param AlignObj (S4 object) must have indexA_aligned, indexB_aligned and score as slots.
#' @return (numeric)
#' @keywords internal
#' @examples
#' data(XIC_QFNNTDIVLLEDFQK_3_DIAlignR, package="DIAlignR")
#' tVec.ref <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR[["hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]][[1]][, "time"]
#' tVec.eXp <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR[["hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]][[1]][, "time"]
#' \dontrun{
#' AlignObj <- testAlignObj()
#' mappedRTfromAlignObj(refRT= 5238.35, tVec.ref, tVec.eXp, AlignObj)
#' }
mappedRTfromAlignObj <- function(refRT, tVec.ref, tVec.eXp, AlignObj){
  AlignedIndices <- cbind(slot(AlignObj, "indexA_aligned"),
                          slot(AlignObj, "indexB_aligned"),
                          slot(AlignObj, "score"))
  colnames(AlignedIndices) <- c("indexAligned.ref", "indexAligned.eXp", "score")
  AlignedIndices <- AlignedIndices[(AlignedIndices[,"indexAligned.ref"] != 0L), ]
  AlignedIndices[, 1:2][AlignedIndices[, 1:2] == 0] <- NA
  tAligned.ref <- mapIdxToTime(tVec.ref, AlignedIndices[,"indexAligned.ref"])
  tAligned.eXp <- mapIdxToTime(tVec.eXp, AlignedIndices[,"indexAligned.eXp"])
  # Map retention time from reference to eXp.
  eXpRT <- tAligned.eXp[which.min(abs(tAligned.ref - refRT))]
  eXpRT
}


#' Set Alignment rank to the aligned feature
#'
#' Picks the top feature in run by comparing m-score to unaligned FDR and aligned FDR.
#' If no satisfactory feature is found, peak-integration is carried out by mapping left and right peak
#' boundaries from the reference feature and integrating area under the curve.
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2020) + GPL-3
#' Date: 2020-04-13
#' @importFrom data.table set
#' @inheritParams alignToRef
#' @inherit perBatch return
#' @param adaptiveRT (numeric) defines the window around the aligned retention time, within which
#'  features with m-score below aligned FDR are considered for quantification.
#' @param tAligned (list) the first element corresponds to the aligned reference time,
#'  the second element is the aligned experiment time.
#' @param XICs.eXp (list) list of extracted ion chromatograms from experiment run.
#' @return invisible NULL
#' @seealso \code{\link{getMultipeptide}, \link{calculateIntensity}, \link{alignToRef}}
#' @keywords internal
#'
#' @examples
#' data(multipeptide_DIAlignR, package="DIAlignR")
#' data(XIC_QFNNTDIVLLEDFQK_3_DIAlignR, package="DIAlignR")
#' params <- paramsDIAlignR()
#' df <- multipeptide_DIAlignR[["14383"]]
#' df$alignment_rank[2] <- 1L
#' XICs.ref <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR[["hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]]
#' XICs.eXp <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR[["hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]]
#' \dontrun{
#' # Use getAlignedTimes() to get tAligned.
#' alignObj <- testAlignObj()
#' tAligned <- alignedTimes2(alignObj, XICs.ref, XICs.eXp)
#' setAlignmentRank(df, refIdx = 3L, eXp = "run2", tAligned, XICs.eXp,
#' params, adaptiveRT = 38.66)
#' }
setAlignmentRank <- function(df, refIdx, eXp, tAligned, XICs, params, adaptiveRT){
  ##### Map peak from ref to eXp #####
  # reference run.
  analyte <- .subset2(df, "transition_group_id")[[refIdx]]
  analyte_chr <- as.character(analyte)
  refRT <- .subset2(df, "RT")[[refIdx]]
  leftRef <- .subset2(df, "leftWidth")[[refIdx]]
  rightRef <- .subset2(df, "rightWidth")[[refIdx]]
  # Experiment run.
  left <- tAligned[,2][which.min(abs(tAligned[,1] - leftRef))]
  right <- tAligned[,2][which.min(abs(tAligned[,1] - rightRef))]
  eXpRT <- tAligned[,2][which.min(abs(tAligned[,1] - refRT))]
  # TODO. Save for the edge cases. or use wider chromatogram.
  # Peaks can be found withing adaptiveRT window even if the mapping straddles out-of-chromatogram.
  if(any(length(left)==0, length(right)==0, length(eXpRT)==0)){
    return(invisible(NULL)) # Can happen if XICs have all zero intensities.
  }

  ##### Find any feature present within adaptiveRT. #####
  # This step removes low FDR peaks which are not within adaptiveRT window.
  widePk <- c(left - adaptiveRT, right + adaptiveRT)
  narwPk <- c(left, right)
  tempi <- which(df$run == eXp & !is.na(df$RT))
  if(length(tempi) != 0){
    # Feature is present at the aligned time, use narrow peak #
    idx <- sapply(tempi, function(i) checkOverlap(narwPk,
        c(.subset2(df, "leftWidth")[[i]], .subset2(df, "rightWidth")[[i]])))
    idx <- tempi[which(idx)]
    if(any(.subset2(df, "m_score")[idx] <= params[["alignedFDR1"]], na.rm = TRUE)){
      # Select peak with biggest overlap
      idx <- idx[which(.subset2(df, "m_score")[idx] <= params[["alignedFDR1"]])]
      idx <- getBestPkIdx(df, narwPk, idx, params[["criterion"]])
      set(df, i = idx, "alignment_rank", 1L)
      if(params[["recalIntensity"]]){
        reIntensity2(df, idx, XICs[[analyte_chr]], c(left, right), params)}
      return(invisible(NULL))
    }

    # Feature is not present at the aligned time, use wide peak #
    idx <- sapply(tempi, function(i) checkOverlap(widePk,
        c(.subset2(df, "leftWidth")[[i]], .subset2(df, "rightWidth")[[i]])))
    idx <- tempi[which(idx)]
    if(any(.subset2(df, "m_score")[idx] <= params[["alignedFDR2"]], na.rm = TRUE)){
      idx <- idx[which.min(.subset2(df, "m_score")[idx])]
      set(df, i = idx, "alignment_rank", 1L)
      if(params[["recalIntensity"]] && checkOverlap(c(left, right), c(.subset2(df, "leftWidth")[[idx]], .subset2(df, "rightWidth")[[idx]]))){
        reIntensity2(df, idx, XICs[[analyte_chr]], c(left, right), params)
      }
      return(invisible(NULL))
    }
  }

  ##### Create a new feature. #####
  if(params[["fillMissing"]]){
    newRow(df, XICs[[analyte_chr]], left, right, eXpRT, analyte, eXp, params)
  }
  invisible(NULL)
}

setOtherPrecursors <- function(df, refIdx, XICs, analytes, params){
  Run <- .subset2(df, "run")[[refIdx]]
  if(length(refIdx) == 0 | is.null(refIdx)) return(NULL)
  precRef <- .subset2(df, "transition_group_id")[[refIdx]]
  pk <- c(.subset2(df, "leftWidth")[refIdx], .subset2(df, "rightWidth")[refIdx])
  # if(any(is.na(pk))) return(NULL) # Peak may be out of chrom hence set as NA.

  # If other precursors have overlapping feature then set their alignment rank to 1.
  for(analyte in setdiff(analytes, precRef)){
    analyte_chr <- as.character(analyte)
    idx <- which(df[["run"]] == Run & df[["transition_group_id"]] == analyte)
    if(length(idx)!=0){
      idx <- idx[sapply(idx, function(i) {
        sts <- checkOverlap(pk,  c(.subset2(df, "leftWidth")[i], .subset2(df, "rightWidth")[i]))
        ifelse(is.na(sts), FALSE, sts)
      } )]
    }
    if((length(idx)==0 | all(is.na(idx))) & params[["fillMissing"]]){
      # Create a feature for missing precursor
      newRow(df, XICs[[analyte_chr]], pk[1], pk[2], .subset2(df, "RT")[refIdx], analyte, Run, params)
    } else{
      idx <- idx[which.max(pmin(pk[2], .subset2(df, "rightWidth")[idx]) - pmax(pk[1], .subset2(df, "leftWidth")[idx]))]
      set(df, i = idx, 10L, 1L)  # set alignment rank (10L) for already present feature
      # If there is an overlaping peak, re-integrate area
      if(params[["recalIntensity"]]) reIntensity2(df, idx, XICs[[analyte_chr]], pk, params)
    }
  }
  invisible(NULL)
}

#' Populate Alignment Feature Mapping Table
#'
#' Populate an alignment feature mapping table for star align method,
#' to map aligned features in experiment runs to the reference run for a given analyte.
#' Is a data.table generated from of \code{\link{getRefExpFeatureMap}}.
#' @author Justin Sing, \email{justinc.sing@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-0386-0092
#'
#' License: (c) Author (2020) + GPL-3
#' Date: 2022-11-07
#' @keywords internal
#' @import data.table
#' @importFrom data.table rbindlist as.data.table
#' @inherit perBatch return
#' @inheritParams alignToRef
#' @inheritParams setAlignmentRank
#' @param analyte_chr (string) name of highest quality precursor/transition_group_id
#'
#' @return invisible NULL
#' @seealso \code{\link{getRefExpFeatureMap}, \link{alignToRef}}
#' @keywords internal
#'
#' @examples
#' data(multipeptide_DIAlignR, package="DIAlignR")
#' data(XIC_QFNNTDIVLLEDFQK_3_DIAlignR, package="DIAlignR")
#' params <- paramsDIAlignR()
#' df <- multipeptide_DIAlignR[["14383"]]
#' df$alignment_rank[2] <- 1L
#' XICs.ref <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR[["hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]]
#' XICs.eXp <- XIC_QFNNTDIVLLEDFQK_3_DIAlignR[["hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt"]][["4618"]]
#' \dontrun{
#' # Use getAlignedTimes() to get tAligned.
#' alignObj <- testAlignObj()
#' tAligned <- alignedTimes2(alignObj, XICs.ref, XICs.eXp)
#' setAlignmentRank(df, refIdx = 3L, eXp = "run2", tAligned, XICs.eXp, params, adaptiveRT = 38.66)
#' # Use getRefExpFeatureMap() to get a list of feature_alignment_mapping tables
#' feature_alignment_mapping <- data.table::as.data.table(structure(list(
#' reference_feature_id = structure(c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), class = "integer64"),
#' experiment_feature_id = structure(c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), class = "integer64")),
#' row.names = c(NA, -15L), class = c("data.table", "data.frame"), sorted = "reference_feature_id"))
#' populateReferenceExperimentFeatureAlignmentMap(df, feature_alignment_mapping, tAligned, ref = "run0", eXp = "run2", analyte_chr="4618")
#' }
populateReferenceExperimentFeatureAlignmentMap <- function(df, feature_alignment_mapping, tAligned, ref, eXp, analyte_chr){
  mapped_aligned_features = rbindlist(lapply(df[run==ref & transition_group_id==analyte_chr][["RT"]],
                                             function(rt_i){
                                               as.data.table(t(matrix(tAligned[which.min(abs(tAligned[,1]-rt_i)),])))}
                                             ))
  # Subset reference and experiment features for current analyte
  ref_df = df[run==ref & transition_group_id==analyte_chr & !is.na(feature_id)]
  eXp_df = df[run==eXp & transition_group_id==analyte_chr & !is.na(feature_id)]

  # Get reference to experiment feature mapping
  lapply(seq(1,nrow(mapped_aligned_features)), function(feature_i){
    ref_featid <- ref_df[which.min(abs(ref_df[["RT"]]-mapped_aligned_features[["V1"]][[feature_i]]))][['feature_id']]
    eXp_featid <- eXp_df[which.min(abs(eXp_df[["RT"]]-mapped_aligned_features[["V2"]][[feature_i]]))][['feature_id']]
    if( length(eXp_featid)==0 ){ return(invisible(NULL)) }
    if ( eXp_featid %not_in% feature_alignment_mapping[["experiment_feature_id"]] ){
      populate_index <- which(feature_alignment_mapping[["reference_feature_id"]]==0 & feature_alignment_mapping[["experiment_feature_id"]]==0)
      data.table::set(feature_alignment_mapping, i=populate_index[1], "reference_feature_id", ref_featid)
      data.table::set(feature_alignment_mapping, i=populate_index[1], "experiment_feature_id", eXp_featid)
    }
  })
  invisible(NULL)
}
