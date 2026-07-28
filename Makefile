.PHONY: help
help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: shell
shell: ## Enter devenv shell
	devenv shell

.PHONY: tiles
tiles: world finland nordic-baltic style fonts ## Build all PMTiles, style and fonts into dist/

.PHONY: world
world: dist/world.pmtiles ## Generate world country borders and labels (Natural Earth, z0-6)

dist/world.pmtiles: scripts/generate-world.sh
	bash scripts/generate-world.sh

.PHONY: finland
finland: dist/finland.pmtiles ## Generate the Finland basemap from MML open data (z0-11)

dist/finland.pmtiles: scripts/generate-finland.sh
	bash scripts/generate-finland.sh

.PHONY: nordic-baltic
nordic-baltic: dist/nordic-baltic.pmtiles ## Generate Nordic + Baltic OSM tiles with Planetiler (z0-11)

dist/nordic-baltic.pmtiles: scripts/generate-nordic-baltic.sh
	bash scripts/generate-nordic-baltic.sh

.PHONY: style
style: ## Generate dist/style.json and dist/index.html (override base URL with BASE_URL=...)
	bash scripts/generate-style.sh

.PHONY: fonts
fonts: ## Fetch glyph fonts into dist/fonts/
	bash scripts/fetch-fonts.sh

.PHONY: serve
serve: ## Serve dist/ locally with range-request + CORS support on :8080
	caddy run --config Caddyfile

.PHONY: clean
clean: ## Remove generated output
	rm -rf dist

.PHONY: clean-cache
clean-cache: ## Remove downloaded source data cache (forces a full re-fetch)
	rm -rf .cache
