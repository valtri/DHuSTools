#!/bin/bash

# With luck, this script will be reusable in later years.
# Just run it among DHuS log files you wish to process.

# extract download data
cat dhus-*log | grep "download by user" | grep completed | sed 's/.*\([(][^)]*\).*download by user\s\(\S*\).*->\s\([0-9]*\).*/\2 \1 \3/' | sed "s/['(]//g" > stats.$$.tmp
2>&1 echo Raw download stats in stats.$$.tmp

# download counts and volumes
cat stats.$$.tmp | sort | awk '{ gsub("_*[0-9]{8}[Tt][0-9]{6}.*","",$2); print $2 " " $3}'  | sort | awk 'BEGIN {count = 0; sum = 0; last=""} { if ($1 != last && last != "") { print last "," count "," sum; count = 0; sum = 0;} count+=1; sum+=$2; last=$1; } END {print last "," count "," sum;}' >  downloads-by-type.$$.csv

# Replace with human-readable text
sed -i -f consolidation.paterns.sed downloads-by-type.$$.csv

#sort and consolidate again
sort -o downloads-by-type.$$.tmp downloads-by-type.$$.csv

echo Type,count,size > downloads-by-type.$$.csv
cat downloads-by-type.$$.tmp | awk -F"," 'BEGIN {count = 0; sum = 0; last=""} { if ($1 != last && last != "") { print last "," count "," sum; count = 0; sum = 0;} count+=$2; sum+=$3; last=$1; } END {print last "," count "," sum;}' >> downloads-by-type.$$.csv

#special treatment of Manifest files
MANICOUNT=`grep manifest.safe downloads-by-type.$$.csv | awk -F"," '{print $2}'`
MANISUM=`grep manifest.safe downloads-by-type.$$.csv | awk -F"," '{print $3}'`
grep "Nodes('manifest.safe')" *.log | grep SUCCESS | egrep -o "Nodes\('S[1-9][A-D]" | egrep -o 'S[1-9]' | sort | uniq -c | awk -v count=$MANICOUNT -v sum=$MANISUM '{printf "%s (l20) manifest,%d,%0.0f\n", $2, $1, $1/count*sum}' >> downloads-by-type.$$.csv

sort -o downloads-by-type.$$.csv downloads-by-type.$$.csv

2>&1 echo Downloads by product type in downloads-by-type.$$.csv

#List of active users
echo name,category,area,location > active-users.$$.csv
cat stats.$$.tmp | awk '{print $1}' | uniq | sort | uniq >> active-users.$$.csv
>&1 echo List of users who have downloaded something is in active-users.$$.csv

rm stats.$$.tmp downloads-by-type.$$.tmp

