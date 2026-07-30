# Map tiles (Palikkakartta basemap)

Self-hosted PMTiles vector basemap generator for Suomen Palikkaharrastajat
ry's [Palikkaharrastajat ry](https://github.com/Suomen-Palikkaharrastajat-ry/service-map)
and other SPA/PWAs, extracted from that repository.

Rather than depending on an external tile provider, this builds its own
vector tiles from open data and serves them via GitHub Pages at <https://tiles.palikkaharrastajat.fi/>.

Three regional PMTiles archives keep downloads small — especially on
mobile, clients only fetch the tiles for the area and zoom they look at:

| Archive | Source | Coverage | Zoom |
|---|---|---|---|
| `world.pmtiles` | Natural Earth 50m | World country borders + labels | z0–6 |
| `nordic-baltic.pmtiles` | OpenStreetMap (Geofabrik) via Planetiler, OpenMapTiles schema | Norway, Sweden, Denmark, Finland, Estonia, Latvia, Lithuania | z0–11 |
| `finland.pmtiles` | MML Maastokartta 1:250k (kapsi.fi mirror) | Finland | z0–11 |
| `finland-hd.pmtiles` | OpenStreetMap (Geofabrik) via Planetiler, OpenMapTiles schema | Finland (buildings, detailed roads, names) | z12–13 |

The site also serves `style.json` (a ready MapLibre style referencing all
three archives with absolute URLs), glyph fonts under `fonts/`, and a QA
viewer at `index.html`.

## Development Environment

This project uses `devenv` (Nix) to provide `tippecanoe`, `gdal`,
`osmium`, `java` (for Planetiler), the `pmtiles` CLI, and `caddy`.

```sh
make shell
```

## Common Commands

| Command | What it does |
|---|---|
| `make shell` | Open the development shell |
| `make tiles` | Build everything into `dist/` |
| `make world` / `make finland` / `make nordic-baltic` | Build one archive |
| `make style` | Generate `dist/style.json` + `dist/index.html` (override with `BASE_URL=http://localhost:8080`) |
| `make fonts` | Fetch glyph fonts into `dist/fonts/` |
| `make serve` | Serve `dist/` locally on :8080 with range requests + CORS |
| `make clean` | Remove generated output (`dist/`) |
| `make clean-cache` | Remove the downloaded source data cache (`.cache/`) |

## Project Structure

```text
scripts/generate-world.sh          Natural Earth → dist/world.pmtiles
scripts/generate-finland.sh        MML shapefiles → dist/finland.pmtiles
scripts/generate-nordic-baltic.sh  Geofabrik OSM + Planetiler → dist/nordic-baltic.pmtiles
scripts/generate-style.sh          style.template.json → dist/style.json + index.html
scripts/fetch-fonts.sh             Glyph PBFs → dist/fonts/
scripts/style.template.json        MapLibre style with __BASE_URL__ placeholder
dist/                              Generated Pages site (gitignored)
.cache/                            Per-target source data caches (gitignored)
.github/workflows/basemap.yml      CI: parallel builds + GitHub Pages deploy
docs/basemap.md                    How the tiles are generated and consumed
```

See [`docs/basemap.md`](docs/basemap.md) for details.

## CI and Publishing

GitHub Actions ([`.github/workflows/basemap.yml`](.github/workflows/basemap.yml))
shellchecks the scripts and builds the three archives in parallel jobs
(each with its own source-data cache) on every push and pull request. An
assemble job adds `style.json`, `index.html`, and fonts, checks the total
size against GitHub Pages' ~1 GB budget, and on `main` deploys `dist/` to
GitHub Pages.

> **One-time setup**: the repository's *Settings → Pages → Build and
> deployment → Source* must be set to **GitHub Actions**.

## Licenses & attribution

The basemap combines several open-data sources (MML, OpenStreetMap,
OpenMapTiles, Natural Earth) and Open Sans glyph fonts. Required attribution
strings are baked into the served `style.json` (and shown automatically by
maplibre-gl). See [`NOTICE.md`](NOTICE.md) for the source → license →
attribution summary and [`licenses/`](licenses/) for the full texts; the Open
Sans OFL is also served at `fonts/OFL.txt`.

Human-facing usage lives here in `README.md`. Agent-specific development
instructions live in [`AGENTS.md`](AGENTS.md).
