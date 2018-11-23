#!/bin/bash

FILTER=""

while getopts "hf:" opt; do
  case $opt in
        h)
                printf "Parse DHuS logs and generate bandwidth charts.\n\nUsage:\n
\t-h      \tDisplay this help\n \
\t-f <str>\tCustom plot data filter (passed to grep -E before plotting the data\n \
\n\n"
                exit 0
                ;;
        f)
                FILTER="${OPTARG}"
                ;;
  esac
done

shift $(($OPTIND - 1))
MASK=$1

if [ "$MASK" == "" ]; then
	MASK="*.log"
fi

PLOT=""
PID=$$
OUTDIR="outfiles.${PID}"

echo Generating out files by endpoint
mkdir -p "${OUTDIR}"
for f in $MASK; do
	cat $f | grep "successfully [a-z]* from" | grep zip | sed 's/\[[0-9.-]*\]\s*\[\([0-9: -]*\),[0-9]*\].*(\([0-9]*\) bytes compressed).* from http[s]*:\/\/\([^/]*\).*in \([0-9]*\) ms.*/\1 \2 \4 \3/' | awk '{ print $1" "$2" "$4" "$5" T" }' >> out.events.$$.dat

	grep "successfully synchronized" $f | sed 's/.*\]\[\([0-9][0-9\-]*\).*Synchronizer\#\([0-9][0-9]*\).*synchronized from.*:\/\/\([^\/]*\).*/s\/Syncer\2\/\3\//' | sort | uniq > out.translator.$$.dat

	cat $f | grep "query(Products)" | sed 's/\[[0-9.-]*\]\s*\[\([0-9: -]*\),[0-9]*\].*Synchronizer#\(\S*\)\s.*in \([0-9][0-9]*\)ms.*/\1 \30000 \3 Syncer\2/' | awk '{ print $1" "$2" "$4" "$5" Q" }' | sed -f out.translator.$$.dat >> out.events.$$.dat

done


sort out.events.$$.dat | awk -v outdir="$OUTDIR" '{ outfile=outdir"/"$4; print $1" "$2" "$3" "$4" "$5 >> outfile }'

wc -l ${OUTDIR}/*

echo Generating plot data
for f in $OUTDIR/*; do
	BN=`basename $f`
	cat $f | awk -v f="$BN" 'BEGIN{
	thrno=0;
} {
	etime=$1" "$2;
	gsub(":"," ",etime);
	gsub("-"," ",etime);
	ets=mktime(etime);
	dura=($3==0)? 0 : $3/1000;
	sts=ets-dura
	if ($5 =="Q") {
		thrno=0;
		thr="0" }
	else {
		thrno=thrno+1;
		thr=""thrno }
	print strftime("%04Y-%02m-%02e %02H:%02M:%02S", sts) " " strftime("%04Y-%02m-%02e %02H:%02M:%02S", ets) " " thr;
}' | sort | awk 'BEGIN{ counter=0 } {
	counter=counter+1
	if ($5 ==0) { reccolor = "rgb \"gold\"" }
	else { reccolor = "rgb \"cyan\"" }
	print "set object " counter " rect from \"" $1 " " $2 "\"," $5 " to \"" $3 " " $4 "\"," $5+1 " fc " reccolor
}' > out.$BN.$$.dat
#}' | sort | awk '{ print $5 "," $1 " " $2 "," $3 " " $4 }' > out.$BN.$$.dat

PLOT=out.$BN.$$.dat

cat << EOF > plot.$BN.dat
set xdata time
set timefmt "%Y-%m-%d %H:%M:%S"
set format x "$d.%m. %H:%M:%S"

set xrange ["2018-10-21 00:00:00":"2018-10-21 01:00:00"]
set yrange [0:20]
set terminal pdf size 19.20,10.80
set output "out.$BN.pdf"

load "out.$BN.$$.dat"

plot x

EOF

gnuplot plot.$BN.dat
done 

#rm out.*.$$.dat
#rm -rf "${OUTDIR}"
echo Data in "${OUTDIR}"
