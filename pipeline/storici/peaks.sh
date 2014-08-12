#! /usr/bin/env bash

#BSUB -J peaks[1-13]
#BSUB -e peaks.%J.%I.err
#BSUB -o peaks.%J.%I.out
#BSUB -q short

<<DOC
call peaks using macs2.
DOC

set -o nounset -o pipefail -o errexit -x

source $CONFIG
sample=${SAMPLES[$(($LSB_JOBINDEX - 1))]}

results=$RESULT/$sample
peakresults="$results/peaks"

# yeast genome size
genomesize=12e6

# narrowPeak autosql
ucscdir=/vol1/software/modules-sw/ucsc/build/v286
asfile=$ucscdir/kent/src/hg/lib/encode/narrowPeak.as

if [[ ! -f $peakresults ]]; then
    mkdir -p $peakresults
fi

strands=("all" "pos" "neg")

for strand in ${strands[@]}; do
    for align_mode in ${ALIGN_MODES[@]}; do

        exp_name="$peakresults/$sample.$strand.align.$align_mode"

        # these filenames are generated by macs2
        peak="${exp_name}_peaks.bed"
        narrowpeak="${exp_name}_peaks.narrowPeak"

        bigbed="${exp_name}_peaks.bb"

        bam=$results/alignment/$sample.align.$align_mode.bam

        macs2 callpeak -t $bam \
            -n $exp_name \
            --keep-dup all \
            --nomodel \
            --tsize 25 \
            --extsize 50 \
            --gsize $genomesize \
            --call-summits

        # sometimes the score exceeds the maximum (1000) defined by the
        # narrowPeak spec. Reformat the narrowPeak file to covert >= 1000
        # to 1000
        narrowpeak_tmpfile="$narrowpeak.tmp"
        awk 'BEGIN {OFS="\t"} \
                   { if ($5 > 1000) $5 = 1000; print $0}' \
            < $narrowpeak \
            > $narrowpeak_tmpfile
        mv $narrowpeak_tmpfile $narrowpeak
        
        bedToBigBed -type=bed6+4 -as=$asfile \
            $narrowpeak $CHROM_SIZES $bigbed

    done
done

