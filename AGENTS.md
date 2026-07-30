# AGENTS.md

This file provides instructions for AI coding agents working on this
project.

## Project Overview

This repository generates a self-hosted vector basemap as five regional
PMTiles archives (world / regional / Finland / Finland-HD / neighbours)
plus a MapLibre
`style.json` and glyph fonts, deployed to GitHub Pages for use by
[Palikkakartta (service-map)](https://github.com/Suomen-Palikkaharrastajat-ry/service-map)
and any other project that wants a self-hosted basemap instead of an
external tile provider.

There is no application code here — just the generation scripts, their
supporting Nix dev environment, and the CI automation that builds and
deploys the output.

## Repository Layout

```
scripts/generate-world.sh          Natural Earth 50m → dist/world.pmtiles (z0–6)
scripts/generate-finland.sh        MML 1:250k shapefiles → dist/finland.pmtiles (z6–11)
scripts/generate-finland-hd.sh     Geofabrik Finland OSM + Planetiler → dist/finland-hd.pmtiles (z12–13)
scripts/generate-nordic-baltic.sh  Geofabrik OSM + osmium + Planetiler → dist/nordic-baltic.pmtiles (z0–11)
                                   and dist/stations-nordic-baltic.geojson
scripts/generate-neighbours.sh     Geofabrik OSM, water + roads + rail → dist/neighbours.pmtiles (z0–11)
                                   and dist/stations-neighbours.geojson
scripts/extract-stations.sh        OSM extract → dist/stations-<region>.geojson (shared)
scripts/merge-stations.sh          dist/stations-*.geojson → dist/stations.geojson
scripts/generate-style.sh          style.template.json → dist/style.json + dist/index.html
scripts/fetch-fonts.sh             openmaptiles/fonts glyph PBFs → dist/fonts/
scripts/style.template.json        MapLibre style; __BASE_URL__ substituted at build time
scripts/index.template.html        QA viewer copied to dist/index.html
Caddyfile                          Local dist/ server (range requests + CORS)
dist/                              Generated Pages site (gitignored, not committed)
.cache/{world,finland,finland-hd,nordic-baltic,neighbours,fonts}/  Per-target source caches (gitignored)
docs/basemap.md                    How generation and publishing works
.github/workflows/basemap.yml      CI: shellcheck, parallel builds, Pages deploy
```

## Development Environment

The project uses **devenv** (Nix). Always run commands inside the devenv
shell:

```sh
make shell
```

## Build and Test Commands

| Command | Description |
|---|---|
| `make tiles` | Build all archives + style + fonts into `dist/` |
| `make world` / `make finland` / `make nordic-baltic` | Build a single archive |
| `make style` | Render `dist/style.json` (+`index.html`); `BASE_URL=...` overrides the Pages URL |
| `make fonts` | Fetch glyph fonts into `dist/fonts/` |
| `make serve` | Serve `dist/` on :8080 (Caddy: range requests + CORS) |
| `make clean` | Remove `dist/` |
| `make clean-cache` | Remove `.cache/` (forces a full re-download) |

Verify outputs with `pmtiles show dist/<file>.pmtiles` and
`pmtiles verify dist/<file>.pmtiles` (the `pmtiles` CLI is in the shell).

## Architecture Notes

- Each generation script owns one archive and one cache directory; CI
  builds them in parallel matrix jobs, each caching `.cache/<target>`
  keyed by the hash of `scripts/generate-<target>.sh`.
- **Planetiler** is not in nixpkgs; `generate-nordic-baltic.sh` downloads a
  pinned jar (version + sha256 constants at the top of the script) and
  runs it with the OpenMapTiles profile. It runs `java` from inside
  `.cache/nordic-baltic/` so Planetiler's default `data/sources/` download
  location (water polygons, Natural Earth, lake centerlines — several GB)
  stays inside the CI cache.
- Labels follow the OpenMapTiles `place` layer (class + rank, `name:fi`)
  across the whole region including Finland. MML `nimisto` is **not tiled** —
  `generate-finland.sh` still merges `KarttanimiPiste` so the data stays cached
  and re-addable, but it is left out of the tippecanoe input because nothing
  styles it and it cost 3–5% of every `finland` tile.
- **`finland.pmtiles` starts at z6, and `tie` is filtered per zoom.** The
  lowest `finland` layer minzoom in the style is 6, so z0–5 tiles were built and
  never requested. Within `tie`, only motorway/primary are tiled below z9:
  86.5% of the `tie` bytes in a z7 tile were classes nothing drew until z9/z10.
  The tippecanoe `-j` filter's thresholds must stay in sync with the `tie-*`
  layer minzooms in `scripts/style.template.json`.
- The style is a checked-in template; only `__BASE_URL__` is substituted.
  Keep source names (`world`, `nordic`, `neighbours`, `finland`,
  `finland-hd`, `stations`) and attribution strings stable. The contract with
  downstream is the `style.json` URL — `service-map` loads only that and never
  names a source — but keep them stable for other consumers.
- **Symbol layers are placed in REVERSE style order.** MapLibre's
  `Placement.continuePlacement` walks the layer order from the end backwards, so
  the symbol layer listed *last* is placed *first* and wins collisions. The
  place labels therefore sit at the end of the style, after the `finland-hd`
  road/water/place labels — otherwise a city name is silently collided away the
  moment those z12/z13 layers switch on, which looks like the label vanishing as
  soon as a fly-to settles. Keep `place-city` last.
- **Layer order encodes the data split.** `hallinto` is an opaque fill
  covering all of Finland and sits above every `nordic` layer, which is why
  the OSM `transportation-*`/`rail-nordic*` layers show outside Finland
  only, while the MML `tie-*`/`rautatie*` layers drawn after it show inside
  it. Rail goes before the road layers in each block so it draws underneath
  roads, as on GT Tiekartta.
- Train stations cannot come from the tiles: OpenMapTiles keeps them in its
  `poi` layer, which Planetiler pins to minzoom 14 — above the z13 built
  here. `scripts/extract-stations.sh` pulls them out of an OSM extract with
  `osmium tags-filter` (~30 s); `generate-nordic-baltic.sh` and
  `generate-neighbours.sh` each call it for their own region, writing
  `dist/stations-<region>.geojson`, and `scripts/merge-stations.sh` combines
  those into the single `dist/stations.geojson` the style declares. The merge
  tolerates a region being absent so one failed build degrades to a map missing
  that region's stations rather than a broken `stations` source.
- **Licenses/attribution are load-bearing.** Keep the source `attribution`
  fields, the vendored `licenses/` texts, `NOTICE.md`, and the served
  `dist/fonts/OFL.txt` (written by `fetch-fonts.sh`) and `dist/NOTICE.md`
  (written by `generate-style.sh`) in place. The SIL OFL requires the font
  license to be served with the glyphs; the upstream font zip ships none.

## Known Gotchas

- **Geofabrik extracts must share an epoch**: `osmium merge` fails if
  overlapping objects differ between extract dates. Never refresh a single
  `*-latest.osm.pbf`; wipe them all (`make clean-cache`) so they
  re-download together. The CI cache keeps them consistent between runs.
- **GitHub Pages size budget**: the whole `dist/` site must stay under
  ~1 GB; the assemble job fails above ~950 MB. The regional build uses
  `--only-layers` to include only the 7 styled layers; if archives
  grow too large, drop `--maxzoom` on `nordic-baltic` to 10, or on
  `finland-hd` to 13, or remove countries from the list.
- **PMTiles needs HTTP range requests** — plain `python3 -m http.server`
  will not work for local testing; use `make serve` (Caddy).
- **Planetiler writes a bogus header center zoom**: it derives it from the
  tileset bounds and ignores `--minzoom/--maxzoom`, so `finland-hd` (z12–13)
  came out with `CenterZoom=4` and `pmtiles verify` rejected the header as
  invalid. `generate-finland-hd.sh` fixes it afterwards with
  `pmtiles edit --header-json` (header-only rewrite, tile data untouched); the
  `assemble` job now runs `pmtiles verify` so a regression fails CI. Note
  `pmtiles verify` exits 0 even when it reports `invalid` — match on its output.
- MML's `kartat.kapsi.fi` mirror, Natural Earth's CDN, and Geofabrik are
  external and can be slow or rate-limit; the per-target caches exist
  specifically to avoid re-hitting them.
- Keep `dist/` and `.cache/` out of version control — large, regenerable,
  gitignored; the deployed Pages site is the publish channel.

## Security Considerations

No secrets or authenticated services are involved beyond the Cachix auth
token already configured in CI. The workflow needs `pages: write` and
`id-token: write` to deploy GitHub Pages; `contents` stays read-only.
The Planetiler jar download is pinned by sha256.
