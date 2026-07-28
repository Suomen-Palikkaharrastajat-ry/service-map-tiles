# AGENTS.md

This file provides instructions for AI coding agents working on this
project.

## Project Overview

This repository generates a self-hosted vector basemap as three regional
PMTiles archives (world / Nordic+Baltic / Finland) plus a MapLibre
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
scripts/generate-finland.sh        MML 1:250k shapefiles → dist/finland.pmtiles (z0–11)
scripts/generate-nordic-baltic.sh  Geofabrik OSM + osmium + Planetiler → dist/nordic-baltic.pmtiles (z0–11)
scripts/generate-style.sh          style.template.json → dist/style.json + dist/index.html
scripts/fetch-fonts.sh             openmaptiles/fonts glyph PBFs → dist/fonts/
scripts/style.template.json        MapLibre style; __BASE_URL__ substituted at build time
scripts/index.template.html        QA viewer copied to dist/index.html
Caddyfile                          Local dist/ server (range requests + CORS)
dist/                              Generated Pages site (gitignored, not committed)
.cache/{world,finland,nordic-baltic,fonts}/  Per-target source caches (gitignored)
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
  across the whole region including Finland. MML `nimisto` stays in
  `finland.pmtiles` but is unstyled.
- The style is a checked-in template; only `__BASE_URL__` is substituted.
  Keep source names (`world`, `nordic`, `finland`) and attribution strings
  stable — downstream apps depend on them.
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
  ~1 GB; the assemble job fails above ~950 MB. If `nordic-baltic.pmtiles`
  grows too large, first drop `--maxzoom` to 10, then exclude OpenMapTiles
  layers (`--exclude-layers=building,housenumber,poi`).
- **PMTiles needs HTTP range requests** — plain `python3 -m http.server`
  will not work for local testing; use `make serve` (Caddy).
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
