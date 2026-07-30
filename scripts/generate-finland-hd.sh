#!/usr/bin/env bash
# Finland high-zoom detail: Geofabrik Finland OSM extract -> Planetiler
# (OpenMapTiles profile) -> dist/finland-hd.pmtiles (z12-13)
# Adds building footprints, detailed roads, and water/road names for Finland.
set -euo pipefail

CACHE=.cache/finland-hd
mkdir -p "$CACHE"
mkdir -p dist

PLANETILER_VERSION=0.10.2
PLANETILER_SHA256=f310bd0413e2e4512b27f4046d418664e8e1d3bf31603c2a70e23de06c167e4d

PBF="$CACHE/finland-latest.osm.pbf"
if [ ! -f "$PBF" ]; then
  echo "Downloading Finland extract..."
  # Random jitter (0-15s) to avoid hammering Geofabrik when
  # multiple CI jobs start simultaneously.
  sleep $((RANDOM % 16))
  curl -sfL --retry 5 --retry-delay 15 --retry-all-errors \
    -A "service-map-tiles (github.com/Suomen-Palikkaharrastajat-ry)" \
    -o "$PBF" "https://download.geofabrik.de/europe/finland-latest.osm.pbf"
fi

echo "Installing Planetiler ${PLANETILER_VERSION}..."
if [ ! -f "$CACHE/planetiler.jar" ] || \
   ! echo "${PLANETILER_SHA256}  $CACHE/planetiler.jar" | sha256sum -c - > /dev/null 2>&1; then
  curl -sfL -o "$CACHE/planetiler.jar" \
    "https://github.com/onthegomap/planetiler/releases/download/v${PLANETILER_VERSION}/planetiler.jar"
  echo "${PLANETILER_SHA256}  $CACHE/planetiler.jar" | sha256sum -c -
fi

echo "Creating dummy shapefile to skip unused global downloads..."
echo "id,WKT" > "$CACHE/dummy.csv"
echo "1,POLYGON EMPTY" >> "$CACHE/dummy.csv"
ogr2ogr -f "ESRI Shapefile" -a_srs EPSG:3857 "$CACHE/dummy.shp" "$CACHE/dummy.csv"
zip -j "$CACHE/dummy.zip" "$CACHE/dummy.shp" "$CACHE/dummy.shx" "$CACHE/dummy.dbf" "$CACHE/dummy.prj" 2>/dev/null || true

echo "Running Planetiler (OpenMapTiles profile, z12-13)..."
REPO_ROOT=$PWD
(
  cd "$CACHE"
  java -Xmx4g -jar planetiler.jar \
    --osm-path=finland-latest.osm.pbf \
    --download \
    --water-polygons-path=dummy.zip \
    --lake-centerlines-path=dummy.zip \
    --minzoom=12 --maxzoom=13 \
    --only-layers=building,transportation,transportation_name,water,waterway,water_name,place,landcover,landuse,boundary \
    --storage=mmap --nodemap-type=sortedtable \
    --languages=fi,sv,en \
    --fetch-wikidata=false --use-wikidata=false \
    --output="$REPO_ROOT/dist/finland-hd.pmtiles" --force
)

echo "Finland high-zoom tiles generated: dist/finland-hd.pmtiles"
