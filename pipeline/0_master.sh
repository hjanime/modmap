#!/usr/bin/env bash
#BSUB -J master
#BSUB -e master.%J.err
#BSUB -o master.%J.out
#BSUB -q normal
#BSUB -P storici

<<DOC
master analysis loop for storici mopmap pipeline
DOC

set -o nounset -o pipefail -o errexit -x

ASSEMBLIES=("sacCer1" "sacCer2" "sacCer3")
export PIPELINE=$HOME/devel/modmap/pipeline

for assembly in ${ASSEMBLIES[@]}; do

    source $PIPELINE/config.sh

    # reassign assembly-specific variables
    export ASSEMBLY=$assembly
    # XXX DEBUG provides a directory extension, or nothing ("")
    export RESULT=$HOME/projects/collab/storici-lab/results/common$DEBUG/$assembly

    export BOWTIEIDX=$HOME/ref/genomes/$assembly/$assembly
    export CHROM_SIZES=$HOME/ref/genomes/$assembly/$assembly.chrom.sizes
    export GTF=$HOME/ref/genomes/$assembly/sgdGene.$assembly.gtf
    export FASTA=$HOME/ref/genomes/$assembly/$assembly.fa
    
    job_array="[1-$NUM_SAMPLES]"

    bsub -J "align_$ASSEMBLY$job_array" \
        < $PIPELINE/1_align.sh

    bsub -J "coverage_$ASSEMBLY$job_array" \
        -w "done('align_$ASSEMBLY[*]')" \
        < $PIPELINE/2_coverage.sh 

    bsub -J "nuc_freqs_$ASSEMBLY$job_array" \
        -w "done('coverage_$ASSEMBLY[*]')" \
        < $PIPELINE/3_nuc_freqs.sh

    bsub -J "origin_anal_$ASSEMBLY$job_array" \
        -w "done('nuc_freqs_$ASSEMBLY[*]')" \
        < $PIPELINE/4_origin_analysis.sh

    bsub -J "plots_$ASSEMBLY$job_array" \
        -w "done('origin_anal_$ASSEMBLY[*]')" \
        < $PIPELINE/5_plots.sh

done
