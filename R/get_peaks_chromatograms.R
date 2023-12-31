#' Extract XICs of chromIndices
#'
#' Extracts XICs using mz object. Each chromatogram represents a transition of precursor.
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2019) + GPL-3
#' Date: 2019-12-13
#' @param mz (mzRpwiz object)
#' @param chromIndices (vector of Integers) Indices of chromatograms to be extracted.
#' @return A list of data-frames. Each data frame has elution time and intensity of fragment-ion XIC.
#' @keywords internal
#' @examples
#' dataPath <- system.file("extdata", package = "DIAlignR")
#' mzmlName<-paste0(dataPath,"/xics/hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt.chrom.mzML")
#' mz <- mzR::openMSfile(mzmlName, backend = "pwiz")
#' chromIndices <- c(37L, 38L, 39L, 40L, 41L, 42L)
#' \dontrun{
#' XIC_group <- extractXIC_group(mz, chromIndices)
#' }
extractXIC_group <- function(mz, chromIndices){
  XIC_group <- lapply(mzR::chromatograms(mz, chromIndices), as.matrix)
  if (is(XIC_group, "list") & length(XIC_group) > 1) {
    return( XIC_group )
  } else {
    return( list(XIC_group) ) # only one transition detected
  }
}


#' Extract XICs of chromIndices
#'
#' DATA_TYPE is one of 0 = mz, 1 = intensity, 2 = rt
#' Extracts XICs using connection to sqMass file Each chromatogram represents a transition of precursor.
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2020) + GPL-3
#' Date: 2020-12-25
#' @param mz (SQLiteConnection object)
#' @param chromIndices (vector of Integers) Indices of chromatograms to be extracted.
#' @return A list of data-frames. Each data frame has elution time and intensity of fragment-ion XIC.
#' @keywords internal
#' @examples
#' dataPath <- system.file("extdata", package = "DIAlignR")
#' sqName <- paste0(dataPath,"/xics/hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt.chrom.sqMass")
#' chromIndices <- c(36L, 37L, 38L, 39L, 40L, 41L)
#' \dontrun{
#' con <- DBI::dbConnect(RSQLite::SQLite(), dbname = sqName)
#' XIC_group <- extractXIC_group2(con, chromIndices)
#' DBI::dbDisconnect(con)
#' }
extractXIC_group2 <- function(con, chromIndices){
  query <- sqMassQuery(chromIndices)
  results <- DBI::dbGetQuery(con, query)
  XIC_group <- lapply(seq_along(chromIndices), function(i){
    cbind("time" = uncompressVec(results[["DATA"]][[2*i-1]],
                                 results$COMPRESSION[[2*i-1]]),
          "intensity" = uncompressVec(results[["DATA"]][[2*i]],
                                      results$COMPRESSION[[2*i]]))
  })
  XIC_group
}

xicIntersect <- function(xics){
  time <- lapply(xics, function(df) floor(df[, "time"]))
  strt <- max(sapply(time, function(v) v[1]))
  end <- min(sapply(time, function(v) v[length(v)]))
  newXICs <- lapply(seq_along(xics), function(i){
    st <- which(time[[i]] == strt)
    en <- which(time[[i]] == end)
    xics[[i]][seq(st, en),]
  })
  newXICs
}

#' Extract XICs of analytes
#'
#' For all the analytes requested, it fetches chromatogram indices from prec2chromIndex and
#' extracts chromatograms using mzPntrs.
#'
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2019) + GPL-3
#' Date: 2019-12-13
#' @param mzPntrs a list of mzRpwiz.
#' @param fileInfo (data-frame) output of getRunNames().
#' @param runs (vector of string) names of mzML files without extension.
#' @param prec2chromIndex (list of data-frames) output of getChromatogramIndices(). Each dataframe has two columns: transition_group_id and chromatogramIndex.
#' @param analytes (integer) a vector of precursor IDs.
#' @return A list of list of data-frames. Each data frame has elution time and intensity of fragment-ion XIC.
#'
#' @seealso \code{\link{getChromatogramIndices}, \link{getRunNames}}
#' @examples
#' dataPath <- system.file("extdata", package = "DIAlignR")
#' runs <- c("hroest_K120809_Strep0%PlasmaBiolRepl2_R04_SW_filt",
#'           "hroest_K120808_Strep10%PlasmaBiolRepl1_R03_SW_filt")
#' analytes <- c(32L, 898L, 2474L)
#' params <- paramsDIAlignR()
#' params[["chromFile"]] <- "mzML"
#' fileInfo <- getRunNames(dataPath = dataPath)
#' fileInfo <- updateFileInfo(fileInfo, runs)
#' precursors <- getPrecursorByID(analytes,fileInfo)
#' mzPntrs <- getMZMLpointers(fileInfo)
#' prec2chromIndex <- getChromatogramIndices(fileInfo, precursors, mzPntrs)
#' XICs <- getXICs4AlignObj(mzPntrs, fileInfo, runs, prec2chromIndex, analytes)
#' rm(mzPntrs)
#' @export
getXICs4AlignObj <- function(mzPntrs, fileInfo, runs, prec2chromIndex, analytes){
  # Select ony runs that are present in fileInfo.
  if(is(mzPntrs[[1]])[1] == "mzRpwiz") fetchXIC = extractXIC_group
  if(is(mzPntrs[[1]])[1] == "SQLiteConnection") fetchXIC = extractXIC_group2
  fileInfo <- updateFileInfo(fileInfo, runs)
  runs <- rownames(fileInfo)
  # Create empty list to store chromatograms.
  XICs <- vector("list", nrow(fileInfo))
  names(XICs) <- fileInfo$runName
  for(i in seq_along(runs)){
    runname = runs[i]
    # Get precursor to chromatogram Indices mapping.
    chromMapping <- prec2chromIndex[[runname]]
    message("Fetching XICs from run ", fileInfo$chromatogramFile[i])
    # From each run iterate over analytes.
    XICs[[i]] <- lapply(seq_along(analytes), function(j){
      analyte <- analytes[j]
      idx <- which(chromMapping[["transition_group_id"]] == analyte)
      chromIndices <- chromMapping[["chromatogramIndex"]][[idx]]
      # If chromatogram indices are missing, add NULL as XICs for the analyte.
      if(any(is.na(chromIndices))){
        warning("Chromatogram indices for ", analyte, " are missing in ", fileInfo$chromatogramFile[i])
        message("Skipping ", analyte)
        XIC_group <- NULL
      } else {
        XIC_group <- fetchXIC(mzPntrs[[runname]], chromIndices)
      }
      XIC_group
    })
    # Name the XICs as analyte(coerced as character).
    names(XICs[[i]]) <- as.character(analytes)
  }
  XICs
}

#' Get XICs of all analytes
#'
#' For all the analytes requested in runs, it first creates oswFiles, then, fetches chromatogram indices from oswFiles and
#' extract chromatograms from mzML files.
#'
#' @importFrom magrittr %>%
#' @author Shubham Gupta, \email{shubh.gupta@mail.utoronto.ca}
#'
#' ORCID: 0000-0003-3500-8152
#'
#' License: (c) Author (2019) + GPL-3
#' Date: 2019-12-13
#'
#' @inheritParams checkParams
#' @param analytes (integer) a vector of precursor IDs.
#' @param runs (vector of string) names of mzML files without extension.
#' @param dataPath (string) Path to xics and osw directory.
#' @param maxFdrQuery (numeric) A numeric value between 0 and 1. It is used to filter features from osw file which have SCORE_MS2.QVALUE less than itself.
#' @param runType (char) This must be one of the strings "DIA_Proteomics", "DIA_Metabolomics".
#' @param oswMerged (logical) TRUE for experiment-wide FDR and FALSE for run-specific FDR by pyprophet.
#' @return A list of list. Each list contains XIC-group for that run. XIC-group is a list of dataframe that has elution time and intensity of fragment-ion XIC.
#'
#' @seealso \code{\link{getXICs4AlignObj}, \link{getRunNames}, \link{analytesFromFeatures}}
#' @examples
#' dataPath <- system.file("extdata", package = "DIAlignR")
#' runs <- c("hroest_K120808_Strep10%PlasmaBiolRepl1_R03_SW_filt",
#'  "hroest_K120809_Strep10%PlasmaBiolRepl2_R04_SW_filt")
#' analytes <- c(32L, 898L, 2474L)
#' XICs <- getXICs(analytes, runs = runs, dataPath = dataPath)
#' @export
getXICs <- function(analytes, runs, dataPath = ".", maxFdrQuery = 1.0, runType = "DIA_Proteomics",
                    oswMerged = TRUE, params = paramsDIAlignR()){
  # Get fileInfo from .merged.osw file and check if names are consistent between osw and mzML files.
  fileInfo <- getRunNames(dataPath, oswMerged, params)
  fileInfo <- updateFileInfo(fileInfo, runs)

  precursors <- getPrecursorByID(analytes, fileInfo, oswMerged, runType)
  mzPntrs <- getMZMLpointers(fileInfo)
  prec2chromIndex <- getChromatogramIndices(fileInfo, precursors, mzPntrs, lapply)

  # Get Chromatogram indices for each peptide in each run.
  features <- getFeatures(fileInfo, maxFdrQuery, params[["maxIPFFdrQuery"]], runType, lapply)
  refAnalytes <-  analytesFromFeatures(features, analyteFDR = maxFdrQuery, commonAnalytes = FALSE)
  analytesFound <- intersect(analytes, refAnalytes)
  analytesNotFound <- setdiff(analytes, analytesFound)
  if(length(analytesNotFound)>0){
    message("Analytes ", paste(analytesNotFound, ", "), "not found below the FDR cutoff.")
  }

  ####################### Get XICs ##########################################

  # Get Chromatogram for each peptide in each run.
  message("Fetching Extracted-ion chromatograms from runs")
  XICs <- getXICs4AlignObj(mzPntrs, fileInfo, runs, prec2chromIndex, analytesFound)
  for(mz in mzPntrs){
    if(is(mz)[1] == "SQLiteConnection") DBI::dbDisconnect(mz)
    if(is(mz)[1] == "mzRpwiz") rm(mz)
  }
  XICs
}
