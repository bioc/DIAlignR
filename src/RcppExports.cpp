// Generated by using Rcpp::compileAttributes() -> do not edit by hand
// Generator token: 10BE3573-1514-4C36-9D1C-5A225CD40393

#include <Rcpp.h>

using namespace Rcpp;

// getSeqSimMat
NumericMatrix getSeqSimMat(std::string seq1, std::string seq2, float Match, float MisMatch);
RcppExport SEXP _DIAlignR_getSeqSimMat(SEXP seq1SEXP, SEXP seq2SEXP, SEXP MatchSEXP, SEXP MisMatchSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< std::string >::type seq1(seq1SEXP);
    Rcpp::traits::input_parameter< std::string >::type seq2(seq2SEXP);
    Rcpp::traits::input_parameter< float >::type Match(MatchSEXP);
    Rcpp::traits::input_parameter< float >::type MisMatch(MisMatchSEXP);
    rcpp_result_gen = Rcpp::wrap(getSeqSimMat(seq1, seq2, Match, MisMatch));
    return rcpp_result_gen;
END_RCPP
}
// getChromSimMat
NumericMatrix getChromSimMat(Rcpp::List l1, Rcpp::List l2, std::string Normalization, std::string SimType, double dotProdThresh, double cosAngleThresh);
RcppExport SEXP _DIAlignR_getChromSimMat(SEXP l1SEXP, SEXP l2SEXP, SEXP NormalizationSEXP, SEXP SimTypeSEXP, SEXP dotProdThreshSEXP, SEXP cosAngleThreshSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< Rcpp::List >::type l1(l1SEXP);
    Rcpp::traits::input_parameter< Rcpp::List >::type l2(l2SEXP);
    Rcpp::traits::input_parameter< std::string >::type Normalization(NormalizationSEXP);
    Rcpp::traits::input_parameter< std::string >::type SimType(SimTypeSEXP);
    Rcpp::traits::input_parameter< double >::type dotProdThresh(dotProdThreshSEXP);
    Rcpp::traits::input_parameter< double >::type cosAngleThresh(cosAngleThreshSEXP);
    rcpp_result_gen = Rcpp::wrap(getChromSimMat(l1, l2, Normalization, SimType, dotProdThresh, cosAngleThresh));
    return rcpp_result_gen;
END_RCPP
}
// setAffineAlignObj_S4
S4 setAffineAlignObj_S4(int ROW_SIZE, int COL_SIZE);
RcppExport SEXP _DIAlignR_setAffineAlignObj_S4(SEXP ROW_SIZESEXP, SEXP COL_SIZESEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< int >::type ROW_SIZE(ROW_SIZESEXP);
    Rcpp::traits::input_parameter< int >::type COL_SIZE(COL_SIZESEXP);
    rcpp_result_gen = Rcpp::wrap(setAffineAlignObj_S4(ROW_SIZE, COL_SIZE));
    return rcpp_result_gen;
END_RCPP
}
// setAlignObj_S4
S4 setAlignObj_S4(int ROW_SIZE, int COL_SIZE);
RcppExport SEXP _DIAlignR_setAlignObj_S4(SEXP ROW_SIZESEXP, SEXP COL_SIZESEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< int >::type ROW_SIZE(ROW_SIZESEXP);
    Rcpp::traits::input_parameter< int >::type COL_SIZE(COL_SIZESEXP);
    rcpp_result_gen = Rcpp::wrap(setAlignObj_S4(ROW_SIZE, COL_SIZE));
    return rcpp_result_gen;
END_RCPP
}
// doAlignment_S4
S4 doAlignment_S4(NumericMatrix s, int signalA_len, int signalB_len, float gap, bool OverlapAlignment);
RcppExport SEXP _DIAlignR_doAlignment_S4(SEXP sSEXP, SEXP signalA_lenSEXP, SEXP signalB_lenSEXP, SEXP gapSEXP, SEXP OverlapAlignmentSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< NumericMatrix >::type s(sSEXP);
    Rcpp::traits::input_parameter< int >::type signalA_len(signalA_lenSEXP);
    Rcpp::traits::input_parameter< int >::type signalB_len(signalB_lenSEXP);
    Rcpp::traits::input_parameter< float >::type gap(gapSEXP);
    Rcpp::traits::input_parameter< bool >::type OverlapAlignment(OverlapAlignmentSEXP);
    rcpp_result_gen = Rcpp::wrap(doAlignment_S4(s, signalA_len, signalB_len, gap, OverlapAlignment));
    return rcpp_result_gen;
END_RCPP
}
// doAffineAlignment_S4
S4 doAffineAlignment_S4(NumericMatrix s, int signalA_len, int signalB_len, float go, float ge, bool OverlapAlignment);
RcppExport SEXP _DIAlignR_doAffineAlignment_S4(SEXP sSEXP, SEXP signalA_lenSEXP, SEXP signalB_lenSEXP, SEXP goSEXP, SEXP geSEXP, SEXP OverlapAlignmentSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< NumericMatrix >::type s(sSEXP);
    Rcpp::traits::input_parameter< int >::type signalA_len(signalA_lenSEXP);
    Rcpp::traits::input_parameter< int >::type signalB_len(signalB_lenSEXP);
    Rcpp::traits::input_parameter< float >::type go(goSEXP);
    Rcpp::traits::input_parameter< float >::type ge(geSEXP);
    Rcpp::traits::input_parameter< bool >::type OverlapAlignment(OverlapAlignmentSEXP);
    rcpp_result_gen = Rcpp::wrap(doAffineAlignment_S4(s, signalA_len, signalB_len, go, ge, OverlapAlignment));
    return rcpp_result_gen;
END_RCPP
}
// initializeMatrix
NumericMatrix initializeMatrix(float initVal, int ROW_SIZE, int COL_SIZE);
RcppExport SEXP _DIAlignR_initializeMatrix(SEXP initValSEXP, SEXP ROW_SIZESEXP, SEXP COL_SIZESEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< float >::type initVal(initValSEXP);
    Rcpp::traits::input_parameter< int >::type ROW_SIZE(ROW_SIZESEXP);
    Rcpp::traits::input_parameter< int >::type COL_SIZE(COL_SIZESEXP);
    rcpp_result_gen = Rcpp::wrap(initializeMatrix(initVal, ROW_SIZE, COL_SIZE));
    return rcpp_result_gen;
END_RCPP
}

static const R_CallMethodDef CallEntries[] = {
    {"_DIAlignR_getSeqSimMat", (DL_FUNC) &_DIAlignR_getSeqSimMat, 4},
    {"_DIAlignR_getChromSimMat", (DL_FUNC) &_DIAlignR_getChromSimMat, 6},
    {"_DIAlignR_setAffineAlignObj_S4", (DL_FUNC) &_DIAlignR_setAffineAlignObj_S4, 2},
    {"_DIAlignR_setAlignObj_S4", (DL_FUNC) &_DIAlignR_setAlignObj_S4, 2},
    {"_DIAlignR_doAlignment_S4", (DL_FUNC) &_DIAlignR_doAlignment_S4, 5},
    {"_DIAlignR_doAffineAlignment_S4", (DL_FUNC) &_DIAlignR_doAffineAlignment_S4, 6},
    {"_DIAlignR_initializeMatrix", (DL_FUNC) &_DIAlignR_initializeMatrix, 3},
    {NULL, NULL, 0}
};

RcppExport void R_init_DIAlignR(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
