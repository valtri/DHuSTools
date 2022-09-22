#!/bin/bash

#DEBUG=1
ID="$1"
HOST="https://dhr1.cesnet.cz/"
declare -A COLLECTION
COLLECTION["S2"]="https://resto-test.c-scale.zcu.cz/collections/S2"
COLLECTION["S1"]="https://resto-test.c-scale.zcu.cz/collections/S1"
COLLECTION["S3"]="https://resto-test.c-scale.zcu.cz/collections/S3"
COLLECTION["S5"]="https://resto-test.c-scale.zcu.cz/collections/S5"
TMP="/tmp"
SUCCPREFIX="/var/tmp/register-stac-success-"
ERRPREFIX="/var/tmp/register-stac-error-"
BASEURL="https://ip-147-251-21-170.flt.cloud.muni.cz/api/data/"

######################################
#
# Initial checks and settings
#
######################################

if [ "${ID}" == "" ]; then
	1>&2 echo $0: No ID specified
	exit 1
fi

RUNDATE=`date +%Y-%m-%d`

######################################
#
# Get metadata from DHuS Database
#
######################################

# TITLE.zip to ID
arg_title="${ID}"
BN=`echo $arg_title | sed 's/\.[^.]*$//'` # this strips extensions such as .ZIP or .SAFE

ID=$(curl -s -n --silent ${HOST}/odata/v1/Products?%24format=text/csv\&%24select=Id\&%24filter=Name%20eq%20%27$BN%27 | tail -n 1 | sed 's/\r//' )
if [ "$ID" == 'Id' -o "$ID" == "" ]; then
	>&2 echo Product with name \"$BN\" not found
exit 1
fi

XML=`curl -n -o - "${HOST}odata/v1/Products(%27${ID}%27)/Nodes"`
TITLE=`echo "${XML}" | sed "s/.*<entry>.*<link href=.Nodes('\([^']*\).*/\1/"`
PREFIX=`echo "${XML}" | sed "s/.*<entry>.*<id>\([^<]*\).*/\1/"`
PRODUCTURL=`echo "${PREFIX}" | sed 's/\\Nodes.*//'`
PLATFORM="${TITLE:0:2}"

1>&2 echo Getting metadata for $TITLE "(ID: ${ID})"
1>&2 echo Download prefix: ${PREFIX}
1>&2 echo Platform prefix: ${PLATFORM}
1>&2 echo Using colection: ${COLLECTION[${PLATFORM}]}

######################################
#
# Extract metadata files (manifests)
#
######################################

ORIGDIR=`pwd`

mkdir -p "${TMP}/register-stac.$$"

cd "${TMP}/register-stac.$$"

mkdir "${TITLE}"

# Get manifest

if [ "$PLATFORM" == "S1" -o "$PLATFORM" == "S2" ]; then
	MANIFEST="${TITLE}/manifest.safe"
	curl -n -o "${MANIFEST}" "${PREFIX}/Nodes(%27manifest.safe%27)/%24value"
elif [ "$PLATFORM" == "S3" -o "$PLATFORM" == "S3p" ]; then
	MANIFEST="${TITLE}/xfdumanifest.xml"
	curl -n -o "${MANIFEST}" "${PREFIX}/Nodes(%27xfdumanifest.xml%27)/%24value"
else
	MANIFEST="${TITLE}"
	rmdir "${TITLE}"
	curl -n -o "${MANIFEST}" "${PREFIX}/%24value"
fi

# download other metadata files line by line (Only for S1 and S2)
if [ "$PLATFORM" == "S1" -o "$PLATFORM" == "S2" ]; then
	cat "${MANIFEST}" | grep 'href=' | grep -E "/MTD_MSIL2A.xml|MTD_MSIL1C.xml|/MTD_TL.xml|annotation/s1a.*xml" | sed 's/.*href="//' | sed 's/".*//' |
	while read file; do
		1>&2 echo Downloading $file
		URL="${PREFIX}/Nodes(%27$(echo $file | sed "s|^\.*\/*||" | sed "s|\/|%27)/Nodes(%27|g")%27)/%24value"
	#	echo $URL
		mkdir -p "${TITLE}/$(dirname ${file})"
		curl -n -o "${TITLE}/${file}" "${URL}"
	done
fi

# create empty directiries stac-tools look into (only S1)
if [ "$PLATFORM" == "S1" ]; then
	mkdir -p "${TITLE}/annotation/calibration"
	mkdir -p "${TITLE}/measurement"
fi


find . 1>&2

######################################
#
# Generate JSON
#
######################################

if [ "$PLATFORM" == "S2" ]; then
	~/.local/bin/stac sentinel2 create-item "${TITLE}" ./
elif [ "$PLATFORM" == "S1" ]; then
	~/.local/bin/stac sentinel1 grd create-item "${TITLE}" ./
elif [ "$PLATFORM" == "S3" ]; then
	~/.local/bin/stac sentinel3 create-item "${TITLE}" ./
elif [ "$PLATFORM" == "S5" ]; then
	~/.local/bin/stac sentinel5p create-item "${TITLE}" ./
fi

######################################
#
# Doctor JSON
#
######################################

file=`ls *.json | head -n 1`
printf "\n" >> "$file" # Poor man's hack to make sure `read` gets all lines
"${ORIGDIR}/stac-modifier.py" -u "${BASEURL}${arg_title}" < "$file" > "new_${file}"

######################################
#
# Upload
#
######################################

curl -n -o output.json -X POST "${COLLECTION[${PLATFORM}]}/items" -H 'Content-Type: application/json' -H 'Accept: application/json' --upload-file "new_${file}"

######################################
#
# Cleanup
#
######################################


#TODO: Add reaction to {"ErrorMessage":"Not Found","ErrorCode":404}

grep '"status":"success"' output.json >/dev/null
if [ $? -eq 0 ]; then
	echo "${ID}" >> "${SUCCPREFIX}${RUNDATE}.csv"
else
	echo "${ID}" >> "${ERRPREFIX}${RUNDATE}.csv"
	DEBUG="1"
fi


cd "${ORIGDIR}"

if [ "$DEBUG" == "" ]; then
	rm -rf "${TMP}/register-stac.$$"
else
	1>&2 echo Artifacts in "${TMP}/register-stac.$$"
fi

