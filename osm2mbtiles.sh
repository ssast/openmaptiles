#!/bin/bash
config=$1
source $config

if [ "$download" = true ]
then
  make download area="${area}"
fi

export area="${area}"
export DATA_DIR="${data_dir}"
export MIN_ZOOM="${min_zoom}"
export MAX_ZOOM="${max_zoom}"

if [ "$bbox" != "" ]
then
  echo "$bbox" > "${data_dir}/${area}.bbox"

  # Split bbox into coords
  IFS=',' read -r -a coords <<< "$bbox"

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
  export BBOX_FILE="/import/${area}.geojson"
  export BBOX="${bbox}"
else
  make generate-bbox-file
  export BBOX=$(<"${data_dir}/${area}.bbox")
  export BBOX_FILE=""
fi

if [ "$tiles_only" != true ]
then
  make import-osm

  make import-borders

  if [ "$bbox" != "" ]
  then
    make clip-borders
  fi

  make import-wikidata

  make import-sql
fi

# make generate-tiles

export MBTILES_FILE="${area}.mbtiles"

rm "${data_dir}/${MBTILES_FILE}"

MBTILES_LOCAL_FILE="/import/${MBTILES_FILE}"
docker-compose run --rm -u $(id -u):$(id -g) generate-vectortiles

docker-compose run --rm -u $(id -u):$(id -g) openmaptiles-tools \
      mbtiles-tools meta-generate "${MBTILES_LOCAL_FILE}" "openmaptiles.yaml" --auto-minmax --show-ranges
