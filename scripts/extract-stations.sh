#!/usr/bin/env bash
# Railway stations from an OSM extract -> trimmed GeoJSON.
#
#   extract-stations.sh <input.osm.pbf> <work-dir> <output.geojson>
#
# OpenMapTiles keeps stations in its `poi` layer, which Planetiler hard-codes to
# minzoom 14 — above the z11/z13 this project builds — so they cannot come from
# the tiles and are published as a small GeoJSON style source instead.
# `railway=station` also covers metro (station=subway); trams
# (railway=tram_stop) are deliberately left out.
#
# Shared by generate-nordic-baltic.sh and generate-neighbours.sh so the two
# regions cannot end up with differently-shaped station properties — the style
# reads the same `rank`/`railway`/`name*` fields from both.
set -euo pipefail

PBF=$1
WORK=$2
OUT=$3

mkdir -p "$WORK" "$(dirname "$OUT")"

osmium tags-filter -R "$PBF" n/railway=station,halt \
  -o "$WORK/stations.osm.pbf" --overwrite
osmium export "$WORK/stations.osm.pbf" -f geojson \
  -o "$WORK/stations-raw.geojson" --overwrite

# Raw station nodes carry 15-20 tags each; keep only what the style renders.
RAW="$WORK/stations-raw.geojson" OUT="$OUT" python3 -c "
import json, os

names = ('name', 'name:fi', 'name:sv', 'name:en')
# A handful of nodes tag tram/monorail/funicular/model-railway stops as
# railway=station; those are not part of the network this map shows.
skip = {'tram', 'monorail', 'funicular', 'miniature'}
urban = {'subway', 'light_rail'}

with open(os.environ['RAW']) as f:
    data = json.load(f)

features = []
for feat in data['features']:
    tags = feat['properties']
    station = tags.get('station')
    if station in skip:
        continue
    if not any(tags.get(n) for n in names):
        continue
    props = {n: tags[n] for n in names if tags.get(n)}
    props['railway'] = tags.get('railway')
    if station:
        props['station'] = station
    # Drives both the per-zoom style layers and label collision priority:
    # 0 mainline station, 1 mainline halt, 2 metro / light rail.
    if station in urban:
        props['rank'] = 2
    else:
        props['rank'] = 0 if tags.get('railway') == 'station' else 1
    features.append({'type': 'Feature', 'geometry': feat['geometry'], 'properties': props})

out = os.environ['OUT']
with open(out, 'w') as f:
    json.dump({'type': 'FeatureCollection', 'features': features}, f, ensure_ascii=False)
print(f'Wrote {len(features)} stations to {out}')
"
