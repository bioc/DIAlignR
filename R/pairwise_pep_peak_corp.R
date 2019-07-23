#' Establishes pairwise correspondence between extracted-ion chromatograms.
#'
#' This function calculates three matrices for affine gap alignment using input
#' similarity matrix and affine gap opening and gap closing penalties. An
#' implementation of Needleman-Wunsch alignment and overlap alignment is also
#' provided. All three matrices are clubbed together in an S4 object.
#' @param featureTable A table of retention time identifications for each peptides. The retention times
#' could be annotated manually or through softwares like OpenSWATH.
#' @param pairName Names of runs joined with underscore. e.g. runA_runB, This will allow
#' alignment of runB to runA.
#' @param XICs.A List of extracted ion chromatograms of runA.
#' @param XICs.B List of extracted ion chromatograms of runB.
#' @param alignType Available alignment methods are "global", "local" and "hybrid".
#' @param oswFeatureList List of features detected in each run. For feature detection
#' OpenSWATH, Spectronaut, Skyline etc can be used.
#' @param spanvalue A numeric Spanvalue for LOESS fit.
#' @param normalization A character string. Must be selected from (mean, l2)
#' @param simMeasure A character string. Must be selected from (dotProduct, cosineAngle,
#' cosine2Angle, dotProductMasked, euclideanDist, covariance and correlation)
#' @param goFactor A numeric scalar. Penalty for introducing first gap in alignment. This value is multiplied by base gap-penalty.
#' @param geFactor A numeric scalar. Penalty for introducing subsequent gaps in alignment. This value is multiplied by base gap-penalty.
#' @param cosAngleThresh (numeric) In simType = dotProductMasked mode, angular similarity should be higher than cosAngleThresh otherwise similarity is forced to zero.
#' @param OverlapAlignment (logical) An input for alignment with free end-gaps. False: Global alignment, True: overlap alignment.
#' @param dotProdThresh (numeric) In simType = dotProductMasked mode, values in similarity matrix higher than dotProdThresh quantile are checked for angular similarity.
#' @param gapQuantile A numeric scalar. Must be between 0 and 1. This is used to calculate base gap-penalty from similarity distribution.
#' @param hardConstrain A logical scalar. if false; indices farther from noBeef distance are filled with distance from linear fit line.
#' @param samples4gradient A numeric scalar. This parameter modulates penalization of masked indices.
#' @param expRSE Expected residual standard error(rse) for constraining hybrid alignment, if rse from LOESS fit comes out to be large.
#' @param samplingTime Time difference between two data-points in each chromatogram. For hybrid and local alignment, samples are assumed to be equally time-spaced.
#' @param RSEdistFactor A numeric scalar. This defines how much distance in the unit of rse remains a noBeef zone.
#' @return A numeric matrix
#' @examples
#' pair <- "run1_run2"
#' MappedTime2 <- getPepPeakCorp(StrepAnnot, pair, StrepChroms[["run1"]], StrepChroms[["run2"]],
#' "hybrid", oswOutStrep, expRSE = 7.4)
#' @export
getPepPeakCorp <- function(featureTable, pairName, XICs.A=NULL, XICs.B=NULL, alignType, oswFeatureList=NULL,spanvalue = 0.1,
                           normalization = "mean", simMeasure = "dotProductMasked",
                           goFactor = 0.125, geFactor = 40,
                           cosAngleThresh = 0.3, OverlapAlignment = TRUE, dotProdThresh = 0.96, gapQuantile = 0.5,
                           hardConstrain = FALSE, samples4gradient = 100,
                           expRSE = 8.0, samplingTime = 3.4,  RSEdistFactor = 3.5
                           ){
  peptides <- rownames(featureTable)
  run_pair <- strsplit(pairName, split = "_")[[1]]
  MappedTime <- matrix(NA, nrow = length(peptides), ncol = 1)
  rownames(MappedTime) <- peptides
  if(alignType != "local"){
    if(is.null(oswFeatureList)){
      print("oswFeatureList can't be NULL for non-local alignment")
    }
    # In finding global fit, peptides are removed while training the fit.
    Loess.fit <- getLOESSfit(pairName, peptides, oswFeatureList, spanvalue)
    rse <- Loess.fit$s # Residual Standard Error
  }
  for(peptide in peptides){
    if(alignType == "global")
      MappedTime[peptide, 1] <- predict(Loess.fit, featureTable[peptide,run_pair[1]])
    else{
      intensityListA <- lapply(XICs.A[[peptide]], `[[`, 2) # Extracting intensity values
      intensityListB <- lapply(XICs.B[[peptide]], `[[`, 2) # Extracting intensity values
      tAVec <- XICs.A[[peptide]][[1]][["time"]] # Extracting time component
      tBVec <- XICs.B[[peptide]][[1]][["time"]] # Extracting time component
      if(alignType == "hybrid"){
        noBeef <- ceiling(RSEdistFactor*min(rse, expRSE)/samplingTime)
        B1p <- predict(Loess.fit, tAVec[1])
        B2p <- predict(Loess.fit, tAVec[length(tAVec)])
        Alignobj <- alignChromatogramsCpp(intensityListA, intensityListB, alignType,
                                           tAVec, tBVec, normalization, simMeasure,
                                           B1p, B2p, noBeef)
      }
      else{
        Alignobj <- alignChromatogramsCpp(intensityListA, intensityListB, alignType,
                                           tAVec, tBVec, normalization, simMeasure)
      }
      AlignedIndices <- cbind(Alignobj@indexA_aligned, Alignobj@indexB_aligned, Alignobj@score)
      colnames(AlignedIndices) <- c("indexA_aligned", "indexB_aligned", "score")
      AlignedIndices[, 1:2][AlignedIndices[, 1:2] == 0] <- NA
      tA.aligned <- mapIdxToTime(tAVec, AlignedIndices[,"indexA_aligned"])
      tB.aligned <- mapIdxToTime(tBVec, AlignedIndices[,"indexB_aligned"])
      MappedTime[peptide, 1] <- tB.aligned[which.min(abs(tA.aligned - featureTable[peptide,run_pair[1]]))]
    }
  }
  return(MappedTime)
}

#' Outputs an aligned object for pairwise correspondence between extracted-ion chromatograms.
#'
#' This function calculates three matrices for affine gap alignment using input
#' similarity matrix and affine gap opening and gap closing penalties. An
#' implementation of Needleman-Wunsch alignment and overlap alignment is also
#' provided. All three matrices are clubbed together in an output S4 object.
#' @param peptide A string. Peptide for which AlignObj needs to be calculated.
#' @param pairName Names of runs joined with underscore. e.g. runA_runB, This will allow
#' alignment of runB to runA.
#' @param XICs.A List of extracted ion chromatograms of runA.
#' @param XICs.B List of extracted ion chromatograms of runB.
#' @param alignType Available alignment methods are "global", "local" and "hybrid".
#' @param oswFeatureList List of features detected in each run. For feature detection
#' OpenSWATH, Spectronaut, Skyline etc can be used.
#' @param spanvalue A numeric Spanvalue for LOESS fit.
#' @param normalization A character string. Must be selected from (mean, l2)
#' @param simMeasure A character string. Must be selected from (dotProduct, cosineAngle,
#' cosine2Angle, dotProductMasked, euclideanDist, covariance and correlation)
#' @param goFactor A numeric scalar. Penalty for introducing first gap in alignment. This value is multiplied by base gap-penalty.
#' @param geFactor A numeric scalar. Penalty for introducing subsequent gaps in alignment. This value is multiplied by base gap-penalty.
#' @param cosAngleThresh (numeric) In simType = dotProductMasked mode, angular similarity should be higher than cosAngleThresh otherwise similarity is forced to zero.
#' @param OverlapAlignment (logical) An input for alignment with free end-gaps. False: Global alignment, True: overlap alignment.
#' @param dotProdThresh (numeric) In simType = dotProductMasked mode, values in similarity matrix higher than dotProdThresh quantile are checked for angular similarity.
#' @param gapQuantile A numeric scalar. Must be between 0 and 1. This is used to calculate base gap-penalty from similarity distribution.
#' @param hardConstrain A logical scalar. if false; indices farther from noBeef distance are filled with distance from linear fit line.
#' @param samples4gradient A numeric scalar. This parameter modulates penalization of masked indices.
#' @param expRSE Expected residual standard error(rse) for constraining hybrid alignment, if rse from LOESS fit comes out to be large.
#' @param samplingTime Time difference between two data-points in each chromatogram. For hybrid and local alignment, samples are assumed to be equally time-spaced.
#' @param RSEdistFactor A numeric scalar. This defines how much distance in the unit of rse remains a noBeef zone.
#' @return A S4 object
#' @examples
#' pair <- "run1_run2"
#' peptide <- "15605_YFMPVHGEYR/3"
#' hybridObj <- getAlignedObj(peptide, pair, StrepChroms[["run1"]], StrepChroms[["run2"]], "hybrid", oswOutStrep, expRSE = 7.4)
#' @export
getAlignedObj <- function(peptide, pairName, XICs.A=NULL, XICs.B=NULL, alignType, oswFeatureList=NULL,spanvalue = 0.1,
                           normalization = "mean", simMeasure = "dotProductMasked",
                           goFactor = 0.125, geFactor = 40,
                           cosAngleThresh = 0.3, OverlapAlignment = TRUE, dotProdThresh = 0.96, gapQuantile = 0.5,
                           hardConstrain = FALSE, samples4gradient = 100,
                           expRSE = 8.0, samplingTime = 3.4,  RSEdistFactor = 3.5
){
  if(alignType == "global"){
    print("AlignObj can only be returned for local and hybrid alignment.")
  }
  else{
    if(alignType != "local"){
      if(is.null(oswFeatureList)){
        print("oswFeatureList can't be NULL for non-local alignment")
      }
      # In finding global fit, peptides are removed while training the fit.
      Loess.fit <- getLOESSfit(pairName, peptide, oswFeatureList, spanvalue)
      rse <- Loess.fit$s # Residual Standard Error
    }
    intensityListA <- lapply(XICs.A[[peptide]], `[[`, 2) # Extracting intensity values
    intensityListB <- lapply(XICs.B[[peptide]], `[[`, 2) # Extracting intensity values
    tAVec <- XICs.A[[peptide]][[1]][["time"]] # Extracting time component
    tBVec <- XICs.B[[peptide]][[1]][["time"]] # Extracting time component
    if(alignType == "hybrid"){
      noBeef <- ceiling(RSEdistFactor*min(rse, expRSE)/samplingTime)
      B1p <- predict(Loess.fit, tAVec[1])
      B2p <- predict(Loess.fit, tAVec[length(tAVec)])
      Alignobj <- alignChromatogramsCpp(intensityListA, intensityListB, alignType,
                                        tAVec, tBVec, normalization, simMeasure,
                                        B1p, B2p, noBeef)
    }
    else{
      Alignobj <- alignChromatogramsCpp(intensityListA, intensityListB, alignType,
                                        tAVec, tBVec, normalization, simMeasure)
    }
    return(Alignobj)
  }
}