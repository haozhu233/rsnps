#' Query NCBI's dbSNP for information on a set of SNPs
#' 
#' @export
#' @param SNPs A vector of SNPs (rs numbers).
#' @param ... Further named parameters passed on to \code{\link[httr]{config}} to debug curl.
#' @examples \dontrun{
#' SNPs <- c("rs332", "rs420358", "rs1837253", "rs1209415715", "rs111068718")
#' NCBI_snp_query2(SNPs)
#' NCBI_snp_query2("123456") ## invalid: must prefix with 'rs'
#' NCBI_snp_query2("rs420358")
#' NCBI_snp_query2("rs332") # warning, merged into new one
#' NCBI_snp_query2("rs121909001") 
#' NCBI_snp_query2("rs1837253")
#' NCBI_snp_query2("rs1209415715") # no data available
#' NCBI_snp_query2("rs111068718") # chromosomal information may be unmapped
#' }

NCBI_snp_query2 <- function(SNPs, ...) {
  tmp <- sapply( SNPs, function(x) { 
    grep( "^rs[0-9]+$", x) 
  })
  if ( any( sapply( tmp, length ) == 0 ) ) {
    stop("not all items supplied are prefixed with 'rs';\n",
         "you must supply rs numbers and they should be prefixed with ",
         "'rs', e.g. rs420358")
  }
  url <- "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"
  res <- GET(url, query = list(db = 'snp', retmode = 'flt', rettype = 'flt', id = paste( SNPs, collapse = ",")), ...)
  stop_for_status(res)
  tmp <- content(res, "text")
  tmpsplit <- strsplit(tmp, "\n\n")[[1]]
  return( structure(setNames(lapply(tmpsplit, parse_data), SNPs), class = "dbsnp") )
  Sys.sleep(0.33)
}

#' @export
print.dbsnp <- function(x, ...) {
  cat("<dbsnp>", sep = "\n")
  cat(sprintf("   SNPs: %s", paste0(names(x), collapse = ", ")), sep = "\n")
  cat("   Summary:", sep = "\n")
  dfs <- list()
  for (i in seq_along(x)) {
    z <- x[[i]]
    ctg <- z$ctg
    dfs[[i]] <- data.frame(query = names(x[i]), 
               marker = z$rs$snp,
               organism = rn(z$rs$organism), 
               chromsome = rn(ctg$chromosome),
               assembly = rn(ctg$groupLabel),
               alleles = rn(z$snp$observed),
               minor = rn(z$gmaf$allele),
               maf = rn(z$gmaf$freq),
               BP = rn(ctg$physmapInt),
               stringsAsFactors = FALSE)
  }
  dfs <- do.call("rbind.data.frame", dfs)
  row.names(dfs) <- NULL
  print(dfs)
}

rn <- function(x) {
  if (is.null(x)) {
    NA
  } else {
    x
  }
}

parse_data <- function(x) {
  bits <- strsplit(x, "\n")[[1]]
  rs <- pull_vars(rs_vars, "rs", bits)
  ss <- pull_vars(ss_vars, "ss", bits, multi = TRUE)
  snp <- pull_vars(SNP_vars, "SNP", bits)
  clinsig <- pull_vars(CLINSIG_vars, "CLINSIG", bits)
  gmaf <- pull_vars(GMAF_vars, "GMAF", bits)
  ctg <- pull_vars(CTG_vars, "CTG", bits, TRUE)
  loc <- pull_vars(LOC_vars, "LOC", bits, TRUE)
  seq <- pull_vars(SEQ_vars, "SEQ", bits, TRUE)
  list(rs = rs, ss = ss, snp = snp, clinsig = clinsig, gmaf = gmaf, 
       ctg = ctg, loc = loc, seq = seq)
}

pull_line <- function(var_set, x) {
  line_set <- list()
  for (j in seq_along(var_set)) {
    if (is(var_set[[j]], "numeric")) {
      line_set[[ names(var_set[j]) ]] <- strtrim(x[ var_set[[j]] ])
    } else if (is(var_set[[j]], "character")) {
      line_set[[ names(var_set[j]) ]] <- strtrim(sub(var_set[[j]], "", grep(var_set[[j]], x, value = TRUE)))
    }
  }
  line_set[vapply(line_set, length, numeric(1)) == 0] <- NULL
  return(line_set)
}

pull_vars <- function(var_set, line_start, line, multi = FALSE) {
  lineset <- strsplit(line[grep(line_start, substring(line, 0, 4))], "\\|")
  if (length(lineset) == 0) {
    NULL
  } else {
    if (multi) {
      pulled_vars <- list()
      for (i in seq_along(lineset)) {
        pulled_vars[[i]] <- pull_line(var_set, lineset[[i]])
      }
      if (length(pulled_vars) == 1) {
        pulled_vars[[1]]
      } else {
        pulled_vars
      }
    } else {
      line <- lineset[[1]]
      pull_line(var_set, line)
    }
  }
}

rs_vars <- list("snp" = 1,
                "organism" = 2,
                "taxId" = 3,
                "snpClass" = 4,
                "genotype" = "genotype=",
                "rsLinkout" = "submitterlink=",
                "date" = "updated ")

ss_vars <- list("ssId" = 1,
                "handle" = 2,
                "locSnpId" = 3,
                "orient" = "orient=",
                "exemplar" = "ss_pick=")

SNP_vars <- list("observed" = "alleles=",
                 "value" = "het=",
                 "stdError" = "se\\(het\\)=",
                 "validated" = "validated=",
                 "validProbMin" = "min_prob=",
                 "validProbMax" = "max_prob=",
                 "validation" = "suspect=",
                 "AlleleOrigin" = c('unknown',
                                    'germline',
                                    'somatic',
                                    'inherited',
                                    'paternal',
                                    'maternal',
                                    'de-novo',
                                    'bipaternal',
                                    'unipaternal',
                                    'not-tested',
                                    'tested-inconclusive'),
                 "snpType" = c('notwithdrawn',
                               'artifact',
                               'gene-duplication',
                               'duplicate-submission',
                               'notspecified',
                               'ambiguous-location;',
                               'low-map-quality')
)

CLINSIG_vars <- list("ClinicalSignificance" = c('probable-pathogenic', 'pathogenic', 'other'))

GMAF_vars = list("allele" = "allele=",
                 "sampleSize" = "count=",
                 "freq" = "MAF=")

CTG_vars <- list("groupLabel" = "assembly=",
                 "chromosome" = "chr=",
                 "physmapInt" = "chr-pos=",
                 "asnFrom" = "ctg-start=",
                 "asnTo" = "ctg-end=",
                 "loctype" = "loctype=",
                 "orient" = "orient=")

LOC_vars <- list("symbol" = 2,
                 "geneId" = "locus_id=",
                 "fxnClass" = "fxn-class=",
                 "allele" = "allele=",
                 "readingFrame" = "frame=",
                 "residue" = "residue=",
                 "aaPosition" = "aa_position=",
                 "mrna_acc" = "mrna_acc=")

SEQ_vars <- list("gi" = 1,
                 "source" = "source-db=",
                 "asnFrom" = "seq-pos=",
                 "orient" = "orient=")