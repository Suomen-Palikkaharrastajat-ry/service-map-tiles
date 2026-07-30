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
