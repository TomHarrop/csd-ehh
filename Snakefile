#!/usr/bin/env python3

'''

PLAN:

- measure haplotype length from the HVR
- genotype drones in this region
- phase & genotype pools in this region and see if we get the haplotype back


# HVR: NC_037640.1:11771976-11772216
# CSD: NC_037640.1:11771679-11781139
# HAP: NC_037640.1:11763366-11784228    # just covers CSD
# HAP: NC_037640.1:11726078-11825888    # closest SNP + 10 each side
# REG: NC_037640.1:11721078-11830888    # closest 10 + 5kb for mapping

# use -m2 -M2 to get biallelic only

bcftools view \
    -S <( grep "_drone" data/cnv_map.txt | cut -f1 ) \
    --regions NC_037640.1 \
    -v snps \
    --exclude "F_MISSING>0.1" \
    data/filtered.vcf.gz \
    > test/drones.vcf

bcftools sort test/drones.vcf > test/drones_sorted.vcf

bcftools view \
    -S <( grep -v "_drone" data/cnv_map.txt | cut -f1 ) \
    --regions NC_037640.1:11726078-11825888 \
    -v snps \
    --exclude "F_MISSING>0.1" \
    data/filtered.vcf.gz \
    > test/pools_region.vcf


# subset the bam file
samtools view \
    -R <( grep -v "_drone" ../../data/cnv_map.txt | cut -f1 ) \
    /Volumes/archive/deardenlab/tomharrop/projects/bb-drones-pools-201911/output/010_genotypes/merged.bam \
    -bh \
    -@ 7 \
    NC_037640.1:11721078-11830888 \
    > pools.bam
samtools index pools.bam

# add phase info to the drones file
# CHROM, POS, PS, PS
# echo "CHROM POS PS" > test/annot.txt    # WATCH TABS

Rscript src/add_phase_set.R \
    test/drones_sorted.vcf \
    test/drones_phased_noheader.vcf

# test/annots.hdr
##FORMAT=<ID=PS,Number=1,Type=Integer,Description="Phase set">

cat <( grep "^##" test/drones_sorted.vcf ) \
    test/annots.hdr \
    <( grep "^#[^#]" test/drones_sorted.vcf ) \
    test/drones_phased_noheader.vcf \
    > test/drones_phased.vcf

# YOU PROBABLY HAVE TO RENAME SAMPLES FIRST! (FOR PHASING)
# OR RUN PER-INDIV
# ACTUALLY BOTH!!!!! (but it works, per-indiv. need a wider region.
)

singularity exec shub://TomHarrop/variant-utils:whatshap_61481b6 \
    whatshap phase \
    -o test/pools_phased.vcf \
    test/pools_region.vcf \
    test/pools.bam \
    test/drones_phased.vcf \
    &> whatshap_log.txt

singularity exec shub://TomHarrop/variant-utils:whatshap_0.18 \
    whatshap stats test/pools_region.vcf

singularity exec shub://TomHarrop/variant-utils:whatshap_0.18 \
    whatshap stats test/drones_phased.vcf

singularity exec shub://TomHarrop/variant-utils:whatshap_61481b6 \
    whatshap stats \
        --sample BB34_pool \
        test/pools_phased.vcf


# PER-INDIV w/ BB34
bcftools view \
    -s BB34_drone \
    test/drones_phased.vcf \
    > test/BB34_drone.vcf

bgzip test/BB34_drone.vcf
tabix -p vcf test/BB34_drone.vcf.gz
samtools faidx \
    data/GCF_003254395.2_Amel_HAv3.1_genomic.fna \
    NC_037640.1:11726078-11825888 \
    | bcftools consensus \
    test/BB34_drone.vcf.gz \
    > test/BB34_drone.fa

# CHANGE READ NAME IN test/BB34_drone.fa TO BB34

minimap2 \
    -a -x asm5 \
    -R '@RG\tID:BB34\tSM:BB34' \
    data/GCF_003254395.2_Amel_HAv3.1_genomic.fna \
    test/BB34_drone.fa \
    | samtools view -bh \
    > test/BB34_drone.bam

samtools index test/BB34_drone.bam

bcftools view \
    -s BB34_pool \
    test/pools_region.vcf \
    > test/BB34_pool.vcf

# rename stuff
#rename_pool.txt
BB34_pool BB34
#rename_drone.txt
BB34_drone BB34

bcftools reheader \
    -s rename_pool.txt \
    test/BB34_pool.vcf \
    > test/BB34_pool.renamed.vcf

bcftools reheader \
    -s rename_drone.txt \
    test/BB34_drone.vcf.gz \
    > test/BB34_drone.renamed.vcf.gz


samtools view -h \
    -r "BB34_pool" \
    test/pools.bam \
    | samtools addreplacerg \
    -r "ID:BB34" \
    -r "SM:BB34" \
    -O BAM \
    - \
    > test/BB34_pool_reads.bam

samtools index test/BB34_pool_reads.bam

# WORKS! (the short reads don't tend to cover multiple snps, though)
singularity exec whatshap_61481b6.sif \
    whatshap phase \
    -o test/BB34_phased.vcf \
    test/BB34_pool.renamed.vcf \
    test/BB34_drone.bam \
    test/BB34_pool_reads.bam


singularity exec whatshap_61481b6.sif \
    whatshap stats test/BB34_phased.vcf

singularity exec shub://TomHarrop/variant-utils:shapeit_v2.r904 \
    shapeit \
    --input-vcf test/drones_sorted.vcf \
    -O test/phased \
    -T 8

'''
