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

###############################################
# Repo → Local Path Map
###############################################
ROOT="/config"

# Repos
REPO_BLUEPRINTS="smartqasa/blueprints"
REPO_MEDIA="smartqasa/media"
REPO_ESSENTIALS="smartqasa/essentials"
REPO_LOADER="smartqasa/dash-loader"
REPO_ELEMENTS="smartqasa/dash-elements"
REPO_UTILITIES="smartqasa/ha-utilities"
REPO_PICO_LINK="smartqasa/pico-link"
REPO_SCENE_PLUS="smartqasa/scene-plus"

# Targets
DIR_BLUEPRINTS="$ROOT/blueprints/automation/smartqasa"
DIR_MEDIA="$ROOT/www/smartqasa/media"
DIR_ESSENTIALS="$ROOT/smartqasa"
DIR_LOADER="$ROOT/www/smartqasa/dash-loader"
DIR_ELEMENTS="$ROOT/www/smartqasa/dash-elements"
DIR_UTILITIES="$ROOT/custom_components/smartqasa"
DIR_PICO_LINK="$ROOT/custom_components/pico_link"
DIR_SCENE_PLUS="$ROOT/custom_components/scene_plus"
TMP="/tmp/sq_extract"

###############################################
# Load SmartQasa sqconfig.json
###############################################
SQCONFIG_PATH="$ROOT/sqconfig.json"
UPDATE_CHANNEL="main"
AUTO_UPDATE="true"   # default

if [ -f "$SQCONFIG_PATH" ]; then
    CHANNEL=$(jq -r '(.channel // "main")' "$SQCONFIG_PATH")
    AUTO_UPDATE=$(jq -r '(.auto_update // true) | tostring' "$SQCONFIG_PATH")

    if [ "$CHANNEL" = "beta" ]; then
        UPDATE_CHANNEL="beta"
    fi
fi

# Respect auto_update flag
if [ "$AUTO_UPDATE" != "true" ]; then
    echo ""
    echo "====================================="
    echo " ⏭️  Auto-update disabled — exiting."
    echo "====================================="
    exit 0
fi

echo ""
echo "====================================="
echo "   🚀 SmartQasa Sync Starting"
echo "====================================="
echo "📡 Update channel: $UPDATE_CHANNEL"
echo "🔧 Auto-update: $AUTO_UPDATE"

###############################################
# REPOS THAT SUPPORT BETA (UPDATED)
###############################################
repo_supports_beta() {
    case "$1" in
        smartqasa/dash-loader|smartqasa/dash-elements|smartqasa/pico-link|smartqasa/essentials)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

###############################################
# Utility: download & extract repo ZIP
###############################################
extract_repo() {
    local REPO="$1"
    local ZIP="/tmp/$(basename "$REPO").zip"

    # Determine branch
    local BRANCH="main"
    if [ "$UPDATE_CHANNEL" = "beta" ] && repo_supports_beta "$REPO"; then
        BRANCH="beta"
    fi

    echo ""
    echo "⬇️  Downloading $REPO ($BRANCH)..."
    $CURL -Ls "https://github.com/$REPO/archive/refs/heads/$BRANCH.zip" -o "$ZIP"

    echo "📦 Extracting..."
    $RM -rf "$TMP"
    $UNZIP -q "$ZIP" -d "$TMP"
}

###############################################
# BLUEPRINTS (YAML only)
###############################################
sync_blueprints() {
    echo ""
    echo "📁 Syncing Blueprints (.yaml only)"
    extract_repo "$REPO_BLUEPRINTS"

    local NAME
    NAME=$(basename "$REPO_BLUEPRINTS")
    local BRANCH="main"
    if [ "$UPDATE_CHANNEL" = "beta" ] && repo_supports_beta "$REPO_BLUEPRINTS"; then
        BRANCH="beta"
    fi

    local SRC="$TMP/${NAME}-${BRANCH}"

    $MKDIR -p "$DIR_BLUEPRINTS"
    $RM -f "$DIR_BLUEPRINTS"/*.yaml || true

    find "$SRC" -type f -name '*.yaml' -exec $CP {} "$DIR_BLUEPRINTS" \;

    echo "✅ Blueprints updated."
}

###############################################
# MEDIA (copy everything)
###############################################
sync_media() {
    echo ""
    echo "📁 Syncing Media"
    extract_repo "$REPO_MEDIA"

    local NAME
    NAME=$(basename "$REPO_MEDIA")
    local BRANCH="main"
    if [ "$UPDATE_CHANNEL" = "beta" ] && repo_supports_beta "$REPO_MEDIA"; then
        BRANCH="beta"
    fi

    local SRC="$TMP/${NAME}-${BRANCH}"

    $RM -rf "$DIR_MEDIA"
    $MKDIR -p "$DIR_MEDIA"

    $CP -r "$SRC"/* "$DIR_MEDIA"/

    echo "✅ Media updated."
}

###############################################
# ESSENTIALS (copy everything)
###############################################
sync_essentials() {
    echo ""
    echo "📁 Syncing Essentials"
    extract_repo "$REPO_ESSENTIALS"

    local NAME
    NAME=$(basename "$REPO_ESSENTIALS")
    local BRANCH="main"
    if [ "$UPDATE_CHANNEL" = "beta" ] && repo_supports_beta "$REPO_ESSENTIALS"; then
        BRANCH="beta"
    fi

    local SRC="$TMP/${NAME}-${BRANCH}"

    $RM -rf "$DIR_ESSENTIALS"
    $MKDIR -p "$DIR_ESSENTIALS"

    $CP -r "$SRC"/* "$DIR_ESSENTIALS"/

    echo "✅ Essentials updated."
}

###############################################
# Generic Integration Sync
###############################################
sync_integration() {
    local REPO="$1"
    local INTEGRATION="$2"
    local TARGET_DIR="$3"

    echo ""
    echo "📁 Syncing Integration: $INTEGRATION  (repo: $REPO)"

    extract_repo "$REPO"

    local NAME
    NAME=$(basename "$REPO")
    local BRANCH="main"
    if [ "$UPDATE_CHANNEL" = "beta" ] && repo_supports_beta "$REPO"; then
        BRANCH="beta"
        echo "🔍 Using BETA branch for integration"
    fi

    local SRC="$TMP/${NAME}-${BRANCH}/custom_components/${INTEGRATION}"

    if [ ! -d "$SRC" ]; then
        echo "❌ ERROR: integration folder not found: $SRC"
        exit 1
    fi

    echo "🗑️  Removing existing integration: $TARGET_DIR"
    $RM -rf "$TARGET_DIR"

    echo "📦 Copying new integration files..."
    $MKDIR -p "$(dirname "$TARGET_DIR")"
    $CP -r "$SRC" "$TARGET_DIR"

    echo "✅ Integration updated: $INTEGRATION"
}

###############################################
# Module (Loader & Elements)
###############################################
sync_module() {
    local REPO="$1"
    local TARGET="$2"
    local NAME
    NAME=$(basename "$REPO")

    echo ""
    echo "📁 Syncing module for $REPO"
    extract_repo "$REPO"

    local BRANCH="main"
    if [ "$UPDATE_CHANNEL" = "beta" ] && repo_supports_beta "$REPO"; then
        BRANCH="beta"
        echo "🔍 Using BETA branch"
    fi

    local SRC="$TMP/${NAME}-${BRANCH}/dist"

    if [ ! -d "$SRC" ]; then
        echo "❌ ERROR: module folder missing in $REPO ($SRC)"
        exit 1
    fi

    $RM -rf "$TARGET"
    $MKDIR -p "$TARGET"
    $CP -r "$SRC"/* "$TARGET"/

    echo "💨 Generating .gz assets..."
    for JSFILE in "$TARGET"/*.js; do
        if [ -f "$JSFILE" ]; then
            gzip -c "$JSFILE" > "${JSFILE}.gz"
        fi
    done

    echo "✅ Module updated for $REPO (with gzip)"
}

###############################################
# EXECUTE SYNC
###############################################
sync_blueprints
sync_media
sync_essentials

sync_integration "$REPO_UTILITIES" "smartqasa" "$DIR_UTILITIES"
sync_integration "$REPO_PICO_LINK" "pico_link" "$DIR_PICO_LINK"
sync_integration "$REPO_SCENE_PLUS" "scene_plus" "$DIR_SCENE_PLUS"

sync_module "$REPO_LOADER" "$DIR_LOADER"
sync_module "$REPO_ELEMENTS" "$DIR_ELEMENTS"

echo ""
echo "====================================="
echo " 🎉 SmartQasa Sync COMPLETE!"
echo "====================================="
