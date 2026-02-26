#!/bin/sh
set -eu

CURL="/usr/bin/curl"
JQ="/usr/bin/jq"

ROOT="/config"
SQCONFIG="$ROOT/sqconfig.json"

REPO="smartqasa/dash-elements"
DIR="$ROOT/www/smartqasa/dash-elements"

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
# Locate deployed bundle (exactly one expected)
###############################################
JS=$(ls "$DIR"/elements-v*.js 2>/dev/null | head -n 1 || true)
log "JS_PATH=${JS:-<none>}"

if [ -z "$JS" ] || [ ! -f "$JS" ]; then
  log "No elements-v*.js found in $DIR"
  echo "false"
  exit 0
fi

###############################################
# Extract installed version from bundle
# Supports: versionElements="x"  OR 'x' OR unquoted
###############################################
INSTALLED=$(
  grep -oE 'SmartQasa Elements ⏏ [^ ]+' "$JS" \
  | head -n 1 \
  | sed -E 's/.*⏏[[:space:]]+([^[:space:]]+).*/\1/' \
  | tr -d '\r' \
  || true
)
INSTALLED=$(printf "%s" "$INSTALLED" | tr -d '\n')
log "INSTALLED='${INSTALLED:-<empty>}'"

###############################################
# Fetch available version from GitHub branch package.json
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
log "LATEST='${LATEST:-<empty>}'"

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