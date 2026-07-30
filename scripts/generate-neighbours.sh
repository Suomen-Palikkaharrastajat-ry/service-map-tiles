#!/usr/bin/env bash
# Physical detail for the countries that sit inside scripts/nordic-baltic.poly
# but only get labels from nordic-baltic.pmtiles: Benelux, Germany, Poland.
# Geofabrik extracts -> osmium tags-filter -> osmium merge -> Planetiler
# (OpenMapTiles profile) -> dist/neighbours.pmtiles (z0-11).
#
# Those tiles currently carry `place` labels and nothing else — measured, a z8
# tile over Berlin is 9 KB of labels against 178 KB for Stockholm — so the
# neighbours render as bare background with city names floating on it. This
# archive fills in the water and the major road network, which is most of the
# visual difference per byte. Landcover/landuse are deliberately excluded: they
# were 115 KB of that 178 KB Stockholm tile, and the Pages budget is finite.
#
# `place` stays out of here too: nordic-baltic.pmtiles already labels these
# countries, and tiling them twice would double-draw every city name.
set -euo pipefail

CACHE=.cache/neighbours
mkdir -p "$CACHE"
mkdir -p dist

PLANETILER_VERSION=0.10.2
PLANETILER_SHA256=f310bd0413e2e4512b27f4046d418664e8e1d3bf31603c2a70e23de06c167e4d

COUNTRIES="belgium netherlands luxembourg germany poland"

# Unlike the nordic-baltic merge, these extracts are filtered down before they
# are merged, so an epoch mismatch cannot produce conflicting versions of an
# overlapping object — each filtered file is disjoint from the others.
if [ ! -f "$CACHE/neighbours.osm.pbf" ]; then
  for country in $COUNTRIES; do
    pbf="$CACHE/${country}-latest.osm.pbf"
    filtered="$CACHE/${country}-detail.osm.pbf"
    if [ ! -f "$filtered" ]; then
      if [ ! -f "$pbf" ]; then
        echo "Downloading $country..."
        # Random jitter (0-15s) to avoid hammering Geofabrik when
        # multiple CI jobs start simultaneously.
        sleep $((RANDOM % 16))
        curl -sfL --retry 5 --retry-delay 15 --retry-all-errors \
          -A "service-map-tiles (github.com/Suomen-Palikkaharrastajat-ry)" \
          -o "$pbf" "https://download.geofabrik.de/europe/${country}-latest.osm.pbf"
      fi
      # No -R here: way and relation geometry needs its referenced members,
      # which is exactly what the place-only filter in generate-nordic-baltic.sh
      # does not need.
      echo "Filtering water and major roads from $country..."
      osmium tags-filter "$pbf" \
        w/natural=water r/natural=water \
        w/landuse=reservoir,basin r/landuse=reservoir,basin \
        w/waterway=river,canal,riverbank r/waterway=riverbank \
        w/highway=motorway,trunk,primary,motorway_link,trunk_link \
        -o "$filtered" --overwrite
      # Free disk immediately: the German extract alone is several GB.
      rm -f "$pbf"
    fi
  done

  echo "Merging filtered extracts with osmium..."
  PBFS=()
  for country in $COUNTRIES; do
    PBFS+=("$CACHE/${country}-detail.osm.pbf")
  done
  osmium merge "${PBFS[@]}" -o "$CACHE/neighbours.osm.pbf" --overwrite

  for country in $COUNTRIES; do
    rm -f "$CACHE/${country}-detail.osm.pbf"
  done
else
  echo "Merged extract $CACHE/neighbours.osm.pbf already exists, skipping download."
fi

echo "Installing Planetiler ${PLANETILER_VERSION}..."
if [ ! -f "$CACHE/planetiler.jar" ] || \
   ! echo "${PLANETILER_SHA256}  $CACHE/planetiler.jar" | sha256sum -c - > /dev/null 2>&1; then
  curl -sfL -o "$CACHE/planetiler.jar" \
    "https://github.com/onthegomap/planetiler/releases/download/v${PLANETILER_VERSION}/planetiler.jar"
  echo "${PLANETILER_SHA256}  $CACHE/planetiler.jar" | sha256sum -c -
fi

echo "Running Planetiler (OpenMapTiles profile, water + major roads)..."
REPO_ROOT=$PWD
# Run from inside the cache so Planetiler's default data/sources/ download
# location (water polygons, Natural Earth, lake centerlines) stays cacheable.
(
  cd "$CACHE"
  java -Xmx6g -jar planetiler.jar \
    --osm-path=neighbours.osm.pbf \
    --download \
    --minzoom=0 --maxzoom=11 \
    --polygon="$REPO_ROOT/scripts/nordic-baltic.poly" \
    --only-layers=water,waterway,transportation \
    --storage=mmap --nodemap-type=sortedtable \
    --languages=fi,sv,en,de,nl,fr,pl \
    --fetch-wikidata=false --use-wikidata=false \
    --output="$REPO_ROOT/dist/neighbours.pmtiles" --force
)

echo "Neighbour detail generated: dist/neighbours.pmtiles"
