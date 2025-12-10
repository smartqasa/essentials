#!/bin/bash
set -e

###############################################
# Full path binaries (HA container compatible)
###############################################
CURL="/usr/bin/curl"
UNZIP="/usr/bin/unzip"
MKDIR="/bin/mkdir"
RM="/bin/rm"
CP="/bin/cp"
MV="/bin/mv"
GZIP="/bin/gzip"

###############################################
# Colors
###############################################
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

###############################################
# Repo → Local Path Map
###############################################
ROOT="/config"

REPO_BLUEPRINTS="smartqasa/blueprints"
REPO_MEDIA="smartqasa/media"
REPO_ESSENTIALS="smartqasa/essentials"
REPO_LOADER="smartqasa/dash-loader"
REPO_ELEMENTS="smartqasa/dash-elements"
REPO_UTILITIES="smartqasa/ha-utilities"
REPO_PICO_LINK="smartqasa/pico-link"

DIR_BLUEPRINTS="$ROOT/blueprints/automation/smartqasa"
DIR_MEDIA="$ROOT/www/smartqasa/media"
DIR_ESSENTIALS="$ROOT/smartqasa"
DIR_LOADER="$ROOT/www/smartqasa/dash-loader"
DIR_ELEMENTS="$ROOT/www/smartqasa/dash-elements"
DIR_UTILITIES="$ROOT/custom_components/smartqasa"
DIR_PICO_LINK="$ROOT/custom_components/pico_link"

TMP="/tmp/sq_extract"

###############################################
# Load SmartQasa sqconfig.json
###############################################
SQCONFIG_PATH="$ROOT/sqconfig.json"
UPDATE_CHANNEL="main"
AUTO_UPDATE="true"

if [ -f "$SQCONFIG_PATH" ]; then
    CHANNEL=$(jq -r '(.channel // "main")' "$SQCONFIG_PATH")
    AUTO_UPDATE=$(jq -r '(.auto_update // true) | tostring' "$SQCONFIG_PATH")

    [ "$CHANNEL" = "beta" ] && UPDATE_CHANNEL="beta"
fi

if [ "$AUTO_UPDATE" != "true" ]; then
    echo -e "${YELLOW}"
    echo "====================================="
    echo " ⏭️  Auto-update disabled — exiting."
    echo "====================================="
    echo -e "${RESET}"
    exit 0
fi

echo ""
echo -e "${GREEN}====================================="
echo "   🚀 SmartQasa Sync Starting"
echo "=====================================${RESET}"
echo "📡 Update channel: $UPDATE_CHANNEL"
echo "🔧 Auto-update: $AUTO_UPDATE"

###############################################
# Define which repos support beta
###############################################
beta_supported=(
    "smartqasa/dash-loader"
    "smartqasa/dash-elements"
    "smartqasa/pico-link"
)

repo_supports_beta() {
    for r in "${beta_supported[@]}"; do
        [ "$1" = "$r" ] && return 0
    done
    return 1
}

###############################################
# Download + Extract Repo
###############################################
extract_repo() {
    local REPO="$1"
    local NAME=$(basename "$REPO")

    local BRANCH="main"
    if [ "$UPDATE_CHANNEL" = "beta" ] && repo_supports_beta "$REPO"; then
        BRANCH="beta"
        echo "🔍 $REPO supports beta — using beta branch"
    fi

    local ZIP="/tmp/${NAME}.zip"

    echo ""
    echo "⬇️  Downloading $REPO ($BRANCH)..."
    $CURL -Ls "https://github.com/$REPO/archive/refs/heads/$BRANCH.zip" -o "$ZIP"

    echo "📦 Extracting..."
    $RM -rf "$TMP"
    $UNZIP -q "$ZIP" -d "$TMP"

    echo "$TMP/${NAME}-${BRANCH}"
}

###############################################
# Sync Blueprints
###############################################
sync_blueprints() {
    echo ""
    echo "📁 Syncing Blueprints (.yaml only)"

    SRC=$(extract_repo "$REPO_BLUEPRINTS")
    $MKDIR -p "$DIR_BLUEPRINTS"

    # Clean old YAMLs
    find "$DIR_BLUEPRINTS" -type f -name "*.yaml" -delete || true

    find "$SRC" -type f -name "*.yaml" -exec $CP {} "$DIR_BLUEPRINTS" \;

    echo "✅ Blueprints updated."
}

###############################################
# Generic directory sync (copy all)
###############################################
sync_all_files() {
    local REPO="$1"
    local TARGET="$2"

    echo ""
    echo "📁 Syncing: $REPO → $TARGET"

    SRC=$(extract_repo "$REPO")

    $RM -rf "$TARGET"
    $MKDIR -p "$TARGET"

    $CP -r "$SRC"/* "$TARGET"/

    echo "✅ Synced $REPO"
}

###############################################
# Sync Integration
###############################################
sync_integration() {
    local REPO="$1"
    local NAME="$2"
    local TARGET_DIR="$3"

    echo ""
    echo "📁 Syncing Integration: $NAME (repo: $REPO)"

    SRC=$(extract_repo "$REPO")
    SRC="$SRC/custom_components/$NAME"

    if [ ! -d "$SRC" ]; then
        echo -e "${RED}❌ Integration folder missing: $SRC${RESET}"
        exit 1
    fi

    echo "🗑️  Removing old integration"
    $RM -rf "$TARGET_DIR"

    echo "📦 Installing new files"
    $MKDIR -p "$(dirname "$TARGET_DIR")"
    $CP -r "$SRC" "$TARGET_DIR"

    echo "✅ Integration updated: $NAME"
}

###############################################
# Sync dist (loader + elements)
###############################################
sync_dist() {
    local REPO="$1"
    local TARGET="$2"

    echo ""
    echo "📁 Syncing dist for $REPO"

    SRC=$(extract_repo "$REPO")
    SRC="$SRC/dist"

    if [ ! -d "$SRC" ]; then
        echo -e "${RED}❌ ERROR: dist folder missing in $REPO${RESET}"
        exit 1
    fi

    $RM -rf "$TARGET"
    $MKDIR -p "$TARGET"
    $CP -r "$SRC"/* "$TARGET"/

    echo "💨 Generating .gz versions..."
    for JSFILE in "$TARGET"/*.js; do
        [ -f "$JSFILE" ] && $GZIP -c "$JSFILE" > "${JSFILE}.gz"
    done

    echo "✅ dist updated for $REPO"
}

###############################################
# EXECUTE SYNC
###############################################
sync_blueprints
sync_all_files "$REPO_MEDIA" "$DIR_MEDIA"
sync_all_files "$REPO_ESSENTIALS" "$DIR_ESSENTIALS"

sync_integration "$REPO_UTILITIES" "smartqasa" "$DIR_UTILITIES"
sync_integration "$REPO_PICO_LINK" "pico_link" "$DIR_PICO_LINK"

sync_dist "$REPO_LOADER" "$DIR_LOADER"
sync_dist "$REPO_ELEMENTS" "$DIR_ELEMENTS"

echo ""
echo -e "${GREEN}====================================="
echo " 🎉 SmartQasa Sync COMPLETE!"
echo "=====================================${RESET}"
