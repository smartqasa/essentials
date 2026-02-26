#!/bin/sh
set -eu

CURL="/usr/bin/curl"
JQ="/usr/bin/jq"

ROOT="/config"
SQCONFIG="$ROOT/sqconfig.json"

# Essentials configuration (version file comparison; stored under /config/smartqasa)
ESSENTIALS_REPO="smartqasa/essentials"
ESSENTIALS_DIR="$ROOT/smartqasa"
ESSENTIALS_FILE="version.txt"          # local file name
ESSENTIALS_REMOTE_PATH="version.txt"   # path in GitHub repo

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
# Function to check a module (loader/elements)
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
  local INSTALLED
  INSTALLED=$(
    grep -a -m1 "$MARKER" "$JS" 2>/dev/null \
      | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?' \
      | head -n1 \
      | tr -d '\r\n' \
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
# Function to check essentials via version file
# Outputs: "true" if mismatch, "false" if match/unknown
###############################################
check_essentials() {
  log "Checking essentials..."

  local LOCAL_PATH="$ESSENTIALS_DIR/$ESSENTIALS_FILE"
  log "essentials_LOCAL_PATH=$LOCAL_PATH"

  if [ ! -f "$LOCAL_PATH" ]; then
    log "essentials: missing local version file -> returning false"
    echo "false"
    return
  fi

  local INSTALLED
  INSTALLED=$(
    cat "$LOCAL_PATH" 2>/dev/null \
      | tr -d '\r\n' \
      || true
  )
  INSTALLED=$(printf "%s" "$INSTALLED" | tr -d '\n')
  log "essentials_INSTALLED='${INSTALLED:-<empty>}'"

  local VERSION_URL
  VERSION_URL="https://raw.githubusercontent.com/$ESSENTIALS_REPO/$BRANCH/$ESSENTIALS_REMOTE_PATH"
  log "essentials_VERSION_URL=$VERSION_URL"

  local LATEST
  LATEST=$(
    $CURL -Ls "$VERSION_URL" \
      | tr -d '\r\n' \
      || true
  )
  LATEST=$(printf "%s" "$LATEST" | tr -d '\n')
  log "essentials_LATEST='${LATEST:-<empty>}'"

  if [ -z "$INSTALLED" ]; then
    log "essentials: INSTALLED empty -> returning false"
    echo "false"
    return
  fi

  if [ -z "$LATEST" ]; then
    log "essentials: LATEST empty -> returning false"
    echo "false"
    return
  fi

  if [ "$INSTALLED" != "$LATEST" ]; then
    log "essentials: MISMATCH -> true"
    echo "true"
  else
    log "essentials: MATCH -> false"
    echo "false"
  fi
}

###############################################
# Check essentials
###############################################
ESSENTIALS_RESULT=$(check_essentials)

###############################################
# Check dash-loader
###############################################
LOADER_RESULT=$(check_module "$LOADER_REPO" "$LOADER_DIR" "$LOADER_GLOB" "$LOADER_MARKER" "loader")

###############################################
# Check dash-elements
###############################################
ELEMENTS_RESULT=$(check_module "$ELEMENTS_REPO" "$ELEMENTS_DIR" "$ELEMENTS_GLOB" "$ELEMENTS_MARKER" "elements")

log "RESULTS: loader=$LOADER_RESULT elements=$ELEMENTS_RESULT essentials=$ESSENTIALS_RESULT"

# Return true if any mismatched
if [ "$LOADER_RESULT" = "true" ] || [ "$ELEMENTS_RESULT" = "true" ] || [ "$ESSENTIALS_RESULT" = "true" ]; then
  echo "true"
else
  echo "false"
fi

exit 0