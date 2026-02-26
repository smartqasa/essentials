#!/bin/sh
set -eu

CURL="/usr/bin/curl"
JQ="/usr/bin/jq"

ROOT="/config"
CONF="$ROOT/configuration.yaml"
SQCONFIG="$ROOT/sqconfig.json"

REPO="smartqasa/dash-elements"

log() { echo "[dash-elements-check] $*" >&2; }

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
# Get installed version from active JS bundle
###############################################
URL=$(grep -oE '/local/smartqasa/dash-elements/elements-[^ ]+\.js' "$CONF" | head -n 1 || true)
log "RESOURCE_URL=${URL:-<none>}"

if [ -z "$URL" ]; then
  log "No resource URL found in $CONF"
  echo "false"
  exit 0
fi

JS="$ROOT/www${URL#/local}"
log "JS_PATH=$JS"

if [ ! -f "$JS" ]; then
  log "JS file missing"
  echo "false"
  exit 0
fi

# Extract installed version. Support both:
#   window.smartqasa.versionElements="x"
#   window.smartqasa.versionElements='x'
#   window.smartqasa.versionElements=x
INSTALLED=$(
  sed -nE 's/.*versionElements[[:space:]]*=[[:space:]]*["'\'']?([^"'\''];[:space:]]+)["'\'']?.*/\1/p' "$JS" \
  | head -n 1 \
  | tr -d '\r' \
  || true
)
INSTALLED=$(printf "%s" "$INSTALLED" | tr -d '\n')
log "INSTALLED='$INSTALLED'"

###############################################
# Get latest available version from branch
###############################################
PKG_URL="https://raw.githubusercontent.com/$REPO/$BRANCH/package.json"
log "PKG_URL=$PKG_URL"

LATEST=$(
  $CURL -Ls "$PKG_URL" \
  | $JQ -r '.version // empty' 2>/dev/null \
  | tr -d '\r' \
  || true
)
LATEST=$(printf "%s" "$LATEST" | tr -d '\n')
log "LATEST='$LATEST'"

###############################################
# Compare
###############################################
if [ -z "$INSTALLED" ]; then
  log "INSTALLED empty -> returning false"
  echo "false"
  exit 0
fi

if [ -z "$LATEST" ]; then
  log "LATEST empty -> returning false"
  echo "false"
  exit 0
fi

if [ "$INSTALLED" != "$LATEST" ]; then
  log "MISMATCH -> true"
  echo "true"
else
  log "MATCH -> false"
  echo "false"
fi

exit 0