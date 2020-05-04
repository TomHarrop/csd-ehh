library(data.table)
library(rehh)

hh <- data2haplohh("test/drones_sorted.vcf",
                   polarize_vcf = FALSE,
                   min_perc_geno.mrk = 0.9)


# which SNP is closest to the hvr?
hvr_start <- 11771976
hvr_end <- 11772216

snps <- data.table(pos = positions(hh))
snps[, c("start_dist", "end_dist") := .(
    abs(hvr_start - pos),
    abs(hvr_end - pos)), by = pos]
closest_snp_loc <- melt(snps, id.vars = "pos")[which.min(value), pos]
closest_snp <- snps[, .I[pos == closest_snp_loc]]

# testing testing
# closest_snp <- 501

# calculate EHH and EHHs
ehh <- calc_ehh(hh, mrk = closest_snp)
ehhs <- calc_ehhs(hh, mrk = closest_snp)
plot(ehh)
plot(ehhs)

# furcation plots? no
furc <- calc_furcation(hh, mrk = closest_snp, phased = FALSE)
plot(furc, allele = 1)
h <- calc_haplen(furc)
plot(h)
haplen <- data.table(h[[4]])
haplen[, mean(MAX - MIN, na.rm = TRUE)]
hap_start <- haplen[, as.integer(names(sort(table(MIN),decreasing=TRUE)[1]))]
hap_end <- haplen[, as.integer(names(sort(table(MAX),decreasing=TRUE)[1]))]

# look at markers in haplotype
is <- seq(closest_snp - 10, closest_snp + 10)
is <- snps[, .I[pos >= hap_start & pos <= hap_end]]
snps[is]

hh_sub <- subset(hh, select.mrk = is, min_perc_geno.mrk = 0.9)
plot(hh_sub)
