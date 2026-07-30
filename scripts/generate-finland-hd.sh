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
  curl -sL -o "$PBF" "https://download.geofabrik.de/europe/finland-latest.osm.pbf"
fi

echo "Installing Planetiler ${PLANETILER_VERSION}..."
if [ ! -f "$CACHE/planetiler.jar" ] || \
   ! echo "${PLANETILER_SHA256}  $CACHE/planetiler.jar" | sha256sum -c - > /dev/null 2>&1; then
  curl -sL -o "$CACHE/planetiler.jar" \
    "https://github.com/onthegomap/planetiler/releases/download/v${PLANETILER_VERSION}/planetiler.jar"
  echo "${PLANETILER_SHA256}  $CACHE/planetiler.jar" | sha256sum -c -
fi

echo "Creating dummy shapefile to skip unused global downloads..."
python3 -c "
import zipfile
with zipfile.ZipFile('$CACHE/dummy.zip', 'w') as zf:
    header = bytearray(100)
    header[0:4] = (9994).to_bytes(4, 'big')
    header[24:28] = (50).to_bytes(4, 'big')
    header[28:32] = (1000).to_bytes(4, 'little')
    header[32:36] = (5).to_bytes(4, 'little')
    zf.writestr('dummy.shp', header)
    zf.writestr('dummy.shx', header)
    dbf = bytearray(32)
    dbf[0] = 0x03
    dbf[8:10] = (32).to_bytes(2, 'little')
    dbf[10:12] = (1).to_bytes(2, 'little')
    zf.writestr('dummy.dbf', dbf)
"

echo "Running Planetiler (OpenMapTiles profile, z12-13)..."
REPO_ROOT=$PWD
(
  cd "$CACHE"
  java -Xmx4g -jar planetiler.jar \
    --osm-path=finland-latest.osm.pbf \
    --water-polygons-path=dummy.zip \
    --natural-earth-path=dummy.zip \
    --lake-centerlines-path=dummy.zip \
    --minzoom=12 --maxzoom=13 \
    --only-layers=building,transportation,transportation_name,water,waterway,water_name,place,landcover,landuse,boundary \
    --storage=mmap --nodemap-type=sortedtable \
    --languages=fi,sv,en \
    --fetch-wikidata=false --use-wikidata=false \
    --output="$REPO_ROOT/dist/finland-hd.pmtiles" --force
)

echo "Finland high-zoom tiles generated: dist/finland-hd.pmtiles"
