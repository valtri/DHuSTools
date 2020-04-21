#$/bin/bash

while read line; do
	curl -ns https://colhub.copernicus.eu/dhus/odata/v1/DeletedProducts?%24format=text/csv\&%24select=Id,Name,DeletionCause\&%24filter=Name%20eq%20%27${line}%27 | tail -n +2
done
