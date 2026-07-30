{ pkgs, ... }:
{
  packages = with pkgs; [
    git
    tippecanoe
    gdal
    python3
    curl
    unzip
    osmium-tool
    pmtiles
    jdk21_headless
    caddy
    watchexec
  ];

  enterShell = ''
    echo ""
    echo "── map tiles dev environment ────────────────────────"
    echo "  tippecanoe: $(tippecanoe --version 2>&1 | head -n1)"
    echo "  gdal:       $(ogr2ogr --version)"
    echo "  osmium:     $(osmium --version | head -n1)"
    echo "  java:       $(java --version | head -n1)"
    echo ""
    echo "  make tiles  — build all PMTiles + style into dist/"
    echo "  make serve  — serve dist/ locally on :8080"
    echo "  make watch  — watch templates, rebuild style on change, and serve"
    echo ""
  '';
}
