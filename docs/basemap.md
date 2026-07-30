# Basemap Generation (PMTiles)

This repository generates a self-hosted vector basemap as three regional
PMTiles archives plus a MapLibre style, served from GitHub Pages. Splitting
by region keeps mobile data usage low: PMTiles archives are fetched with
HTTP range requests, so clients only download the tiles they actually view,
and the small world archive is all that is needed at low zooms.

## The archives

### `world.pmtiles` — world country borders and labels (z0–6)

Built by `scripts/generate-world.sh` from Natural Earth 50m data
(`ne_50m_admin_0_countries`, `ne_50m_admin_0_boundary_lines_land`).
Layers: `countries` (polygons), `boundaries` (lines), `country_labels`
(label points placed at NE's `LABEL_X`/`LABEL_Y`, with a per-feature
tippecanoe minzoom derived from NE's `MIN_LABEL` recommendation, so more
important countries label earlier). Replaces the old
`world_countries.geojson`, which had to be downloaded in full before
anything rendered. A few MB total; its z6 tiles also overzoom as the
land-fill fallback outside the Nordic region at higher zooms.

### `nordic-baltic.pmtiles` — OSM detail for the region (z0–11)

Built by `scripts/generate-nordic-baltic.sh`: Geofabrik extracts for
Norway, Sweden, Denmark, Finland, Estonia, Latvia and Lithuania are merged with
`osmium merge` and rendered by [Planetiler](https://github.com/onthegomap/planetiler)
(pinned jar, checksum-verified) using the **OpenMapTiles** profile with
`--only-layers=landcover,landuse,water,waterway,boundary,transportation,place`
(only the layers the style references — building, housenumber, poi and
other unstyled layers are excluded to save space). That schema's `place`
layer (class `city`/`town`/`village` plus a
per-feature `rank`) provides OSM-standard label prioritization per zoom
level, including `name:fi` translations — this is what drives which labels
appear at which zoom across the whole region, Finland included.

Finland is part of this build on purpose: it gives seamless coastlines,
borders and label ranking across the region.

### `finland.pmtiles` — MML detail for Finland (z0–11)

Built by `scripts/generate-finland.sh` from MML Maastokartta 1:250k
shapefiles (kapsi.fi mirror), merged and reprojected EPSG:3067 → EPSG:4326
with GDAL. Source layers: `hallinto`, `vesi`, `tie`, `taajama`, `raja`,
`nimisto`. The `nimisto` place names (with `scalerelev`-derived minzooms)
are still in the archive for data consumers, but the shipped style labels
Finland from the OpenMapTiles `place` layer instead.

### `finland-hd.pmtiles` — Finland OSM high-zoom detail (z12–13)

Built by `scripts/generate-finland-hd.sh` from the Finland Geofabrik
extract, rendered by Planetiler (same pinned jar) at z12–13 only. This
archive includes building footprints, detailed road/water networks, and
`transportation_name` / `water_name` label layers — the detail that makes
close zoom useful. The style adds layers referencing this source at z12+
(buildings from z13, road/water names from z12–13). Outside Finland these
zoom levels overzoom the regional archive's z11 tiles transparently.

## Style and fonts

`scripts/generate-style.sh` renders `scripts/style.template.json` into
`dist/style.json`, substituting `__BASE_URL__` (default
`https://tiles.palikkaharrastajat.fi`; set
`BASE_URL=http://localhost:8080` for local testing). Layer plan,
bottom-to-top: world fill/borders (all zooms) → OpenMapTiles landcover,
landuse, water, waterways, country boundaries, roads (z5+) → MML Finland
layers (z7+) → labels (world country labels to z6, then OpenMapTiles
`place` classes: country z6, city z5, town z8, village z10).

`scripts/fetch-fonts.sh` downloads prebuilt glyph PBFs
([openmaptiles/fonts](https://github.com/openmaptiles/fonts) v2.0) for the
two stacks the style uses: `Open Sans Regular` and `Open Sans Semibold`.

`dist/index.html` is a minimal MapLibre viewer for eyeballing the deployed
site.

## Caching

Each script caches downloads and intermediates under its own directory
(`.cache/world`, `.cache/finland`, `.cache/nordic-baltic`, `.cache/fonts`)
so re-runs are incremental, and CI caches each independently (keyed by the
hash of the corresponding script). Note: the Geofabrik extracts must all
come from the same date for `osmium merge` to work — refresh them all
together (`make clean-cache`), never one at a time.

## Consuming the output

Everything is served from GitHub Pages with
`access-control-allow-origin: *` and range-request support:

```
https://tiles.palikkaharrastajat.fi/style.json
https://tiles.palikkaharrastajat.fi/{world,nordic-baltic,finland}.pmtiles
https://tiles.palikkaharrastajat.fi/fonts/{fontstack}/{range}.pbf
```

A MapLibre app only needs to register the pmtiles protocol and point at the
hosted `style.json` — no files need copying:

```js
import maplibregl from 'maplibre-gl';
import { Protocol } from 'pmtiles';
maplibregl.addProtocol('pmtiles', new Protocol().tile);
new maplibregl.Map({
  container: 'map',
  style: 'https://tiles.palikkaharrastajat.fi/style.json',
  maxZoom: 13,
});
```

### Breaking changes vs. the old single-archive output

- `basemap.pmtiles` is replaced by three archives; style source names are
  now `world`, `nordic`, and `finland` (was `basemap` + the
  `world_countries` GeoJSON source).
- `world_countries.geojson` no longer exists.
- The style's URLs are absolute (Pages URL) instead of same-origin
  relative paths, and glyphs use single font stacks (`Open Sans Regular`,
  `Open Sans Semibold`) — the combined
  `Open Sans Regular,Arial Unicode MS Regular` stack is gone.
- MML `nimisto` labels are no longer styled (OpenMapTiles `place` labels
  cover the whole region); the layer data remains in `finland.pmtiles`.
- Output is published via GitHub Pages only; the rolling `latest` GitHub
  release is discontinued.
- Client `maxZoom` should be 13 to see Finland high-zoom detail.
  Outside Finland, z12–13 overzooms the regional archive's z11 tiles.

## Licenses and attribution

| Data | License | Required attribution |
|---|---|---|
| MML Maastokartta | CC BY 4.0 | `© Maanmittauslaitos` |
| OpenStreetMap | ODbL | `© OpenStreetMap contributors` |
| Natural Earth | Public domain | courtesy `Natural Earth` |
| OpenMapTiles schema | CC BY 4.0 (design) / BSD (code) | `© OpenMapTiles` |
| Open Sans glyphs | SIL OFL 1.1 | reserved font name "Open Sans" |

The attribution strings are baked into the style's `sources` and must not
be removed by consumers — maplibre-gl surfaces them automatically.

Full license texts are vendored in [`licenses/`](../licenses/) and summarized in
the root [`NOTICE.md`](../NOTICE.md), which the build also copies to
`dist/NOTICE.md`. Because the upstream font release ships no license text,
`scripts/fetch-fonts.sh` serves the Open Sans OFL at `dist/fonts/OFL.txt`
alongside the glyphs (required by the SIL OFL).
