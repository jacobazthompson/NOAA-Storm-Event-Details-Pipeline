#!/usr/bin/env bash
#
# pipeline.sh — Download a year of NOAA Storm Events, convert to GeoParquet.
#
# Usage:   ./pipeline.sh [YEAR]
# Example: ./pipeline.sh 2024
#
# Requires: bash, curl, gunzip, ogr2ogr (GDAL >= 3.5)
#
# This is a starter scaffold. Read the comments. Replace the [TODO] markers
# with the actual logic. Do not change the structure unless you have a reason.

RAW_DIR="data/raw"
PROCESSED_DIR="data/processed"

set -euo pipefail

# -----------------------------------------------------------------------------
# Config
# -----------------------------------------------------------------------------

# Year to pull. Override by passing as the first argument.
YEAR="${1:-2024}" 

# NOAA file naming pattern. The "c{CREATED_DATE}" portion changes when NOAA
# republishes a year. Look at https://www.ncei.noaa.gov/data/storm-events/files/
# and update CREATED_DATE for the year you want.
# -- CREATED_DATE="20250101
#Jacob - CREATED_DATE is dynamic on the table, need a solution to include 2022-2026 and updated dates for LTR capabilities

# -----------------------------------------------------------------------------
# Step 1: Set up directories
# -----------------------------------------------------------------------------

echo "[1/4] Setting up directories"
# [TODO] Use mkdir -p to create RAW_DIR and PROCESSED_DIR. Both should be
# safe to call even if the directories already exist.
mkdir -p "$RAW_DIR" "$PROCESSED_DIR"


BASE_URL="https://www.ncei.noaa.gov/pub/data/swdi/stormevents/csvfiles/"
#Claude Sonnet 5.5 Output:
#!/usr/bin/env python3
#"""Print all CREATED_DATE values available for a given storm events year."""
#establish that the user can run the python script
# --- Ensure beautifulsoup4 is available ---------------------------------------
if python3 -c "import bs4" 2>/dev/null; then
    PYTHON=python3
else
    VENV_DIR="$(dirname "${BASH_SOURCE[0]}")/.venv"
    if [[ ! -x "$VENV_DIR/bin/python" ]]; then
        echo "Setting up local Python environment (one-time)..."
        python3 -m venv "$VENV_DIR"
        "$VENV_DIR/bin/pip" install -q beautifulsoup4
    fi
    PYTHON="$VENV_DIR/bin/python"
fi

# --- Python section: prints CREATED_DATEs, one per line -----------------------
DATES_OUT=$("$PYTHON" - "$YEAR" "$BASE_URL" <<'PY'
import re
import sys
from urllib.request import urlopen

from bs4 import BeautifulSoup

year, base_url = sys.argv[1], sys.argv[2]

try:
    html = urlopen(base_url, timeout=30).read()
except Exception as e:
    sys.exit(f"Request failed: {e}")

table = BeautifulSoup(html, "html.parser").find("table")
if table is None:
    sys.exit("No table found on page.")

pattern = re.compile(
    rf"^StormEvents_details-ftp_v1\.0_d{re.escape(year)}_c(\d{{8}})\.csv\.gz$"
)
dates = {m.group(1) for a in table.find_all("a", href=True)
         if (m := pattern.match(a["href"]))}

if not dates:
    sys.exit(f"No files found for year {year}.")

print("\n".join(sorted(dates, reverse=True)))
PY
)
# --- Back to bash --------------------------------------------------------------

mapfile -t CREATED_DATES <<< "$DATES_OUT"

if [[ -t 0 ]]; then
    echo "Available created dates for $YEAR (newest first):"
    select CREATED_DATE in "${CREATED_DATES[@]}"; do
        [[ -n "${CREATED_DATE:-}" ]] && break
        echo "Invalid choice, try again."
    done
else
    CREATED_DATE="${CREATED_DATES[0]}"
    echo "Non-interactive run, using latest: $CREATED_DATE"
fi

FILE_NAME="StormEvents_details-ftp_v1.0_d${YEAR}_c${CREATED_DATE}.csv.gz"
URL="${BASE_URL}${FILE_NAME}"
echo "URL: $URL"
# Build FILE_NAME and URL
FILE_NAME="StormEvents_details-ftp_v1.0_d${YEAR}_c${CREATED_DATE}.csv.gz"
URL="${BASE_URL}${FILE_NAME}"

echo "Selected: $FILE_NAME"
echo "URL: $URL"



# -----------------------------------------------------------------------------
# Step 2: Download the raw file
# -----------------------------------------------------------------------------

echo "[2/4] Downloading ${FILE_NAME}"
# [TODO] Use curl to download URL into RAW_GZ. Suggested flags:
#   -L       follow redirects
#   -o       write to a specific output file path
#   --fail   exit non-zero on HTTP errors (4xx/5xx)
RAW_GZ="${RAW_DIR}/${FILE_NAME}"
# Skip the download if the file already exists (idempotency).
if [[ -f "$RAW_GZ" ]]; then
    echo "  Already downloaded, skipping: $RAW_GZ"
else
    curl -fSL -o "${RAW_GZ}" "$URL"
fi

# -----------------------------------------------------------------------------
# Step 3: Decompress
# -----------------------------------------------------------------------------

echo "[3/4] Decompressing"
RAW_CSV="${RAW_DIR}/${FILE_NAME%.gz}"
# [TODO] Use gunzip to decompress RAW_GZ into RAW_CSV.
# The -k flag keeps the original .gz so the pipeline can rerun.
# Skip this step if RAW_CSV already exists.
if [[ -f "$RAW_CSV" ]]; then
    echo "  Already extracted, skipping: $RAW_CSV"
else
    gunzip -c "$RAW_GZ" > "${RAW_CSV}"
fi
# -----------------------------------------------------------------------------
# Step 4: Convert CSV to GeoParquet
# -----------------------------------------------------------------------------

echo "[4/4] Converting to GeoParquet"
OUT_PARQUET="${PROCESSED_DIR}/storms_${YEAR}.parquet"

# [TODO] Use ogr2ogr to convert RAW_CSV into a GeoParquet file at OUT_PARQUET.
#
# The CSV uses BEGIN_LON / BEGIN_LAT for the storm start point. ogr2ogr can
# pick those up if you tell it the column names with -oo:
#
#   -oo X_POSSIBLE_NAMES=BEGIN_LON
#   -oo Y_POSSIBLE_NAMES=BEGIN_LAT
#
# The data is in WGS 84 (EPSG:4326). Set that explicitly with -a_srs.
#
# Use -f Parquet for the output format.
#
# Tip: ask your AI pair (see R1.3 prompts 4 and 6) for the exact ogr2ogr
# command, then verify the flags against `ogr2ogr --help` before running.
echo "ogrinfo: $(command -v ogrinfo)"
echo "ogr2ogr: $(command -v ogr2ogr)"
if ! command -v ogr2ogr >/dev/null 2>&1; then
    echo "ogr2ogr not found. See README for GDAL install." >&2
    exit 1
fi

GDAL_FORMATS="$(ogrinfo --formats)"
if ! grep -qi "parquet" <<< "$GDAL_FORMATS"; then
    echo "Your GDAL build has no Parquet driver. See README: GDAL Parquet support." >&2
    exit 1
fi



ogr2ogr -f Parquet "$OUT_PARQUET" "$RAW_CSV"  \
    -oo X_POSSIBLE_NAMES=BEGIN_LON \
    -oo Y_POSSIBLE_NAMES=BEGIN_LAT \
    -a_srs EPSG:4326

echo "Done. Output: ${OUT_PARQUET}"
echo "Open it in DuckDB:"
echo "  duckdb -c \"INSTALL spatial; LOAD spatial; SELECT COUNT(*) FROM read_parquet('${OUT_PARQUET}');\""
