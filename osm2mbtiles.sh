#!/bin/bash
area=$1
bbox=$2
data_dir=$3
download=$4
min_zoom=$5
max_zoom=$6

if [ "$download" = true ]
then
  make download area="${area}"
fi

export area="${area}"
export BBOX="${bbox}"
export BBOX_FILE="/import/${area}.geojson"
export DATA_DIR="${data_dir}"
export MIN_ZOOM="${min_zoom}"
export MAX_ZOOM="${max_zoom}"

echo "$BBOX" > "${data_dir}/${area}.bbox"

# Split bbox into coords
IFS=',' read -r -a coords <<< "$BBOX"

echo '
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            ['${coords[0]}', '${coords[1]}'],
            ['${coords[2]}', '${coords[1]}'],
            ['${coords[2]}', '${coords[3]}'],
            ['${coords[0]}', '${coords[3]}'],
            ['${coords[0]}', '${coords[1]}']
          ]
        ]
      },
      "properties": {
      }
    }
  ]
}' > "${data_dir}/${area}.geojson"

make import-osm

make import-borders

make clip-borders

make import-wikidata

make import-sql

# make generate-tiles

export MBTILES_FILE="${area}.mbtiles"
MBTILES_LOCAL_FILE="/import/${MBTILES_FILE}"
docker-compose run --rm -u 1000:1000 generate-vectortiles

docker-compose run --rm -u 1000:1000 openmaptiles-tools \
      mbtiles-tools meta-generate "${MBTILES_LOCAL_FILE}" "openmaptiles.yaml" --auto-minmax --show-ranges
