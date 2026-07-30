.PHONY: help
help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: shell
shell: ## Enter devenv shell
	devenv shell

.PHONY: tiles
tiles: world finland finland-hd nordic-baltic neighbours stations style fonts ## Build all PMTiles, style and fonts into dist/

.PHONY: world
world: dist/world.pmtiles ## Generate world country borders and labels (Natural Earth, z0-6)

dist/world.pmtiles: scripts/generate-world.sh
	bash scripts/generate-world.sh

.PHONY: finland
finland: dist/finland.pmtiles ## Generate the Finland basemap from MML open data (z0-11)

dist/finland.pmtiles: scripts/generate-finland.sh
	bash scripts/generate-finland.sh

.PHONY: finland-hd
finland-hd: dist/finland-hd.pmtiles ## Generate Finland high-zoom OSM detail (z12-13)

dist/finland-hd.pmtiles: scripts/generate-finland-hd.sh
	bash scripts/generate-finland-hd.sh

.PHONY: nordic-baltic
nordic-baltic: dist/nordic-baltic.pmtiles dist/stations-nordic-baltic.geojson ## Generate Nordic + Baltic OSM tiles with Planetiler (z0-11)

# Grouped target (&:): one run of the script writes both the archive and the
# stations GeoJSON, so either one going missing must re-run it exactly once.
dist/nordic-baltic.pmtiles dist/stations-nordic-baltic.geojson &: scripts/generate-nordic-baltic.sh scripts/nordic-baltic.poly scripts/extract-stations.sh
	bash scripts/generate-nordic-baltic.sh

.PHONY: neighbours
neighbours: dist/neighbours.pmtiles dist/stations-neighbours.geojson ## Generate water, major roads + rail for Benelux, Germany, Poland (z0-11)

dist/neighbours.pmtiles dist/stations-neighbours.geojson &: scripts/generate-neighbours.sh scripts/nordic-baltic.poly scripts/extract-stations.sh
	bash scripts/generate-neighbours.sh

.PHONY: stations
stations: dist/stations.geojson dist/stations.pmtiles ## Merge the per-region station files and tile them

# Grouped target (&:): one run writes the merged GeoJSON and the tiled archive.
dist/stations.geojson dist/stations.pmtiles &: scripts/merge-stations.sh dist/stations-nordic-baltic.geojson dist/stations-neighbours.geojson
	bash scripts/merge-stations.sh

.PHONY: style
style: ## Generate dist/style.json and dist/index.html (override base URL with BASE_URL=...)
	bash scripts/generate-style.sh

.PHONY: fonts
fonts: ## Fetch glyph fonts into dist/fonts/
	bash scripts/fetch-fonts.sh

.PHONY: serve
serve: ## Serve dist/ locally with range-request + CORS support on :8080
	caddy run --config Caddyfile

.PHONY: watch
watch: ## Watch style and html templates, rebuild on change, and serve locally
	@echo "Starting local server on :8080 and watching for template changes..."
	@bash -c 'caddy run --config Caddyfile & CADDY_PID=$$!; \
		trap "kill $$CADDY_PID" EXIT; \
		watchexec -w scripts/style.template.json -w scripts/index.template.html -r "make style BASE_URL=http://localhost:8080"'

.PHONY: clean
clean: ## Remove generated output
	rm -rf dist

.PHONY: clean-cache
clean-cache: ## Remove downloaded source data cache (forces a full re-fetch)
	rm -rf .cache
