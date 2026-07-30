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
  # .part then move: an interrupted transfer must not leave a truncated extract
  # that the guard above accepts on the next run.
  curl -sfL --retry 5 --retry-delay 15 --retry-all-errors \
    -A "service-map-tiles (github.com/Suomen-Palikkaharrastajat-ry)" \
    -o "$PBF.part" "https://download.geofabrik.de/europe/finland-latest.osm.pbf"
  mv "$PBF.part" "$PBF"
fi

echo "Installing Planetiler ${PLANETILER_VERSION}..."
if [ ! -f "$CACHE/planetiler.jar" ] || \
   ! echo "${PLANETILER_SHA256}  $CACHE/planetiler.jar" | sha256sum -c - > /dev/null 2>&1; then
  curl -sfL -o "$CACHE/planetiler.jar" \
    "https://github.com/onthegomap/planetiler/releases/download/v${PLANETILER_VERSION}/planetiler.jar"
  echo "${PLANETILER_SHA256}  $CACHE/planetiler.jar" | sha256sum -c -
fi

# Only the two shapefile sources can be stubbed out this way. Natural Earth is
# a sqlite db and Planetiler validates it on open ("No .sqlite file found inside
# dummy.zip"), so --natural-earth-path=dummy.zip fails fast — tested, do not
# retry. Its 415 MB download stays in .cache/finland-hd/data/sources/ even
# though a z12-13 build never uses low-zoom NE data. If the Actions cache limit
# ever becomes binding, --free-natural-earth-after-read=true trades that 415 MB
# of cache for a 415 MB re-download on every run.
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

# Planetiler derives the PMTiles header center zoom from the tileset bounds and
# ignores --minzoom/--maxzoom, so this z12-13 archive comes out with
# CenterZoom=4 and `pmtiles verify` rejects the header as invalid. MapLibre
# ignores the field (the style drives zoom), but keep the archive spec-valid.
# `pmtiles edit` rewrites only the header, not the tile data.
echo "Correcting PMTiles header center zoom..."
pmtiles show --header-json dist/finland-hd.pmtiles > "$CACHE/header.json"
HEADER="$CACHE/header.json" python3 -c "
import json, os

path = os.environ['HEADER']
with open(path) as f:
    header = json.load(f)
header['center'][2] = header['minzoom']
with open(path, 'w') as f:
    json.dump(header, f)
print(f\"center zoom set to {header['minzoom']}\")
"
pmtiles edit --header-json="$CACHE/header.json" dist/finland-hd.pmtiles

echo "Finland high-zoom tiles generated: dist/finland-hd.pmtiles"
