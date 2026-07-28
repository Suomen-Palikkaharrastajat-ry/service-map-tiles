#!/usr/bin/env bash
# World country borders + labels: Natural Earth 50m -> dist/world.pmtiles (z0-6)
set -euo pipefail

CACHE=.cache/world
mkdir -p "$CACHE/ne"
mkdir -p dist

NE_BASE="https://naciscdn.org/naturalearth/50m/cultural"

for dataset in ne_50m_admin_0_countries ne_50m_admin_0_boundary_lines_land; do
  if [ ! -f "$CACHE/ne/${dataset}.shp" ]; then
    echo "Downloading ${dataset}..."
    curl -sL "${NE_BASE}/${dataset}.zip" > "$CACHE/ne/${dataset}.zip"
    unzip -o -q "$CACHE/ne/${dataset}.zip" -d "$CACHE/ne/"
  fi
done

echo "Converting country polygons..."
rm -f "$CACHE/countries.geojson"
ogr2ogr -f GeoJSON "$CACHE/countries.geojson" "$CACHE/ne/ne_50m_admin_0_countries.shp" \
  -select NAME,ISO_A2_EH,ADM0_A3

echo "Converting boundary lines..."
rm -f "$CACHE/boundaries.geojson"
ogr2ogr -f GeoJSON "$CACHE/boundaries.geojson" "$CACHE/ne/ne_50m_admin_0_boundary_lines_land.shp" \
  -select FEATURECLA

echo "Building country label points from LABEL_X/LABEL_Y..."
rm -f "$CACHE/country_labels_attrs.geojson" "$CACHE/country_labels.geojson"
ogr2ogr -f GeoJSON "$CACHE/country_labels_attrs.geojson" "$CACHE/ne/ne_50m_admin_0_countries.shp" \
  -select NAME,NAME_EN,LABELRANK,MIN_LABEL,LABEL_X,LABEL_Y

# Replace each country polygon with its Natural Earth label point and derive a
# per-feature tippecanoe minzoom from NE's own MIN_LABEL zoom recommendation.
CACHE="$CACHE" python3 -c "
import json, os

cache = os.environ['CACHE']
with open(f'{cache}/country_labels_attrs.geojson') as f:
    data = json.load(f)

labels = []
for feat in data['features']:
    props = feat['properties']
    x, y = props.get('LABEL_X'), props.get('LABEL_Y')
    if x is None or y is None:
        continue
    min_label = props.get('MIN_LABEL') or 6
    labels.append({
        'type': 'Feature',
        'geometry': {'type': 'Point', 'coordinates': [x, y]},
        'properties': {
            'NAME': props.get('NAME'),
            'NAME_EN': props.get('NAME_EN'),
            'LABELRANK': props.get('LABELRANK'),
        },
        'tippecanoe': {'minzoom': max(0, min(6, int(min_label)))},
    })

with open(f'{cache}/country_labels.geojson', 'w') as f:
    json.dump({'type': 'FeatureCollection', 'features': labels}, f, ensure_ascii=False)
print(f'Wrote {len(labels)} country label points')
"

echo "Generating PMTiles with tippecanoe..."
tippecanoe -Z0 -z6 -o dist/world.pmtiles --force \
  --detect-shared-borders --coalesce-densest-as-needed \
  --maximum-tile-bytes=500000 \
  -L countries:"$CACHE/countries.geojson" \
  -L boundaries:"$CACHE/boundaries.geojson" \
  -L country_labels:"$CACHE/country_labels.geojson"

echo "World tiles generated: dist/world.pmtiles"
