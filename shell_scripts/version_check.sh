#!/bin/sh
set -eu

CURL="/usr/bin/curl"
JQ="/usr/bin/jq"

ROOT="/config"
SQCONFIG="$ROOT/sqconfig.json"

# Dash-loader configuration
LOADER_REPO="smartqasa/dash-loader"
LOADER_DIR="$ROOT/www/smartqasa/dash-loader"

# Dash-elements configuration
ELEMENTS_REPO="smartqasa/dash-elements"
ELEMENTS_DIR="$ROOT/www/smartqasa/dash-elements"

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
###############################################
check_module() {
  local REPO="$1"
  local DIR="$2"
  local NAME="$3"

  log "Checking $NAME..."
  
  JS=$(ls "$DIR"/elements-v*.js 2>/dev/null | head -n 1 || true)
  log "${NAME}_JS_PATH=${JS:-<none>}"

  if [ -z "$JS" ] || [ ! -f "$JS" ]; then
    log "No elements-v*.js found in $DIR"
    echo "false"
    return
  fi

  INSTALLED=$(
    grep -oE 'SmartQasa Elements ⏏ [^ ]+' "$JS" \
    | head -n 1 \
    | sed -E 's/.*⏏[[:space:]]+([^[:space:]]+).*/\1/' \
    | tr -d '\r' \
    || true
  )
  INSTALLED=$(printf "%s" "$INSTALLED" | tr -d '\n')
  log "${NAME}_INSTALLED='${INSTALLED:-<empty>}'"

  PKG_URL="https://raw.githubusercontent.com/$REPO/$BRANCH/package.json"
  log "${NAME}_PKG_URL=$PKG_URL"

  LATEST=$(
    $CURL -Ls "$PKG_URL" \
    | $JQ -r '.version // empty' 2>/dev/null \
    | tr -d '\r' \
    || true
  )
  LATEST=$(printf "%s" "$LATEST" | tr -d '\n')
  log "${NAME}_LATEST='${LATEST:-<empty>}'"

  if [ -z "$INSTALLED" ]; then
    log "${NAME}_INSTALLED empty -> returning false"
    echo "false"
    return
  fi

  if [ -z "$LATEST" ]; then
    log "${NAME}_LATEST empty -> returning false"
    echo "false"
    return
  fi

  if [ "$INSTALLED" != "$LATEST" ]; then
    log "${NAME}_MISMATCH -> true"
    echo "true"
  else
    log "${NAME}_MATCH -> false"
    echo "false"
  fi
}

###############################################
# Check dash-loader
###############################################
LOADER_RESULT=$(check_module "$LOADER_REPO" "$LOADER_DIR" "loader")

###############################################
# Check dash-elements
###############################################
ELEMENTS_RESULT=$(check_module "$ELEMENTS_REPO" "$ELEMENTS_DIR" "elements")