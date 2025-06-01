#!/bin/bash

# Deps:
# - Gnuplot
# - Miller (mlr)

# Only update every 7 days
[[ $(date +%s -r RESPVIRUSES_sentinella.csv) -lt $(date +%s --date="7 days ago") || ! -e  RESPVIRUSES_sentinella.csv ]] && curl -L -o RESPVIRUSES_sentinella.csv https://idd.bag.admin.ch/api/v1/export/latest/RESPVIRUSES_sentinella/csv

# Columns:
# 0: valueCategory (samples vs detections)
# >> 1: temporal: week (2020-W42)
# 2: temporal_type
# 3: georegion
# 4: georegion_type
# >> 5: pathogen
# >> 6: type (pathogen type, e.g. "A" or "B" for pathogen=influenza - or "all" for an aggregation)
# 7: subtype (pathogen subtype, e.g. "h1n1", "yamagata", etc.)
# >> 8: testResult ("positive", "negative", "all"
# 9: testResult_type ("pcr", "hht" (haemagglutination test? This might be used for subtyping, unclear.))
# >> 10: value (count: 0-inf)
# 11: prctPathogenType (usually NA)
# 12: prctPathogenSubtype (usually also NA)
# 13: prctTypeSubtype (usually also also NA)
# 14: prctPathogen
# 15: lowerCiPathogen
# 16: upperCiPathogen
# 17: prctPathogenMean3w
# 18: prctSamples
# 19: dataComplete
# 20: defaultView

# Gnuplot cannot parse week-of-year on input (%W/%U are supported only for
# output...). Actually, miller can't either, but we can convert %U to %j by hand:
mlr -x --csv put 'NR > 1; $parts = splita($[[[2]]], "-W"); $[[[2]]] = $parts[1] . "-" . string(int($parts[2], 10)*7)' RESPVIRUSES_sentinella.csv > tmp_dates_adjusted.csv

pathogens=( "adenovirus" "influenza" "respiratory_syncytial_virus" "rhinovirus" "sars-cov-2" "all" )
declare -A titles=( ["all"]="All positives" ["adenovirus"]="Adenovirus" ["influenza"]="Influenza" ["respiratory_syncytial_virus"]="RSV" ["sars_cov_2"]="Covid" ["rhinovirus"]="Rhinovirus" )
plots=()

for pathogen in "${pathogens[@]}"
do
    mlr -x --csv filter "\$valueCategory == \"detections\" && \$pathogen == \"${pathogen}\" &&  \$type == \"all\" && \$testResult == \"positive\"" tmp_dates_adjusted.csv | mlr --csv cut -f temporal,value > tmp_${pathogen}.csv
    plots+=("'tmp_${pathogen}.csv' using 1:2 skip 1 with lines title \"${titles[${pathogen//-/_}]}\"")
done

# Total samples
mlr -x --csv filter "\$valueCategory == \"samples\" && \$pathogen == \"all\" &&  \$type == \"all\" && \$testResult == \"all\"" tmp_dates_adjusted.csv | mlr --csv cut -f temporal,value > tmp_samples.csv
plots+=("'tmp_samples.csv' using 1:2 skip 1 with lines title \"Total samples\"")

# Because bash doesn't have plots.join(','):
plot=${plots[0]}
for p in "${plots[@]:1}"
do
    plot+=", ${p}"
done
echo $plot


gnuplot <<EOL
set datafile separator ','
set xdata time
set timefmt '%Y-%j'

scale=1.2
set terminal pngcairo enhanced size 1600,1200 background rgb "white" fontscale scale linewidth scale*1.1  pointscale scale*2 font ",16"
set output 'sentinella_by_pathogen.png'

set xrange ['2023-180':'2025-220']
set format x "%b-%Y"

plot $plot

EOL
