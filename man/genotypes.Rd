% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/genotypes.R
\name{genotypes}
\alias{genotypes}
\title{Get genotype data for one or multiple users.}
\usage{
genotypes(snp = NA, userid = NA, df = FALSE, ...)
}
\arguments{
\item{snp}{SNP name.}

\item{userid}{ID of openSNP user.}

\item{df}{Return data.frame (TRUE) or not (FALSE) - default = FALSE.}

\item{...}{Curl options passed on to \code{\link[httr]{GET}}.}
}
\value{
List (or data.frame) of genotypes for specified user(s) at a 
certain SNP.
}
\description{
Get genotype data for one or multiple users.
}
\examples{
\dontrun{
genotypes(snp='rs9939609', userid=1)
genotypes('rs9939609', userid='1,6,8', df=TRUE)
genotypes('rs9939609', userid='1-2', df=FALSE)
}
}

