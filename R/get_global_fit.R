#' Calculates LOESS fit between RT of two runs
#'
#' This function uses output of getRTdf that selects features from oswFiles which has m-score < maxFdrLoess. It fits LOESS on these feature.
#' Loess mapping is established from reference to experiment run.
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2019) + GPL-3
#' Date: 2019-12-14
#' @param RUNS_RT (data-frame) must have three calumns: transition_group_id, RT.eXp, and RT.ref.
#' @param spanvalue (numeric) Spanvalue for LOESS fit. For targeted proteomics 0.1 could be used.
#' @return An object of class "loess".
#' @seealso \code{\link{getLinearfit}, \link{getFeatures}, \link{getRTdf}}
#' @keywords internal
#' @examples
#' data(oswFiles_DIAlignR, package="DIAlignR")
#' \dontrun{
#' RUNS_RT <- getRTdf(oswFiles = oswFiles_DIAlignR, ref = "run1", eXp = "run2", maxFdrGlobal = 0.05)
#' Loess.fit <- getLOESSfit(RUNS_RT, spanvalue = 0.1)
#' }
getLOESSfit <- function(RUNS_RT, spanvalue = 0.1){
  fit <- stats::lowess(RUNS_RT$RT.ref, RUNS_RT$RT.eXp, f = spanvalue, iter =3)
  fit$RT.ref <- RUNS_RT$RT.ref
  fit$RT.eXp <- RUNS_RT$RT.eXp
  fit
}


#' Modified loess for condition handling
#'
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2020) + GPL-3
#' Date: 2020-07-11
#' @importFrom stats loess loess.control
#' @param RUNS_RT (data-frame) must have three calumns: transition_group_id, RT.eXp, and RT.ref.
#' @param spanvalue (numeric) spanvalue for LOESS fit. For targeted proteomics 0.1 could be used.
#' @return An object of class "loess" or "lm".
#' @seealso \code{\link{getLinearfit}, \link{getLOESSfit}}
#' @keywords internal
#' @examples
#' df <- data.frame("transition_group_id" = 1:10, "RT.eXp" = 2:11, "RT.ref" = 10:19)
#' \dontrun{
#' dialignrLoess(df, 0.1)
#' dialignrLoess(df[1:4,], 0.1)
#' }
dialignrLoess <- function(RUNS_RT, spanvalue){
  # direct surface allows to extrapolate outside of training data boundary while using predict.
  fit <- tryCatch(expr = loess(RT.eXp ~ RT.ref, data = RUNS_RT, span = spanvalue,
                               control=loess.control(surface="direct")),
                  error = function(c) {
                    print(c)
                    message("\nError in loess. Using linear fit instead.")
                    lm(RT.eXp ~ RT.ref, data = RUNS_RT)},
                  warning = function(c) {
                    print(c)
                    message(paste0("\nWarning in loess, spanvalue is doubled to ", 2*spanvalue))
                    dialignrLoess(RUNS_RT, 2*spanvalue)}
  )
  fit
}


#' Calculates linear fit between RT of two runs
#'
#' This function uses output of getRTdf that selects features from oswFiles which has m-score < maxFdrLoess. It fits Linear model on these feature.
#' Loess mapping is established from reference to experiment run.
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2019) + GPL-3
#' Date: 2019-12-14
#' @param RUNS_RT (data-frame) must have three calumns: transition_group_id, RT.eXp, and RT.ref.
#' @import stats
#' @return An object of class "lm".
#' @seealso \code{\link{getLOESSfit}, \link{getFeatures}, \link{getRTdf}}
#' @keywords internal
#' @examples
#' data(oswFiles_DIAlignR, package="DIAlignR")
#' \dontrun{
#' RUNS_RT <- getRTdf(oswFiles = oswFiles_DIAlignR, ref = "run1", eXp = "run2", maxFdrGlobal = 0.05)
#' lm.fit <- getLinearfit(RUNS_RT)
#' }
getLinearfit <- function(RUNS_RT){
  # For testing we want to avoid validation peptides getting used in the fit.
  fit <- stats::.lm.fit(cbind(1, RUNS_RT$RT.ref), RUNS_RT$RT.eXp)
  fit
}


#' Calculates global alignment between RT of two runs
#'
#' This function selects features from oswFiles which has m-score < maxFdrLoess. It fits linear/loess regression on these feature.
#' Retention-time mapping is established from reference to experiment run.
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2019) + GPL-3
#' Date: 2019-12-14
#' @param oswFiles (list of data-frames) it is output from getFeatures function.
#' @param ref (string) Must be a combination of "run" and an iteger e.g. "run2".
#' @param eXp (string) Must be a combination of "run" and an iteger e.g. "run2".
#' @param fitType (string) Must be from "loess" or "linear".
#' @param maxFdrGlobal (numeric) A numeric value between 0 and 1. Features should have m-score lower than this value for participation in global fit.
#' @param spanvalue (numeric) Spanvalue for LOESS fit. For targeted proteomics 0.1 could be used.
#' @importFrom magrittr %>%
#' @return An object of class "loess".
#' @seealso \code{\link{getFeatures}}
#' @examples
#' data(oswFiles_DIAlignR, package="DIAlignR")
#' fit <- getGlobalAlignment(oswFiles = oswFiles_DIAlignR, ref = "run1", eXp = "run2",
#'  fitType = "linear", maxFdrGlobal = 0.05, spanvalue = 0.1)
#' @export
getGlobalAlignment <- function(oswFiles, ref, eXp, fitType = "linear", maxFdrGlobal = 0.01, spanvalue = 0.1){
  message("Geting global alignment of ", ref, " and ", eXp, ",", appendLF = FALSE)
  RUNS_RT <- getRTdf(oswFiles, ref, eXp, maxFdrGlobal)
  if(is(RUNS_RT, "logical")) return(NA)
  if(fitType == "loess"){
    fit <- getLOESSfit(RUNS_RT, spanvalue)
    N <- length(fit$x)
  }
  else{
    fit <- getLinearfit(RUNS_RT)
    N <- length(fit$residuals)
  }
  message(" n = ", N)
  fit
}


#' Calculates Residual Standard Error of the fit
#'
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2020) + GPL-3
#' Date: 2020-04-08
#' @importFrom methods is
#' @param fit (lm or loess) Linear or loess fit object between reference and experiment run.
#' @return (numeric)
#' @seealso \code{\link{getLOESSfit}, \link{getLinearfit}, \link{getGlobalAlignment}}
#' @keywords internal
#' @examples
#' data(oswFiles_DIAlignR, package="DIAlignR")
#' \dontrun{
#' Loess.fit <- getGlobalAlignment(oswFiles = oswFiles_DIAlignR, ref = "run1", eXp = "run2",
#' maxFdrGlobal = 0.05, spanvalue = 0.1, fit = "loess")
#' getRSE(Loess.fit, "loess")
#' }
getRSE <- function(fit, globalAlignment){
  if(is(fit, "logical")) return(NA_real_)
  if(globalAlignment == "loess"){
    lfun <- stats::approxfun(fit, ties = mean)
    fitted <- lfun(fit$RT.ref)
    res <- fit$RT.eXp - fitted
  } else{
    res <- fit$residuals
  }
  if(length(res) <= 2) return(NA_real_)
  RSE <- sqrt(sum((res)^2)/(length(res)-2))
  RSE
}

#' Calculates all global alignment needed in refRun
#'
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2020) + GPL-3
#' Date: 2020-04-19
#' @param refRun (data-frame) Output of getRefRun function. Must have two columsn : transition_group_id and run.
#' @param features (list of data-frames) it is output from getFeatures function.
#' @param fileInfo (data-frame) Output of getRunNames function.
#' @param globalAlignment (string) Must be from "loess" or "linear".
#' @param globalAlignmentFdr (numeric) A numeric value between 0 and 1. Features should have m-score lower than this value for participation in global fit.
#' @param globalAlignmentSpan (numeric) Spanvalue for LOESS fit. For targeted proteomics 0.1 could be used.
#' @return (list) Each element is either of class lm or loess.
#' @seealso \code{\link{getRefRun}, \link{getFeatures}, \link{getGlobalAlignment}}
#' @keywords internal
#' @examples
#' dataPath <- system.file("extdata", package = "DIAlignR")
#' fileInfo <- getRunNames(dataPath, oswMerged = TRUE)
#' features <- getFeatures(fileInfo, maxFdrQuery = 0.05)
#' precursors <- getPrecursors(fileInfo, TRUE, "DIA_Proteomics", "experiment-wide", 0.01)
#' precursors <- dplyr::arrange(precursors, .data$peptide_id, .data$transition_group_id)
#' peptideIDs <- unique(precursors$peptide_id)
#' peptideScores <- getPeptideScores(fileInfo, peptideIDs, TRUE, "DIA_Proteomics", "experiment-wide")
#' peptideScores <- lapply(peptideIDs, function(pep) dplyr::filter(peptideScores, .data$peptide_id == pep))
#' names(peptideScores) <- as.character(peptideIDs)
#' \dontrun{
#' refRun <- getRefRun(peptideScores)
#' fits <- getGlobalFits(refRun, features, fileInfo, "linear", 0.05, 0.1)
#' }
getGlobalFits <- function(refRun, features, fileInfo, globalAlignment,
                          globalAlignmentFdr, globalAlignmentSpan, applyFun = lapply){
  refs <- unique(refRun[["run"]])
  refs <- refs[!is.na(refs)]
  globalFits <- lapply(refs, function(ref){
    exps <- setdiff(rownames(fileInfo), ref)
    Fits <- applyFun(exps, function(eXp){
      getGlobalAlignment(features, ref, eXp, globalAlignment, globalAlignmentFdr, globalAlignmentSpan)
    })
    names(Fits) <- paste(ref, exps, sep = "_")
    Fits
  })
  globalFits <- unlist(globalFits, recursive = FALSE)
  globalFits
}

#' Calculates global alignment between RT of two runs
#'
#' This function selects features from oswFiles which has m-score < maxFdrLoess. It fits linear/loess regression on these feature.
#' Retention-time mapping is established from reference to experiment run.
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2021) + GPL-3
#' Date: 2019-03-01
#' @inheritParams getGlobalAlignment
#' @inheritParams getGlobalFits
#' @return A data-frame
#' @seealso \code{\link{getGlobalAlignment}}
#' @examples
#' data(oswFiles_DIAlignR, package="DIAlignR")
#' df <- getRTdf(features = oswFiles_DIAlignR, ref = "run1", eXp = "run2", maxFdrGlobal = 0.05)
#' @export
getRTdf <- function(features, ref, eXp, maxFdrGlobal){
  if(maxFdrGlobal > 1){
    warning("No common precursors found between ", ref, " and ", eXp, ". Will do local alignment instead.")
    return(NA)
  }
  df.ref <-  features[[ref]][peak_group_rank == 1L & m_score <= maxFdrGlobal, .(transition_group_id, RT)]
  df.eXp <-  features[[eXp]][peak_group_rank == 1L & m_score <= maxFdrGlobal, .(transition_group_id, RT)]
  RUNS_RT <- df.ref[df.eXp, on = .(transition_group_id), nomatch = 0]
  if(nrow(RUNS_RT) < 2){
    message("Increasing maxFdrGlobal 10 times")
    RUNS_RT <- getRTdf(features, ref, eXp, 10*maxFdrGlobal)
  }
  colnames(RUNS_RT) <- c("transition_group_id", "RT.ref", "RT.eXp")
  RUNS_RT
}

extractFit <- function(fit, globalAlignment){
  if(is(fit, "logical")) return(NA)
  if(globalAlignment == "linear"){
    return(stats::coef(fit))
  }else{
    return(stats::approxfun(fit[1:2], ties = mean))
  }
}

getPredict <- function(fit, x, globalAlignment){
  if(globalAlignment == "linear"){
    return(c(fit%*%t(cbind(1, x))))
  } else{
    return(fit(x))
  }
}
