#!/bin/sh
set -eu

CURL="/usr/bin/curl"
JQ="/usr/bin/jq"

ROOT="/config"
SQCONFIG="$ROOT/sqconfig.json"

# Dash-loader configuration
LOADER_REPO="smartqasa/dash-loader"
LOADER_DIR="$ROOT/www/smartqasa/dash-loader"
LOADER_GLOB="loader-v*.js"
LOADER_MARKER="SmartQasa Loader ⏏"

# Dash-elements configuration
ELEMENTS_REPO="smartqasa/dash-elements"
ELEMENTS_DIR="$ROOT/www/smartqasa/dash-elements"
ELEMENTS_GLOB="elements-v*.js"
ELEMENTS_MARKER="SmartQasa Elements ⏏"

log() { echo "[dash-check] $*" >&2; }

###############################################
# Determine branch (main/beta)
###############################################
BRANCH="main"
if [ -f "$SQCONFIG" ]; then
  CHANNEL=$($JQ -r '(.channel // "main")' "$SQCONFIG" 2>/dev/null || echo "main")
  [ "$CHANNEL" = "beta" ] && BRANCH="beta"
fi
log "BRANCH=$BRANCH"

###############################################
# Function to check a module
# Outputs: "true" if mismatch, "false" if match/unknown
###############################################
check_module() {
  local REPO="$1"
  local DIR="$2"
  local GLOB="$3"
  local MARKER="$4"
  local NAME="$5"

  log "Checking $NAME..."

  # Resolve deployed JS file
  local JS
  JS=$(ls "$DIR"/$GLOB 2>/dev/null | head -n 1 || true)
  log "${NAME}_JS_PATH=${JS:-<none>}"

  if [ -z "$JS" ] || [ ! -f "$JS" ]; then
    log "${NAME}: missing bundle -> returning false"
    echo "false"
    return
  fi

  # Extract installed version from console marker line
  # Matches: "<MARKER> <version>"
  local INSTALLED
  INSTALLED=$(
    grep -oE "${MARKER// /[[:space:]]+}[[:space:]]+[^[:space:]]+" "$JS" \
      | head -n 1 \
      | sed -E 's/.*⏏[[:space:]]+([^[:space:]]+).*/\1/' \
      | tr -d '\r' \
      || true
  )
  INSTALLED=$(printf "%s" "$INSTALLED" | tr -d '\n')
  log "${NAME}_INSTALLED='${INSTALLED:-<empty>}'"

  # Fetch latest version from GitHub branch package.json
  local PKG_URL
  PKG_URL="https://raw.githubusercontent.com/$REPO/$BRANCH/package.json"
  log "${NAME}_PKG_URL=$PKG_URL"

  local LATEST
  LATEST=$(
    $CURL -Ls "$PKG_URL" \
      | $JQ -r '.version // empty' 2>/dev/null \
      | tr -d '\r' \
      || true
  )
  LATEST=$(printf "%s" "$LATEST" | tr -d '\n')
  log "${NAME}_LATEST='${LATEST:-<empty>}'"

  # Decide
  if [ -z "$INSTALLED" ]; then
    log "${NAME}: INSTALLED empty -> returning false"
    echo "false"
    return
  fi

  if [ -z "$LATEST" ]; then
    log "${NAME}: LATEST empty -> returning false"
    echo "false"
    return
  fi

  if [ "$INSTALLED" != "$LATEST" ]; then
    log "${NAME}: MISMATCH -> true"
    echo "true"
  else
    log "${NAME}: MATCH -> false"
    echo "false"
  fi
}

###############################################
# Check dash-loader
###############################################
LOADER_RESULT=$(check_module "$LOADER_REPO" "$LOADER_DIR" "$LOADER_GLOB" "$LOADER_MARKER" "loader")

###############################################
# Check dash-elements
###############################################
ELEMENTS_RESULT=$(check_module "$ELEMENTS_REPO" "$ELEMENTS_DIR" "$ELEMENTS_GLOB" "$ELEMENTS_MARKER" "elements")

log "RESULTS: loader=$LOADER_RESULT elements=$ELEMENTS_RESULT"

# Return true if either mismatched
if [ "$LOADER_RESULT" = "true" ] || [ "$ELEMENTS_RESULT" = "true" ]; then
  echo "true"
else
  echo "false"
fi

exit 0