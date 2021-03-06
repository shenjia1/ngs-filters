#!/usr/bin/env Rscript

##########################################################################################
# MSKCC CMO
# Identify variant present in 3 or more alternate reads in deep-sequenced FFPE pool
##########################################################################################

annotate_maf <- function(maf, fillout,
                         ffpe.count=3) {

  # identify loci with 3+ alternate reads in any normal sample
  fillout <- fillout[t_alt_count >= ffpe.count]

  # Add TAG to MAF
  if (!('TAG' %in% names(maf))) {
    maf[, TAG := str_c('chr', Chromosome,
                       ':', Start_Position,
                       '-', End_Position,
                       ':', Reference_Allele,
                       ':', Tumor_Seq_Allele2)]
  }

  if (!('FILTER' %in% names(maf))) maf$FILTER = '.'
  ffpe_pool.blacklist <- unique(fillout$TAG)
  maf.annotated <- maf[, ffpe_pool := TAG %in% ffpe_pool.blacklist]
  maf.annotated <- maf[, FILTER := ifelse(FILTER == '.' & ffpe_pool == TRUE, 'ffpe_pool',
                                          ifelse(FILTER != '.' & ffpe_pool == TRUE,
                                                 paste0(FILTER, ',ffpe_pool'), FILTER))]

  return(maf.annotated)

}

parse_fillout <- function(fillout) {

  # Convert GetBaseCountsMultiSample output
  fillout = melt(fillout, id.vars = colnames(fillout)[1:34], variable.name = 'Tumor_Sample_Barcode') %>%
    separate(value, into = c('t_depth','t_ref_count','t_alt_count','t_var_freq'), sep = ';') %>%
    mutate(t_depth = str_extract(t_depth, regex('[0-9].*'))) %>%
    mutate(t_ref_count = str_extract(t_ref_count, regex('[0-9].*'))) %>%
    mutate(t_alt_count = str_extract(t_alt_count, regex('[0-9].*'))) %>%
    mutate(t_var_freq = str_extract(t_var_freq, regex('[0-9].*'))) %>%
    mutate(TAG = str_c('chr', Chrom, ':', Start, '-', Start, ':', Ref, ':', Alt))

  # Note, variant might be present mutliple times if occuring in more than one sample, fix this at the fillout step
  # by de-duping the MAF?
  fillout = fillout[!duplicated(fillout$TAG),]

  # Return
  fillout

}

if( ! interactive() ) {

  pkgs = c('data.table', 'argparse', 'reshape2', 'dplyr', 'tidyr', 'stringr')
  junk <- lapply(pkgs, function(p){suppressPackageStartupMessages(require(p, character.only = T))})
  rm(junk)

  parser=ArgumentParser()
  parser$add_argument('-m', '--maf', type='character', help='SOMATIC_FACETS.vep.maf file', default = 'stdin')
  parser$add_argument('-f', '--fillout', type='character', help='GetBaseCountsMultiSample output')
  parser$add_argument('-fo', '--fillout_format', type='double', help='GetBaseCountsMultiSample output format, MAF(1), Tab-delimited with VCF coordinates(2:default)', default=2)
  parser$add_argument('-r', '--read_count', type='double', default=3, help='FFPE pool read-count threshold')
  parser$add_argument('-o', '--outfile', type='character', help='Output file', default = 'stdout')
  args=parser$parse_args()

  if (args$maf == 'stdin') { maf = suppressWarnings(fread('cat /dev/stdin', showProgress = F))
  } else { maf <- suppressWarnings(fread(args$maf, colClasses=c(Chromosome="character"), showProgress = F)) }
  fillout <- suppressWarnings(fread(args$fillout, colClasses=c(Chromosome="character"), showProgress = F))
  fillout.format<-args$fillout_format
  alt.reads <- args$read_count
  outfile <- args$outfile
if(fillout.format == 2){
  parsed_fillout = parse_fillout(fillout)
}else{
	# index
	fillout[, TAG := stringr::str_c('chr', Chromosome,
					':', Start_Position,
					'-', End_Position,
					':', Reference_Allele,
					':', Tumor_Seq_Allele2)]
	fillout = fillout[!duplicated(fillout$TAG),]
	parsed_fillout = fillout
}

  maf.out <- annotate_maf(maf, parsed_fillout,alt.reads)
  if (outfile == 'stdout') { write.table(maf.out, stdout(), na="", sep = "\t", col.names = T, row.names = F, quote = F)
  } else { write.table(maf.out, outfile, na="", sep = "\t", col.names = T, row.names = F, quote = F) }
}