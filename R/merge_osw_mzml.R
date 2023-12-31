#' Merge dataframes from OSW and mzML files
#'
#' Merges dataframes on transition_id(OSW) = chromatogramId(mzML).
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2019) + GPL-3
#' Date: 2019-12-13
#' @importFrom magrittr %>%
#' @importFrom rlang .data
#' @param oswAnalytes (dataframe) This is an output of getOswFiles.
#' @param chromHead (dataframe) This has two columns: chromatogramId and chromatogramIndex with integer values.
#' @param analyteFDR (numeric) Not used.
#' @param runType (char) This must be one of the strings "DIA_Proteomics", "DIA_Metabolomics".
#' @return Invisible NULL
#' @seealso \code{\link{getOswFiles}}
#' @keywords internal
mergeOswAnalytes_ChromHeader <- function(oswAnalytes, chromHead, analyteFDR =  1.00, runType = "DIA_Proteomics"){
  # TODO: Make sure that transition_id has same order across runs. IMO should be specified in query.
  assign("oswAnalytes", dplyr::left_join(oswAnalytes, chromHead,
                                  by = c("transition_id" = "chromatogramId")) %>%
    dplyr::group_by(.data$transition_group_id, .data$peak_group_rank) %>%
    dplyr::mutate(transition_ids = paste0(.data$transition_id, collapse = ","),
                  chromatogramIndex = paste0(.data$chromatogramIndex, collapse = ",")) %>%
    dplyr::ungroup() %>% dplyr::select(-'transition_id') %>% dplyr::distinct(),
    envir = parent.frame(n = 1))
  invisible(NULL)
}

#' Get list of peptides and their chromatogram indices.
#'
#' This function reads all osw and xics files in the directories at dataPath. It selects analytes which has associated features with m-score < maxFdrQuery.
#' For these analytes it fetches chromatogram indices by matching transition_id(osw) with chromatogramID(xics).
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2019) + GPL-3
#' Date: 2019-12-13
#' @importFrom rlang .data
#' @param dataPath (char) path to xics and osw directory.
#' @param filenames (data-frame) column "filename" contains RUN table from osw files. column "runs" contain respective mzML names without extension.
#' To get filenames use DIAlignR::getRunNames function.
#' @param maxFdrQuery (numeric) A numeric value between 0 and 1. It is used to filter features from osw file which have SCORE_MS2.QVALUE less than itself.
#' @param analyteFDR (numeric) Not used.
#' @param oswMerged (logical) TRUE for experiment-wide FDR and FALSE for run-specific FDR by pyprophet.
#' @param analytes (string) analyte is as PRECURSOR.GROUP_LABEL or as PEPTIDE.MODIFIED_SEQUENCE and PRECURSOR.CHARGE from osw file.
#' @param runType (char) This must be one of the strings "DIA_Proteomics", "DIA_Metabolomics".
#' @param analyteInGroupLabel (logical) TRUE for getting analytes as PRECURSOR.GROUP_LABEL from osw file.
#' @param mzPntrs A list of mzRpwiz.
#'  FALSE for fetching analytes as PEPTIDE.MODIFIED_SEQUENCE and PRECURSOR.CHARGE from osw file.
#' @return (data-frames) Data-frame has following columns:
#' \item{transition_group_id}{(string) it is either fetched from PRECURSOR.GROUP_LABEL or a combination of PEPTIDE.MODIFIED_SEQUENCE and PRECURSOR.CHARGE from osw file.}
#' \item{RT}{(numeric) retention time as in FEATURE.EXP_RT of osw files.}
#' \item{delta_rt}{(numeric) as in FEATURE.DELTA_RT of osw files.}
#' \item{assay_RT}{(numeric) library retention time as in PRECURSOR.LIBRARY_RT of osw files.}
#' \item{Intensity}{(numeric) peak intensity as in FEATURE_MS2.AREA_INTENSITY of osw files.}
#' \item{leftWidth}{(numeric) as in FEATURE.LEFT_WIDTH of osw files.}
#' \item{rightWidth}{(numeric) as in FEATURE.RIGHT_WIDTH of osw files.}
#' \item{peak_group_rank}{(integer) rank of each feature associated with transition_group_id.}
#' \item{m_score}{(numeric) q-value of each feature associated with transition_group_id.}
#' \item{chromatogramIndex}{(integer) Index of chromatogram in mzML file.}
#' \item{transition_ids}{(integer) fragment-ion ID associated with transition_group_id. This is matched with chromatogram ID in mzML file.}
#'
#' @seealso \code{\link{getRunNames}}
#' @keywords internal
#' @examples
#' dataPath <- system.file("extdata", package = "DIAlignR")
#' filenames <- getRunNames(dataPath = dataPath)
#' \dontrun{
#' mzPntrs <- getMZMLpointers(filenames)
#' oswFiles <- getOswFiles(filenames, mzPntrs, analyteInGroupLabel = TRUE)
#' rm(mzPntrs)
#' }
getOswFiles <- function(fileInfo, mzPntrs, maxFdrQuery = 0.05, analyteFDR = 0.01, oswMerged = TRUE,
                        analytes = NULL, runType = "DIA_Proteomics", analyteInGroupLabel = FALSE){
  oswFiles <- list()
  for(i in 1:nrow(fileInfo)){
    run <- rownames(fileInfo)[i]
    # Get a query to search against the osw files.
    oswName <- as.character(fileInfo$featureFile[i])
    # Get transition indices for MS2 fragment-ions.
    oswAnalytes <- fetchAnalytesInfo(oswName, maxFdrQuery, oswMerged, analytes = analytes,
                                     filename = fileInfo$spectraFile[i], runType, analyteInGroupLabel)

    # Get chromatogram indices from the header file.
    runname <- rownames(fileInfo)[i]
    chromHead <- mzR::chromatogramHeader(mzPntrs[[runname]])
    chromatogramIdAsInteger(chromHead)
    # Merge chromatogram indices with transition indices and save them.
    # Following function merges analytesInfo dataframe with the chromatogram Header.
    mergeOswAnalytes_ChromHeader(oswAnalytes, chromHead, analyteFDR, runType)
    oswFiles[[i]] <- dplyr::select(oswAnalytes, -'filename')
    message("Fetched chromatogram indices from ", fileInfo$runName[i])
  }
  # Assign rownames to the each element of list
  names(oswFiles) <- rownames(fileInfo)
  return(oswFiles)
}


#' Coerce chromatogram ids as integer
#'
#' chromatogramHeader has 10 columns. The two important columns are:
#' "chromatogramId" which has fragment-ion ID that matches with transition ID in osw file.
#' "chromatogramIndex" that lists indices of chromatograms in mzML file.
#'
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2019) + GPL-3
#' Date: 2019-12-13
#' @param chromatogramHeader (dataframe)
#' @return Invisible NULL
#' @keywords internal
chromatogramIdAsInteger <- function(chromatogramHeader){
  assign("chromHead", dplyr::mutate(dplyr::select(chromatogramHeader, 'chromatogramId', 'chromatogramIndex'),
                                    chromatogramId = as.integer(.data$chromatogramId)),
         envir = parent.frame(n = 1))
  invisible(NULL)
}


#' Merge precursor and transitions mapping with chromatogram header
#'
#' Merges dataframes on transition_ids(OSW) = chromatogramId(mzML).
#' @importFrom magrittr %>%
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2019) + GPL-3
#' Date: 2020-04-07
#' @importFrom rlang .data
#' @param prec2transition (dataframe) This has two columns: transition_group_id and transition_ids with integer values.
#' @param chromHead (dataframe) This has two columns: chromatogramId and chromatogramIndex with integer values.
#' @return (dataframe) having following columns:
#' \item{transition_group_id}{(string) it is either fetched from PRECURSOR.GROUP_LABEL or a combination of PEPTIDE.MODIFIED_SEQUENCE and PRECURSOR.CHARGE from osw file.}
#' \item{chromatogramIndex}{(integer) Index of chromatogram in mzML file.}
#' @seealso \code{\link{getChromatogramIndices}}
#' @keywords internal
mapPrecursorToChromIndices <- function(prec2transition, chromHead){
  # Assume that each transition has one row.
  prec2ChromIndices <- dplyr::select(dplyr::left_join(prec2transition, chromHead,
                                                      by = c("transition_ids" = "chromatogramId")), -'transition_ids')
  prec2ChromIndices <- dplyr::group_by(prec2ChromIndices, .data$transition_group_id) %>%
    dplyr::summarise(chromatogramIndex = base::list(.data$chromatogramIndex)) %>%
    as.data.frame()
  #TODO: If mzR reads index as integer64, use bit64::as.integer64(chromatogramIndex)
  prec2ChromIndices
}


#' Get chromatogram indices of precursors.
#'
#' This function reads the header of chromatogram files. It then fetches chromatogram indices by matching transition_id(osw) with chromatogramID(xics).
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2019) + GPL-3
#' Date: 2019-04-07
#' @inheritParams alignTargetedRuns
#' @importFrom rlang .data
#' @param fileInfo (data-frame) Output of getRunNames function.
#' @param precursors (data-frame) Atleast two columns transition_group_id and transition_ids are required.
#' @param mzPntrs A list of mzRpwiz.
#' @return (list) A list of dataframes having following columns:
#' \item{transition_group_id}{(string) it is PRECURSOR.ID from osw file.}
#' \item{chromatogramIndex}{(integer) index of chromatogram in mzML file.}
#'
#' @seealso \code{\link{chromatogramIdAsInteger}, \link{mapPrecursorToChromIndices}}
#' @examples
#' dataPath <- system.file("extdata", package = "DIAlignR")
#' fileInfo <- getRunNames(dataPath = dataPath)
#' precursors <- getPrecursors(fileInfo, oswMerged = TRUE, context = "experiment-wide")
#' mzPntrs <- getMZMLpointers(fileInfo)
#' prec2chromIndex <- getChromatogramIndices(fileInfo, precursors, mzPntrs)
#' for(mz in mzPntrs) DBI::dbDisconnect(mz)
#' @export
getChromatogramIndices <- function(fileInfo, precursors, mzPntrs, applyFun=lapply){
  # Get precursor to transition mapping and unlist so that each row has one transition.
  prec2transition <- dplyr::select(precursors, 'transition_group_id', 'transition_ids') %>%
    tidyr::unnest('transition_ids') %>% as.data.frame()
  # For each precursor get associated chromatogram Indices
  runs <- rownames(fileInfo)
  prec2chromIndex <- applyFun(seq_along(runs), function(i){
    mz <- mzPntrs[[runs[i]]]
    # Get chromatogram indices from the header file.
    if(is(mz)[1] == "SQLiteConnection"){chromHead <- readSqMassHeader(mz)}
    if(is(mz)[1] == "mzRpwiz"){
      chromHead <- mzR::chromatogramHeader(mz) #TODO: Make sure that chromatogramIndex is read as integer64
    }
    chromHead <- chromHead[grepl("^[[:digit:]]+$", chromHead[,1]),]
    chromatogramIdAsInteger(chromHead) # Select only chromatogramId, chromatogramIndex
    df <- mapPrecursorToChromIndices(prec2transition, chromHead) # Get chromatogram Index for each precursor.
    df <- df[match(precursors$transition_group_id, df$transition_group_id),]
    row.names(df) <- NULL
    message("Fetched chromatogram indices from ", fileInfo$chromatogramFile[i])
    setDT(df)
  })
  names(prec2chromIndex) <- runs
  prec2chromIndex
}

#' Get MS1 chromatogram indices of precursors.
#'
#' This function reads the header of chromatogram files. It then fetches chromatogram indices by matching transition_group_id(osw) with chromatogramID(xics).
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2022) + GPL-3
#' Date: 2022-01-15
#' @inheritParams getChromatogramIndices
#' @importFrom data.table setDT
#' @param fileInfo (data-frame) Output of getRunNames function.
#' @param precursors (data-frame) Atleast two columns transition_group_id and transition_ids are required.
#' @param mzPntrs A list of mzRpwiz.
#' @param ions (character) Strings to specify ions. eg. i0, i1.
#' @return (list) A list of dataframes having following columns:
#' \item{transition_group_id}{(string) it is PRECURSOR.ID from osw file.}
#' \item{chromatogramIndex}{(integer) index of MS1 chromatogram in mzML file.}
#'
#' @seealso \code{\link{chromatogramIdAsInteger}, \link{mapPrecursorToChromIndices}}
#' @examples
#' dataPath <- system.file("extdata", package = "DIAlignR")
#' fileInfo <- getRunNames(dataPath = dataPath)
#' precursors <- getPrecursors(fileInfo, oswMerged = TRUE, context = "experiment-wide")
#' mzPntrs <- getMZMLpointers(fileInfo)
#' prec2chromIndex <- getPrecursorIndices(fileInfo, precursors, mzPntrs)
#' for(mz in mzPntrs) DBI::dbDisconnect(mz)
#' @export
getPrecursorIndices <- function(fileInfo, precursors, mzPntrs, ions='.*', applyFun=lapply){
  runs <- rownames(fileInfo)
  prec2chromIndex <- applyFun(seq_along(runs), function(i){
    mz <- mzPntrs[[runs[i]]]
    # For each precursor get associated MS1 chromatogram Indices
    if(is(mz)[1] == "SQLiteConnection"){chromHead <- readSqMassHeader(mz)}
    if(is(mz)[1] == "mzRpwiz"){
      chromHead <- mzR::chromatogramHeader(mz) #TODO: Make sure that chromatogramIndex is read as integer64
    }
    pattern <- paste0("(.?)(_Precursor_)(", ions, ")")
    chromHead <- chromHead[grepl("^[[:digit:]]+_Precursor_", chromHead[,1]),]
    chromHead[,1] <- as.integer(sub(pattern, "\\1", chromHead[,1]))
    colnames(chromHead)[1] <- "transition_group_id"
    df <- data.frame(transition_group_id = precursors$transition_group_id)
    df <- dplyr::left_join(df, chromHead, by = "transition_group_id")
    message("Fetched precursor indices from ", fileInfo$chromatogramFile[i])
    data.table::setDT(df)
  })
  names(prec2chromIndex) <- runs
  prec2chromIndex
}

dummyChromIndex <- function(precursors, masters){
  transition_group_ids <- .subset2(precursors, "transition_group_id")
  prec2chromIndex <- lapply(masters, function(run) {
    data.table("transition_group_id" = transition_group_ids,
               "chromatogramIndex" = list(c(NA_integer_, NA_integer_)))
  })
  names(prec2chromIndex) <- masters
  prec2chromIndex
}
