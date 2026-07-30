#!/usr/bin/env bash
# Regional basemap: Geofabrik OSM extracts -> osmium merge -> Planetiler
# (OpenMapTiles profile, styled layers only) -> dist/nordic-baltic.pmtiles
# (z0-11). Covers Nordic + Baltic + Germany, Benelux and Poland.
set -euo pipefail

CACHE=.cache/nordic-baltic
mkdir -p "$CACHE"
mkdir -p dist

PLANETILER_VERSION=0.10.2
PLANETILER_SHA256=f310bd0413e2e4512b27f4046d418664e8e1d3bf31603c2a70e23de06c167e4d

COUNTRIES="norway sweden denmark finland estonia latvia lithuania"

# osmium merge requires overlapping objects to have identical versions, so all
# extracts must come from the same Geofabrik epoch. The CI cache keeps them
# together; locally run `make clean-cache` (or remove *.osm.pbf) to refresh all
# of them at once — never refresh just one.
if [ ! -f "$CACHE/nordic-baltic.osm.pbf" ]; then
  echo "Fetching Geofabrik extracts..."
  for country in $COUNTRIES; do
    pbf="$CACHE/${country}-latest.osm.pbf"
    if [ ! -f "$pbf" ]; then
      echo "Downloading $country..."
      curl -sfL --retry 5 --retry-delay 10 -A "service-map-tiles (github.com/Suomen-Palikkaharrastajat-ry)" -o "$pbf" "https://download.geofabrik.de/europe/${country}-latest.osm.pbf"
    fi
  done

  echo "Merging extracts with osmium..."
  PBFS=()
  for country in $COUNTRIES; do
    PBFS+=("$CACHE/${country}-latest.osm.pbf")
  done
  osmium merge "${PBFS[@]}" -o "$CACHE/nordic-baltic.osm.pbf" --overwrite

  # Free disk: individual extracts are no longer needed after the merge.
  # The merged file is kept and cached for subsequent runs.
  for country in $COUNTRIES; do
    rm -f "$CACHE/${country}-latest.osm.pbf"
  done
else
  echo "Merged extract $CACHE/nordic-baltic.osm.pbf already exists, skipping download."
fi

echo "Installing Planetiler ${PLANETILER_VERSION}..."
if [ ! -f "$CACHE/planetiler.jar" ] || \
   ! echo "${PLANETILER_SHA256}  $CACHE/planetiler.jar" | sha256sum -c - > /dev/null 2>&1; then
  curl -sfL -o "$CACHE/planetiler.jar" \
    "https://github.com/onthegomap/planetiler/releases/download/v${PLANETILER_VERSION}/planetiler.jar"
  echo "${PLANETILER_SHA256}  $CACHE/planetiler.jar" | sha256sum -c -
fi

echo "Running Planetiler (OpenMapTiles profile)..."
REPO_ROOT=$PWD
# Run from inside the cache so Planetiler's default data/sources/ download
# location (water polygons, Natural Earth, lake centerlines) stays cacheable.
(
  cd "$CACHE"
  java -Xmx6g -jar planetiler.jar \
    --osm-path=nordic-baltic.osm.pbf \
    --download \
    --minzoom=0 --maxzoom=11 \
    --polygon="$REPO_ROOT/scripts/nordic-baltic.poly" \
    --only-layers=landcover,landuse,water,waterway,boundary,transportation,place \
    --storage=mmap --nodemap-type=sortedtable \
    --languages=fi,sv,en,no,da,et,lv,lt,de,nl,fr,pl \
    --fetch-wikidata=false --use-wikidata=false \
    --output="$REPO_ROOT/dist/nordic-baltic.pmtiles" --force
)

echo "Regional tiles generated: dist/nordic-baltic.pmtiles"
