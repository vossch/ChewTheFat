#!/usr/bin/env bash
# Fetch source datasets for prepare.py.
# Produces:
#   Tools/db-prep/sources/usda/food.csv, food_nutrient.csv, nutrient.csv,
#                         food_portion.csv, measure_unit.csv
#   Tools/db-prep/sources/offs/en.openfoodfacts.org.products.csv.gz
#
# These are large downloads (~600 MB on the wire, ~2 GB decompressed). Not
# committed to the repo — run before `make db-refresh`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/sources"
mkdir -p "$SRC/usda" "$SRC/offs"

# --- USDA FoodData Central ---------------------------------------------------
# Foundation Foods (SR Legacy is included in the same CSV bundle under data_type).
USDA_URL="${USDA_URL:-https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_csv_2024-10-31.zip}"
USDA_ZIP="$SRC/usda.zip"

if [ ! -f "$USDA_ZIP" ]; then
  echo "→ Downloading USDA FDC CSV bundle"
  curl -L --fail -o "$USDA_ZIP" "$USDA_URL"
fi

echo "→ Extracting USDA CSVs"
unzip -o -j "$USDA_ZIP" \
  "*/food.csv" "*/food_nutrient.csv" "*/nutrient.csv" \
  "*/food_portion.csv" "*/measure_unit.csv" \
  -d "$SRC/usda"

# --- Open Food Facts ---------------------------------------------------------
OFFS_URL="${OFFS_URL:-https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz}"
OFFS_GZ="$SRC/offs/en.openfoodfacts.org.products.csv.gz"

if [ ! -f "$OFFS_GZ" ]; then
  echo "→ Downloading Open Food Facts TSV dump"
  curl -L --fail -o "$OFFS_GZ" "$OFFS_URL"
fi

echo "✓ Sources ready at $SRC"
