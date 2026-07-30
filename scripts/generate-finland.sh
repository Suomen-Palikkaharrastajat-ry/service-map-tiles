#!/usr/bin/env bash
# Finland basemap: MML Maastokartta 1:250k (kapsi.fi mirror) -> dist/finland.pmtiles
set -euo pipefail

CACHE=.cache/finland
mkdir -p "$CACHE/mml_shape_250k"
mkdir -p dist

echo "Fetching MML Maastokartta 1:250k (ETRS89) from kapsi.fi..."
GRIDS="K2 K3 K4 L2 L3 L4 L5 M3 M4 M5 N3 N4 N5 N6 P3 P4 P5 P6 Q3 Q4 Q5 R3 R4 R5 S4 S5 T4 T5 U4 U5 V3 V4 V5 W3 W4 W5 X4 X5"

for grid in $GRIDS; do
  zipnames=$(curl -s "https://kartat.kapsi.fi/files/maastokartta_250k/kaikki/etrs89/shp/${grid}/" | grep -oE '"[A-Z0-9]+\.zip"' | tr -d '"' | sort -u)
  for zipname in $zipnames; do
    zipfile="$CACHE/${zipname}"
    if [ ! -f "$zipfile" ]; then
      echo "Downloading ${zipname}..."
      curl -sL "https://kartat.kapsi.fi/files/maastokartta_250k/kaikki/etrs89/shp/${grid}/${zipname}" > "$zipfile"
    fi
    unzip -o -q "$zipfile" -d "$CACHE/mml_shape_250k"
  done
done

echo "Merging shapefiles and reprojecting EPSG:3067 to EPSG:4326 (WGS84)..."

merge_layer() {
  local layer_suffix=$1
  local output=$2
  echo "Merging $layer_suffix into $output..."
  rm -f "$output"
  # Use ogrmerge.py to combine all regional files for this layer
  ogrmerge.py -single -f GeoJSON -t_srs EPSG:4326 -o "$output" "$CACHE"/mml_shape_250k/*_"${layer_suffix}".shp || true
}

merge_layer "HallintoAlue" "$CACHE/hallinto.geojson"
merge_layer "VesiAlue" "$CACHE/vesi.geojson"
merge_layer "TieViiva" "$CACHE/tie.geojson"
merge_layer "RautatieViiva" "$CACHE/rautatie.geojson"
merge_layer "TaajamaAlue" "$CACHE/taajama.geojson"
merge_layer "HallintoalueRaja" "$CACHE/raja.geojson"
merge_layer "KarttanimiPiste" "$CACHE/nimisto_unsorted.geojson"

echo "Sorting KarttanimiPiste by scalerelev..."
if [ -f "$CACHE/nimisto_unsorted.geojson" ]; then
  rm -f "$CACHE/nimisto.geojson"
  ogr2ogr -f GeoJSON -sql "SELECT * FROM merged ORDER BY scalerelev DESC" "$CACHE/nimisto.geojson" "$CACHE/nimisto_unsorted.geojson"
fi

echo "Adding per-feature minzoom from scalerelev..."
if [ -f "$CACHE/nimisto.geojson" ]; then
  CACHE="$CACHE" python3 -c "
import json, os

cache = os.environ['CACHE']

def scalerelev_to_minzoom(sr):
    if not sr: return 11
    if sr >= 8000000: return 3
    if sr >= 4500000: return 5
    if sr >= 2000000: return 6
    if sr >= 1000000: return 7
    if sr >= 500000: return 9
    return 11

with open(f'{cache}/nimisto.geojson') as f:
    data = json.load(f)
for feat in data['features']:
    sr = feat['properties'].get('scalerelev') or 0
    feat['tippecanoe'] = {'minzoom': scalerelev_to_minzoom(sr)}
with open(f'{cache}/nimisto.geojson', 'w') as f:
    json.dump(data, f, ensure_ascii=False)
print(f'Added minzoom to {len(data[\"features\"])} features')
"
fi

echo "Generating PMTiles with tippecanoe..."
# Find which files successfully generated (some layers might be empty or missing)
GEOJSONS=""
for f in hallinto vesi tie rautatie taajama raja nimisto; do
  if [ -f "$CACHE/${f}.geojson" ]; then
    GEOJSONS="$GEOJSONS $CACHE/${f}.geojson"
  fi
done

# shellcheck disable=SC2086 # word splitting of $GEOJSONS is intentional
tippecanoe -Z0 -z11 -o dist/finland.pmtiles --force -r1 \
  --order-descending-by=scalerelev --drop-densest-as-needed \
  --maximum-tile-bytes=2000000 $GEOJSONS

echo "Finland basemap generated: dist/finland.pmtiles"
