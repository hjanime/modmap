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

export ASSEMBLIES=("sacCer1" "sacCer2" "sacCer3")
export PIPELINE=$HOME/devel/modmap/pipeline/storici
export CONFIG=$PIPELINE/config.sh

for assembly in ${ASSEMBLIES[@]}; do

    source $CONFIG

    # reassign assembly-specific variables
    export ASSEMBLY=$assembly
    # XXX DEBUG provides a directory extension ("common-debug"), or
    # nothing ("common")
    export RESULT=$HOME/projects/collab/storici-lab/results/common$DEBUG/$assembly

    export BOWTIEIDX=$HOME/ref/genomes/$assembly/$assembly
    export CHROM_SIZES=$HOME/ref/genomes/$assembly/$assembly.chrom.sizes
    export GTF=$HOME/ref/genomes/$assembly/sgdGene.$assembly.gtf
    export FASTA=$HOME/ref/genomes/$assembly/$assembly.fa
    
    job_array="[1-$NUM_SAMPLES]"

    # 1 job for each of 3 assemblies
    bsub -J "bkgd_freqs[1-3]" \
        < $PIPELINE/background_nuc_freqs.sh

    # job names look like: align_sacCer1[1-10]
    bsub -J "align_$ASSEMBLY$job_array" \
        < $PIPELINE/1_align.sh

    bsub -J "peaks_$ASSEMBLY$job_array" \
        -w "done('align_$ASSEMBLY[*]')" \
        < $PIPELINE/peaks.sh

    # jobs are dependent among individual job indices
    bsub -J "coverage_$ASSEMBLY$job_array" \
        -w "done('align_$ASSEMBLY[*]')" \
        < $PIPELINE/2_coverage.sh 

    bsub -J "nuc_freqs_$ASSEMBLY$job_array" \
        -w "done('align_$ASSEMBLY[*]') && \
            done('bkgd_freqs*')" \
        < $PIPELINE/3_nuc_freqs.sh

    bsub -J "origin_anal_$ASSEMBLY$job_array" \
        -w "done('align_$ASSEMBLY[*]')" \
        < $PIPELINE/4_origin_analysis.sh

    bsub -J "exp_anal_$ASSEMBLY$job_array" \
        -w "done('align_$ASSEMBLY[*]')" \
        < $PIPELINE/expression_analysis.sh

    # wait until *all* coverage jobs are complete
    bsub -J "summary_table_$ASSEMBLY" \
        -w "done('coverage_$ASSEMBLY*')" \
        < $PIPELINE/6_summary_table.sh

    bsub -J "plots_$ASSEMBLY$job_array" \
        -w "done('origin_anal_$ASSEMBLY[*]') && \
            done('nuc_freqs_$ASSEMBLY[*]') && \
            done('exp_anal_$ASSEMBLY[*]')" \
        < $PIPELINE/5_plots.sh

    bsub -J "tracklines_$ASSEMBLY" \
        < $PIPELINE/tracklines.sh

done
