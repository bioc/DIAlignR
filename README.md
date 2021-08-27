[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg?style=flat)](http://bioconda.github.io/recipes/bioconductor-dialignr/README.html)
[![European Galaxy server](https://img.shields.io/badge/usegalaxy-.eu-brightgreen?logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAASCAYAAABB7B6eAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAACXBIWXMAAAsTAAALEwEAmpwYAAACC2lUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNS40LjAiPgogICA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPgogICAgICA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIgogICAgICAgICAgICB4bWxuczp0aWZmPSJodHRwOi8vbnMuYWRvYmUuY29tL3RpZmYvMS4wLyI+CiAgICAgICAgIDx0aWZmOlJlc29sdXRpb25Vbml0PjI8L3RpZmY6UmVzb2x1dGlvblVuaXQ+CiAgICAgICAgIDx0aWZmOkNvbXByZXNzaW9uPjE8L3RpZmY6Q29tcHJlc3Npb24+CiAgICAgICAgIDx0aWZmOk9yaWVudGF0aW9uPjE8L3RpZmY6T3JpZW50YXRpb24+CiAgICAgICAgIDx0aWZmOlBob3RvbWV0cmljSW50ZXJwcmV0YXRpb24+MjwvdGlmZjpQaG90b21ldHJpY0ludGVycHJldGF0aW9uPgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4KD0UqkwAAAn9JREFUOBGlVEuLE0EQruqZiftwDz4QYT1IYM8eFkHFw/4HYX+GB3/B4l/YP+CP8OBNTwpCwFMQXAQPKtnsg5nJZpKdni6/6kzHvAYDFtRUT71f3UwAEbkLch9ogQxcBwRKMfAnM1/CBwgrbxkgPAYqlBOy1jfovlaPsEiWPROZmqmZKKzOYCJb/AbdYLso9/9B6GppBRqCrjSYYaquZq20EUKAzVpjo1FzWRDVrNay6C/HDxT92wXrAVCH3ASqq5VqEtv1WZ13Mdwf8LFyyKECNbgHHAObWhScf4Wnj9CbQpPzWYU3UFoX3qkhlG8AY2BTQt5/EA7qaEPQsgGLWied0A8VKrHAsCC1eJ6EFoUd1v6GoPOaRAtDPViUr/wPzkIFV9AaAZGtYB568VyJfijV+ZBzlVZJ3W7XHB2RESGe4opXIGzRTdjcAupOK09RA6kzr1NTrTj7V1ugM4VgPGWEw+e39CxO6JUw5XhhKihmaDacU2GiR0Ohcc4cZ+Kq3AjlEnEeRSazLs6/9b/kh4eTC+hngE3QQD7Yyclxsrf3cpxsPXn+cFdenF9aqlBXMXaDiEyfyfawBz2RqC/O9WF1ysacOpytlUSoqNrtfbS642+4D4CS9V3xb4u8P/ACI4O810efRu6KsC0QnjHJGaq4IOGUjWTo/YDZDB3xSIxcGyNlWcTucb4T3in/3IaueNrZyX0lGOrWndstOr+w21UlVFokILjJLFhPukbVY8OmwNQ3nZgNJNmKDccusSb4UIe+gtkI+9/bSLJDjqn763f5CQ5TLApmICkqwR0QnUPKZFIUnoozWcQuRbC0Km02knj0tPYx63furGs3x/iPnz83zJDVNtdP3QAAAABJRU5ErkJggg==)](https://usegalaxy.eu/root?tool_id=toolshed.g2.bx.psu.edu/repos/galaxyp/dialignr/dialignr)

# DIAlignR
DIAlignR is an R package for retention time alignment of targeted mass spectrometric data, including DIA and SWATH-MS data. This tool works with MS2 chromatograms directly and uses dynamic programming for alignment of raw chromatographic traces. DIAlignR uses a hybrid approach of global (feature-based) and local (raw data-based) alignment to establish correspondence between peaks.

[![Travis build status](https://travis-ci.com/shubham1637/DIAlignR.svg?branch=master)](https://travis-ci.com/shubham1637/DIAlignR)

# Documentation
For documentation please see [our vignette](https://htmlpreview.github.io/?https://github.com/shubham1637/DIAlignR/master/vignettes/DIAlignR-vignette.html).

# Developing C++ code
```
cd DIAlignR
mkdir build && cd build
cmake -B. -H.. 
make clean && make && make test
make runTest3
cd ..
```

Documenting C++ code
```
sudo apt install doxygen doxygen-gui 
sudo apt install graphviz
cd DIAlignR
cd src
doxygen doc/Doxyfile
```

# Installing Rcompression
`devtools::install_github("omegahat/Rcompression")`

# Docker
## Pull image
```
docker push singjust/dialignr:2.0.0
```

## Build image
```
docker build --no-cache -t singjust/dialignr:2.0.0 .
```

## Run Command
```
$docker run -it --rm -v `pwd`:/data singjust/dialignr:2.0.0

Name:
        Run DIAlignR's alignTargetedRuns via the Command Line

    Usage:
        Rscript alignTargetedRuns_cli.R --dataPath=/data/ [args] | --help

        Example: Rscript alignTargetedRuns_cli.R --dataPath=/data/osw/ --params=context:experiment-wide,maxFdrQuery:0.01

        Example2: Rscript alignTargetedRuns_cli.R --dataPath=/data/osw/ --oswMerged=FALSE --params=context:experiment-wide,maxFdrQuery:0.01 --runs=run0,run1,run2 --peps=0,1 --applyFun=BiocParallel::bplapply --regBioCP=BiocParallel::register(BiocParallel::MulticoreParam(workers=4,progressbar=TRUE))

    Options:
        --dataPath: path to xics and osw directory.
        --outFile: name of the output file.
        --oswMerged: TRUE for experiment-wide FDR and FALSE for run-specific FDR by pyprophet.
        --params: Parameters for the alignment functions generated from DIAlignR::paramsDIAlignR(). Separate keys and values using a ':', and separate parameters using ','. Example: --params=context:experiment-wide,maxFdrQuery:0.01,fitEMG:TRUE
        --runs: names of xics file without extension. Separate runs using ','. Example: --runs=run0,run1,run2
        --refRun: reference for alignment. If no run is provided, m-score is used to select reference run.
        --peps: ids of peptides to be aligned. If NULL, align all peptides. Separate peptide ids using ','. Example--peps=1,2,3
        --appyFun: value must be either lapply or BiocParallel::bplapply.
        --regBioCP: If using BiocParallel::bplapply, register cores to use. Example: --regBioCP=BiocParallel::register(BiocParallel::MulticoreParam(workers=4,progressbar=TRUE)) . Make sure there are no spaces in this command
        --help: Display this help message
```

## Example
```
docker run -it --rm -v `pwd`:/data singjust/dialignr:2.0.0 --dataPath=/data/ --outFile=/data/dialignr
```

# Snakemake
To run the snakemake workflow, you need to ensure you have [snakemake](https://snakemake.readthedocs.io/en/stable/getting_started/installation.html) and [singularity](https://sylabs.io/guides/3.0/user-guide/installation.html#build-and-install-an-rpm) installed.

To change parameters for your experiment, edit the input, output and parameters in the [snakemake/Snakefile.dialignr](https://github.com/singjc/DIAlignR/blob/feature/docker/snakemake/Snakefile.dialignr) file.

## Run Command
```
$bash cmd.sh
```

# Citation
If you use the provided algorithms or the package, please cite our paper:

Gupta S, Ahadi S, Zhou W, Röst H. "DIAlignR Provides Precise Retention Time Alignment Across Distant Runs in DIA and Targeted Proteomics." Mol Cell Proteomics. 2019 Apr;18(4):806-817. doi: https://doi.org/10.1074/mcp.TIR118.001132 Epub 2019 Jan 31.

CNPN 2018 Poster doi: https://doi.org/10.6084/m9.figshare.6200837.v1     
HUPO 2018 Poster doi: https://doi.org/10.6084/m9.figshare.7121696.v2     
