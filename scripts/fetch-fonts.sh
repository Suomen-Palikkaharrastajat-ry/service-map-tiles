#!/usr/bin/env bash
# Fetch prebuilt glyph PBFs (openmaptiles/fonts release) for the font stacks
# referenced by scripts/style.template.json.
set -euo pipefail

CACHE=.cache/fonts
mkdir -p "$CACHE"
mkdir -p dist/fonts

FONTS_URL="https://github.com/openmaptiles/fonts/releases/download/v2.0/noto-open-sans.zip"
STACKS=("Open Sans Regular" "Open Sans Semibold" "Open Sans Bold")

if [ ! -d "$CACHE/extracted" ]; then
  echo "Downloading glyph fonts..."
  curl -sL -o "$CACHE/fonts.zip" "$FONTS_URL"
  unzip -o -q "$CACHE/fonts.zip" -d "$CACHE/extracted"
fi

for stack in "${STACKS[@]}"; do
  # The zip may nest stacks under a top-level directory; find the stack dir.
  stack_dir=$(find "$CACHE/extracted" -type d -name "$stack" | head -n1)
  if [ -z "$stack_dir" ]; then
    echo "ERROR: font stack '$stack' not found in $FONTS_URL" >&2
    exit 1
  fi
  echo "Copying '$stack'..."
  rm -rf "dist/fonts/$stack"
  cp -r "$stack_dir" "dist/fonts/$stack"
done

# The SIL OFL 1.1 requires the license to be distributed with the font. The
# upstream openmaptiles/fonts release ships no license text, so serve our
# vendored copy alongside the glyphs.
cp licenses/SIL-OFL-1.1.txt dist/fonts/OFL.txt

echo "Fonts ready in dist/fonts/ (glyphs + OFL.txt)."
