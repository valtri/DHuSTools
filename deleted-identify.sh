#!/bin/bash
# Finds products that have been deleted from upstream but are still available from downstream

	VARTMP="/var/tmp/deleted-identify"
	WRKDIR="/tmp"

	UPSTREAM_URL="https://colhub.copernicus.eu/dhus"
	DOWNSTREAM_URL="https://dhr1.cesnet.cz"


	UPWD="-n"
	NOW=`date "+%s"`
	if [ "$START" == "" ]; then
		if [ -f "$VARTMP/lastcheck" ]; then
			START=`cat "$VARTMP/lastcheck"`
		else
			START=0 # Start from the beginning of the world (i.e., Jan 1970)
		fi
	fi

	SSTRING=`date -d @$START "+%Y-%m-%dT%H:%M:%S.000"`
	ESTRING=`date -d @$NOW "+%Y-%m-%dT%H:%M:%S.000"`
	PAGESIZE=100
	SKIP=0

	>&2 printf "Checking between\t$SSTRING\n\t\t and \t$ESTRING\n"

	let COUNT=$PAGESIZE+1
	while [ $COUNT -gt $PAGESIZE ]; do
		COUNT=0
		SEG=`curl -sS $UPWD ${UPSTREAM_URL}/odata/v1/DeletedProducts?%24format=text/csv\&%24select=Id,Name,CreationDate,DeletionDate,DeletionCause\&%24skip=$SKIP\&%24top=$PAGESIZE\&%24filter=CreationDate%20gt%20datetime%27${SSTRING}%27%20and%20CreationDate%20lt%20datetime%27${ESTRING}%27%20and%20startswith%28DeletionCause,%27Invalid%27%29`
		touch ${WRKDIR}/deleted.$$.csv
		while read -r line; do
			if [ $COUNT -ne 0 ]; then
				echo "$line" >> ${WRKDIR}/deleted.$$.csv
			fi
			let COUNT=$COUNT+1
		done <<< $SEG
		let SKIP=$SKIP+$PAGESIZE
	done

	>&2 echo "No. of deleted products found: `cat ${WRKDIR}/deleted.$$.csv | wc -l`"

	touch ${WRKDIR}/downstream.$$.csv 

	cat ${WRKDIR}/deleted.$$.csv | while read line; do
		ID=`echo $line | grep -Eo '^[^,]*'`
		curl -sS $UPWD "${DOWNSTREAM_URL}/odata/v1/Products('$ID')" | grep 'Invalid key' 2>&1 > /dev/null

		if [ $? -ne 0 ]; then # Product found downstream
			echo $line >> ${WRKDIR}/downstream.$$.csv 
		fi
	done

	cat ${WRKDIR}/downstream.$$.csv

	>&2 echo "Subset found downstream: `cat ${WRKDIR}/downstream.$$.csv | wc -l`"

	mail -A ${WRKDIR}/downstream.$$.csv -s "Sentinel products invalidated at source" sustr4@cesnet.cz <<< "Deleted products"

	mkdir -p "$VARTMP"
	echo $NOW > "$VARTMP/lastcheck"

	rm ${WRKDIR}/deleted.$$.csv
	mv ${WRKDIR}/downstream.$$.csv "$VARTMP/lastfind"

