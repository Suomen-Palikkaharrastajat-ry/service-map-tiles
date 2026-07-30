#!/usr/bin/env bash
# Combine the per-region station files into the single dist/stations.geojson
# that scripts/style.template.json declares as the `stations` source.
#
# The regional builds run as independent CI jobs, so each writes its own
# dist/stations-<region>.geojson and this runs afterwards, once both are on
# disk. Missing inputs are tolerated: a failed regional build should degrade to
# a map without that region's stations rather than one with no station source
# at all, which would break the style outright.
set -euo pipefail

mkdir -p dist

shopt -s nullglob
INPUTS=(dist/stations-*.geojson)
shopt -u nullglob

if [ ${#INPUTS[@]} -eq 0 ]; then
  echo "ERROR: no dist/stations-*.geojson to merge." >&2
  exit 1
fi

printf '%s\n' "${INPUTS[@]}" | python3 -c "
import json, sys

features = []
for path in sys.stdin.read().split():
    with open(path) as f:
        data = json.load(f)
    n = len(data['features'])
    features.extend(data['features'])
    print(f'  {path}: {n} stations')

with open('dist/stations.geojson', 'w') as f:
    json.dump({'type': 'FeatureCollection', 'features': features}, f, ensure_ascii=False)
print(f'Merged {len(features)} stations into dist/stations.geojson')
"

# Tile them as well. As a plain GeoJSON style source the whole file is fetched
# on every map load — 2.7 MB, 375 KB gzipped, for something no layer draws
# below z9. As PMTiles the client range-requests only the tiles in view.
# Per-feature minzoom mirrors the style: mainline stations from z9, halts and
# urban transit from z11. Points overzoom, so z11 is a sufficient ceiling.
echo "Tiling stations..."
python3 -c "
import json

with open('dist/stations.geojson') as f:
    data = json.load(f)
for feat in data['features']:
    feat['tippecanoe'] = {'minzoom': 9 if feat['properties'].get('rank') == 0 else 11}
with open('dist/stations-tippecanoe.geojson', 'w') as f:
    json.dump(data, f, ensure_ascii=False)
"

tippecanoe -Z9 -z11 -o dist/stations.pmtiles --force -r1 \
  --layer=stations --no-tile-size-limit \
  dist/stations-tippecanoe.geojson
rm -f dist/stations-tippecanoe.geojson

echo "Stations tiled: dist/stations.pmtiles"
