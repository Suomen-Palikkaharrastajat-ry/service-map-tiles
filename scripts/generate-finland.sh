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
# Kept only so the data stays cached and re-addable: `nimisto` is not tiled.
# OpenMapTiles `place` labels from nordic-baltic.pmtiles cover Finland instead.
merge_layer "KarttanimiPiste" "$CACHE/nimisto_unsorted.geojson"

echo "Generating PMTiles with tippecanoe..."
# Find which files successfully generated (some layers might be empty or missing)
GEOJSONS=""
for f in hallinto vesi tie rautatie taajama raja; do
  if [ -f "$CACHE/${f}.geojson" ]; then
    GEOJSONS="$GEOJSONS $CACHE/${f}.geojson"
  fi
done

# MML ships every road class at full detail, but the style only draws motorway
# and primary below z9 — 86.5% of the `tie` bytes in a z7 tile were classes
# nothing rendered until z9/z10. Filter per zoom so the wire only carries what
# is drawn. KEEP IN SYNC with the tie-* layer minzooms in
# scripts/style.template.json (secondary/tertiary/ferry z9, track z10).
# shellcheck disable=SC2016 # $zoom is a tippecanoe filter variable, not a shell
# variable — it must reach tippecanoe unexpanded.
TIE_FILTER='{"tie":["any",
  ["in","Kohdeluokk",12111,12112,12121],
  ["all",[">=","$zoom",9],["in","Kohdeluokk",12122,12131,12132,12151,12152]],
  ["all",[">=","$zoom",10],["==","Kohdeluokk",12141]]]}'

# -Z6: the lowest `finland` layer minzoom in the style is 6, so z0-5 tiles were
# built (at 350-670 KB each) and never requested.
# shellcheck disable=SC2086 # word splitting of $GEOJSONS is intentional
tippecanoe -Z6 -z11 -o dist/finland.pmtiles --force -r1 \
  --drop-densest-as-needed --maximum-tile-bytes=500000 \
  -j "$TIE_FILTER" $GEOJSONS

echo "Finland basemap generated: dist/finland.pmtiles"
