# Attribution & Licenses

This project builds and serves a map basemap derived from several open-data
sources. Each carries an attribution and/or license obligation that must be
preserved by anyone who serves or embeds these tiles.

The required attribution strings are **baked into the generated
`dist/style.json`** (each source's `attribution` field) and are surfaced
automatically by maplibre-gl's attribution control in consuming apps — they must
not be removed. Full license texts are vendored under [`licenses/`](licenses/),
and the Open Sans font license is also **served** next to the glyphs at
`fonts/OFL.txt`.

| Source | Used for | License | Required attribution | License file |
|---|---|---|---|---|
| MML Maastokartta 1:250k (Maanmittauslaitos) | `finland.pmtiles` | CC BY 4.0 | `© Maanmittauslaitos` | [CC-BY-4.0.txt](licenses/CC-BY-4.0.txt) |
| OpenStreetMap (via Geofabrik) | `nordic-baltic.pmtiles` | ODbL 1.0 | `© OpenStreetMap contributors` | [ODbL-1.0.txt](licenses/ODbL-1.0.txt) |
| OpenMapTiles schema / profile | `nordic-baltic.pmtiles` | CC BY 4.0 (design) · BSD-3 (code) | `© OpenMapTiles` | [OpenMapTiles.md](licenses/OpenMapTiles.md) |
| OpenStreetMap (via Geofabrik) | `stations.geojson` | ODbL 1.0 | `© OpenStreetMap contributors` | [ODbL-1.0.txt](licenses/ODbL-1.0.txt) |
| OpenStreetMap (via Geofabrik) | `finland-hd.pmtiles` | ODbL 1.0 | `© OpenStreetMap contributors` | [ODbL-1.0.txt](licenses/ODbL-1.0.txt) |
| OpenStreetMap (via Geofabrik) | `neighbours.pmtiles` | ODbL 1.0 | `© OpenStreetMap contributors` | [ODbL-1.0.txt](licenses/ODbL-1.0.txt) |
| OpenMapTiles schema / profile | `neighbours.pmtiles` | CC BY 4.0 (design) · BSD-3 (code) | `© OpenMapTiles` | [OpenMapTiles.md](licenses/OpenMapTiles.md) |
| OpenMapTiles schema / profile | `finland-hd.pmtiles` | CC BY 4.0 (design) · BSD-3 (code) | `© OpenMapTiles` | [OpenMapTiles.md](licenses/OpenMapTiles.md) |
| Natural Earth 50m | `world.pmtiles` | Public domain | courtesy `Natural Earth` (no obligation) | — |
| Open Sans (openmaptiles/fonts glyphs) | `fonts/` glyph PBFs | SIL OFL 1.1 | Reserved Font Name "Open Sans" | [SIL-OFL-1.1.txt](licenses/SIL-OFL-1.1.txt) |

Notes:

- **Natural Earth** is in the public domain; the credit is a courtesy, not a
  requirement, but is included in the `world` source's attribution.
- The **SIL OFL 1.1** requires the license to travel with the font. Because the
  upstream `openmaptiles/fonts` release ships no license text, `fetch-fonts.sh`
  copies [`licenses/SIL-OFL-1.1.txt`](licenses/SIL-OFL-1.1.txt) to
  `dist/fonts/OFL.txt` so it is distributed with the served glyphs.
- The generation scripts in [`scripts/`](scripts/) and CI configuration are the
  original work of this repository; no separate project license is asserted
  here for that code.
