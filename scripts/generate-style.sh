#!/usr/bin/env bash
# Render scripts/style.template.json into dist/style.json with the deployment
# base URL, and copy the QA viewer page.
set -euo pipefail

BASE_URL="${BASE_URL:-https://tiles.palikkaharrastajat.fi}"

mkdir -p dist

echo "Fetching QA viewer dependencies..."
mkdir -p .cache/vendor dist/vendor

# Download maplibre-gl and pmtiles if not cached
if [ ! -f .cache/vendor/maplibre-gl.js ]; then
  curl -sL "https://unpkg.com/maplibre-gl@5.6.0/dist/maplibre-gl.js" -o .cache/vendor/maplibre-gl.js
  curl -sL "https://unpkg.com/maplibre-gl@5.6.0/dist/maplibre-gl.css" -o .cache/vendor/maplibre-gl.css
  curl -sL "https://unpkg.com/pmtiles@4.3.0/dist/pmtiles.js" -o .cache/vendor/pmtiles.js
fi

cp .cache/vendor/* dist/vendor/

echo "Generating dist/style.json with BASE_URL=${BASE_URL}..."
sed "s|__BASE_URL__|${BASE_URL}|g" scripts/style.template.json > dist/style.json
python3 -m json.tool dist/style.json > /dev/null

echo "Copying QA viewer to dist/index.html..."
cp scripts/index.template.html dist/index.html

echo "Copying attribution notice to dist/NOTICE.md..."
cp NOTICE.md dist/NOTICE.md

echo "Style generated."
