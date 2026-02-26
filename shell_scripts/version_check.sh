#!/bin/sh
set -eu

CURL="/usr/bin/curl"
JQ="/usr/bin/jq"

ROOT="/config"
CONF="$ROOT/configuration.yaml"
ELEMENTS_DIR="$ROOT/www/smartqasa/dash-elements"
SQCONFIG="$ROOT/sqconfig.json"

REPO="smartqasa/dash-elements"

###############################################
# Determine branch (main/beta)
###############################################
BRANCH="main"

if [ -f "$SQCONFIG" ]; then
  CHANNEL=$($JQ -r '(.channel // "main")' "$SQCONFIG")
  if [ "$CHANNEL" = "beta" ]; then
    BRANCH="beta"
  fi
fi

###############################################
# Get installed version from active JS bundle
###############################################
URL=$(grep -oE '/local/smartqasa/dash-elements/elements-[^ ]+\.js' "$CONF" | head -n 1 || true)

if [ -z "$URL" ]; then
  echo "false"
  exit 0
fi

JS="$ROOT/www${URL#/local}"

if [ ! -f "$JS" ]; then
  echo "false"
  exit 0
fi

INSTALLED=$(
  grep -oE 'versionElements[[:space:]]*=[[:space:]]*"[^"]+"' "$JS" |
  head -n 1 |
  sed -E 's/.*="([^"]+)".*/\1/' || true
)

###############################################
# Get latest available version from branch
###############################################
LATEST=$(
  $CURL -Ls "https://raw.githubusercontent.com/$REPO/$BRANCH/package.json" |
  $JQ -r '.version // empty' || true
)

###############################################
# Compare
###############################################
if [ -n "$INSTALLED" ] && [ -n "$LATEST" ] && [ "$INSTALLED" != "$LATEST" ]; then
  echo "true"
else
  echo "false"
fi

exit 0