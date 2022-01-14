#!/bin/bash

NUM=14
LAST=1
ATTRIBUTE="CreationDate"
SELATTR="ContentDate,IngestionDate,CreationDate"
LIST=1
PREFIX=""
MATCH=""
UPWD="-n"

while getopts "hn:u:p:m:" opt; do
  case $opt in
	h)
		printf "List sensing, ingestion and ceration dates for products\n\nUsage:\n
\t-h      \tDisplay this help\n \
\t-n <num>\tNumber of days to count back (default 14)\n \
\t-p <str>\tName prefix (Platform: S1, S2, or S3)\n \
\t-m <str>\tName contents match (e.g.: _SLC_)\n \
\t-u <str>\tuser:password to use accessing the remote site.\n \
\t\t\tThis is passed directly to curl.\n\n"
		exit 0
		;;
	u)
		UPWD="-u \"$OPTARG\""
		;;
	n)
		NUM=$OPTARG
		;;
	p)
		PREFIX="%20and%20startswith(Name,%27${OPTARG}%27)"
		;;
	m)
		MATCH="%20and%20substringof(%27${OPTARG}%27,Name)"
		;;
  esac
done

shift $(($OPTIND - 1))
URL=$1


NOW=`date -d 'yesterday 00:00:00' "+%s"`
let START=$NOW-$NUM*86400+86400

let NUM=$NUM+$LAST

get_list() {
	SSTRING=`date -d @$START "+%Y-%m-%dT%H:%M:%S.000"`
	let ETIME=$START+86400
	ESTRING=`date -d @$NOW "+%Y-%m-%dT%H:%M:%S.000"`
	PAGESIZE=100
	SKIP=0

	

	let COUNT=$PAGESIZE+1
	while [ $COUNT -gt $PAGESIZE ]; do
		COUNT=0
		SEG=`curl -sS $UPWD ${URL}/odata/v1/Products?%24format=text/csv\&%24select=Name,${SELATTR}\&%24skip=$SKIP\&%24top=$PAGESIZE\&%24filter=${ATTRIBUTE}%20gt%20datetime%27${SSTRING}%27%20and%20${ATTRIBUTE}%20lt%20datetime%27${ESTRING}%27${PREFIX}${MATCH}`
		while read -r line; do
			if [ $COUNT -ne 0 ]; then
				echo $line;
			fi
			let COUNT=$COUNT+1
		done <<< $SEG
		let SKIP=$SKIP+$PAGESIZE
	done
}



get_list


exit 0
