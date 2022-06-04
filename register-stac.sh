#!/bin/bash

ID="$1"
HOST="https://dhr1.cesnet.cz/"
TMP="/tmp"
DEBUG="1"

######################################
#
# Initial checks and settings
#
######################################

if [ "${ID}" == "" ]; then
	1>&2 echo $0: No ID specified
fi

######################################
#
# Get metadata from DHuS Database
#
######################################

XML=`curl -n -o - "${HOST}odata/v1/Products(%27${ID}%27)/Nodes"`
TITLE=`echo "${XML}" | sed "s/.*<entry>.*<link href=.Nodes('\([^']*\).*/\1/"`
PREFIX=`echo "${XML}" | sed "s/.*<entry>.*<id>\([^<]*\).*/\1/"`


1>&2 echo Getting metadata for $TITLE "(ID: ${ID})"
1>&2 echo Download prefix: ${PREFIX}


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

curl -n -o "${TITLE}/manifest.safe" "${PREFIX}/Nodes(%27manifest.safe%27)/%24value"

# download other metadata files line by line
cat "${TITLE}/manifest.safe" | grep 'href=' | grep -E "/MTD_MSIL2A.xml|MTD_MSIL1C.xml|/MTD_TL.xml" | sed 's/.*href="//' | sed 's/".*//' |
while read file; do
	1>&2 echo Downloading $file
	URL="${PREFIX}/Nodes(%27$(echo $file | sed "s|^\.*\/*||" | sed "s|\/|%27)/Nodes(%27|g")%27)/%24value"
#	echo $URL
	mkdir -p "${TITLE}/$(dirname ${file})"
	curl -n -o "${TITLE}/${file}" "${URL}"
done

find . -type f 1>&2

######################################
#
# Generate JSON
#
######################################

~/.local/bin/stac sentinel2 create-item "${TITLE}" ./

######################################
#
# Doctor JSON
#
######################################

######################################
#
# Upload
#
######################################

######################################
#
# Cleanup
#
######################################

cd "${ORIGDIR}"

if [ "$DEBUG" == "" ]; then
	rm -rf "${TMP}/register-stac.$$"
else
	1>&2 echo Artifacts in "${TMP}/register-stac.$$"
fi
