# Basemap Generation (PMTiles)

This repository generates a self-hosted vector basemap as five regional
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
`--only-layers=landcover,landuse,water,waterway,boundary,transportation,transportation_name,place`
(only the layers the style references — building, housenumber, poi and
other unstyled layers are excluded to save space). That schema's `place`
layer (class `city`/`town`/`village` plus a
per-feature `rank`) provides OSM-standard label prioritization per zoom
level, including `name:fi` translations — this is what drives which labels
appear at which zoom across the whole region, Finland included.

Finland is part of this build on purpose: it gives seamless coastlines,
borders and label ranking across the region.

This script also writes **`dist/stations-nordic-baltic.geojson`** via the
shared `scripts/extract-stations.sh`: railway station points (`railway=station`
and `railway=halt`, which includes metro via `station=subway`; trams are
excluded) pulled from the merged extract with `osmium tags-filter`. They cannot
come from the tiles: the OpenMapTiles `poi` layer that holds stations is fixed
at minzoom 14, above the z13 this project builds. Only `name*`, `railway`,
`station` and a computed `rank` are kept.

### `neighbours.pmtiles` — water, roads and rail for the neighbours (z0–11)

`scripts/nordic-baltic.poly` reaches well beyond the seven countries above:
Benelux, most of Germany and Poland fall inside the clip polygon. Those areas
used to get only `place=city,town` labels from the nordic-baltic merge, so they
rendered as bare background with city names floating on it — measured, a z8 tile
over Berlin was 9 KB of labels where the equivalent Stockholm tile was 178 KB.

`scripts/generate-neighbours.sh` fills that in. Geofabrik extracts for Belgium,
the Netherlands, Luxembourg, Germany and Poland are reduced with
`osmium tags-filter` to water bodies, rivers/canals, the road network down to
`secondary` and the railways, merged, and rendered by Planetiler with
`--only-layers=water,waterway,transportation,transportation_name`. Station nodes
ride along in the same filter, so the lines get the markers the Nordic ones
have, and `transportation_name` carries the `ref` that the
`neighbours-road-number` style layer renders as route shields — the same
treatment Finland gets from MML `Tienumero`.

Everything here was measured before being added rather than guessed at, against
the class breakdown of nordic-baltic's transportation layer: rail is 10.6% of
it (1.80 MB of 17.0 MB) and secondary 30.6%, which scaled to this region works
out at a few MB each — cheap next to the water this archive already carries.
`transportation_name` stays small for a different reason: OpenMapTiles only
emits street names from z12, above this archive's z11 ceiling, so at these zooms
the layer is essentially just motorway and trunk refs.

Three deliberate exclusions keep it cheap:

- **No `landcover`/`landuse`.** They were 115 KB of that 178 KB Stockholm tile —
  the most expensive layers per unit of visual gain.
- **No `place`.** `nordic-baltic.pmtiles` already labels these countries; tiling
  them again would double-draw every city name.
- **Filtered before merging**, not after, so each country's file is disjoint and
  the shared-epoch constraint that applies to the nordic-baltic merge does not
  apply here.

The style draws this source with paint copied verbatim from the matching
`nordic` layers, so the seam between the two archives is invisible. Keep them
identical if either changes.

### `stations.geojson` — railway stations (all zooms)

Tiled, not a plain GeoJSON source. As GeoJSON the whole file was fetched on
every map load — 2.7 MB, 375 KB gzipped once both regions were in — for
something no layer draws below z9. `merge-stations.sh` now also runs it through
tippecanoe into `dist/stations.pmtiles` (1.4 MB, root-only directory), so a
client range-requests a 12 KB directory plus the tiles in view instead. The
per-feature minzoom mirrors the style: mainline stations from z9, halts and
urban transit from z11; points overzoom above z11.

`dist/stations.geojson` is still published for anyone consuming the data
directly, but the style no longer loads it. Each regional build writes its own
`dist/stations-<region>.geojson` through `scripts/extract-stations.sh`, and
`scripts/merge-stations.sh` (`make stations`) combines them into the single
file the style declares. The merge tolerates a region being missing, so one
failed build costs that region's stations rather than the whole source.

### `finland.pmtiles` — MML detail for Finland (z6–11)

Built by `scripts/generate-finland.sh` from MML Maastokartta 1:250k
shapefiles (kapsi.fi mirror), merged and reprojected EPSG:3067 → EPSG:4326
with GDAL. Tiled layers: `hallinto`, `vesi`, `tie`, `rautatie`, `taajama`,
`raja`. Finland is labelled from the OpenMapTiles `place` layer, so MML
`nimisto` is merged but not tiled.

Two things keep the tiles light, both tuned to what the style actually
draws:

- **z6 floor.** The lowest `finland` layer minzoom in the style is 6, so
  z0–5 tiles (350–670 KB each) were built and never fetched.
- **Per-zoom `tie` filter.** MML ships every road class at full detail, but
  the style draws only motorway and primary below z9 — measured, 86.5% of
  the `tie` bytes in a z7 tile were classes nothing rendered until z9/z10.
  A tippecanoe `-j` filter drops them per zoom (secondary/tertiary/ferry
  from z9, tracks from z10). **Keep those thresholds in sync with the
  `tie-*` layer minzooms in `scripts/style.template.json`.**

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
landuse, water, waterways, country boundaries, railways (z8+), roads (z5+)
→ MML Finland layers, railways then roads (z7+) → labels.

Route numbers come from the OpenMapTiles `transportation_name` layer (MML
`Tienumero` inside Finland) and are drawn as coloured shields — a bold label
over a thick `text-halo` in the class colour. OSM joins multiple numbers for one
road with a semicolon (`E18;E75`); the style renders them separated by three
spaces using `["join", ["split", ...]]`. Those two are MapLibre expressions
rather than Mapbox style-spec ones, so the style needs MapLibre GL JS 5+.

`nordic-road-number` is deliberately the lowest-priority symbol layer: the
`nordic` source covers Finland as well, and labels draw above `hallinto`, so
without that the OSM shields would win over the MML ones inside Finland.

The label block is ordered by **collision priority, not by drawing**. MapLibre
places symbols in reverse style order, so the last symbol layer is placed first
and wins. The order therefore runs least to most important: world country
labels, road numbers, the `finland-hd` road/water/place labels, village,
station labels, country, town, and `place-city` last. Get this wrong and city
names vanish the moment the z12/z13 `finland-hd` labels switch on.

That order is load-bearing. `hallinto` is an opaque fill covering all of
Finland, so every `nordic` layer below it is masked inside Finland and shows
only in the rest of the region — which is why Finland gets MML geometry and
the neighbours get OSM, from the same style. Railways go before the road
layers in both blocks so they draw underneath roads, as on GT Tiekartta.
MML railways are drawn with a track-count-dependent width (`Raideluku`) and
a white dashed overlay for the classic hatched look; `Vertikaali` below 0
(tunnel) drops the opacity.

Stations render from the `stations` GeoJSON source: solid dots for mainline
stations from z9, hollow dots for halts and orange dots for metro/light rail
from z11, names from z11. `rank` (0 station, 1 halt, 2 urban transit) is
precomputed at extraction time and drives both the per-zoom split and label
collision priority.

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
https://tiles.palikkaharrastajat.fi/stations.geojson
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
  cover the whole region), and as of the tile-weight pass the layer is no
  longer tiled into `finland.pmtiles` either.
- `finland.pmtiles` now starts at z6 rather than z0. Nothing in the style
  requested those zooms, but a consumer relying on the archive directly
  should note the new floor.
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
