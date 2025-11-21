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

# Targets
DIR_BLUEPRINTS="$ROOT/blueprints/automation/smartqasa"
DIR_MEDIA="$ROOT/www/smartqasa/media"
DIR_ESSENTIALS="$ROOT/smartqasa"
DIR_LOADER="$ROOT/www/smartqasa/dash-loader"
DIR_ELEMENTS="$ROOT/www/smartqasa/dash-elements"
DIR_UTILITIES="$ROOT/custom_components/smartqasa"

TMP="/tmp/sq_extract"

###############################################
# Load SmartQasa sqconfig.json
###############################################
SQCONFIG_PATH="$ROOT/sqconfig.json"
UPDATE_CHANNEL="main"
AUTO_UPDATE="true"   # default

if [ -f "$SQCONFIG_PATH" ]; then
    CHANNEL=$(jq -r '.channel // "main"' "$SQCONFIG_PATH")
    AUTO_UPDATE=$(jq -r '.auto_update // "true"' "$SQCONFIG_PATH")

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
# Only Loader & Elements support beta
###############################################
repo_supports_beta() {
    case "$1" in
        smartqasa/dash-loader|smartqasa/dash-elements)
            return 0 ;;
        *)
            return 1 ;;
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
    echo "⬇️ Downloading $REPO ($BRANCH)..."
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

    $MKDIR -p "$DIR_BLUEPRINTS"
    $RM -f "$DIR_BLUEPRINTS"/*.yaml

    SRC="$TMP/blueprints-main"
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

    $RM -rf "$DIR_MEDIA"
    $MKDIR -p "$DIR_MEDIA"

    SRC="$TMP/media-main"
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

    $RM -rf "$DIR_ESSENTIALS"
    $MKDIR -p "$DIR_ESSENTIALS"

    SRC="$TMP/essentials-main"
    $CP -r "$SRC"/* "$DIR_ESSENTIALS"/

    echo "✅ Essentials updated."
}

###############################################
# UTILITIES (custom_components/smartqasa)
###############################################
sync_utilities() {
    echo ""
    echo "📁 Syncing HA Utilities (custom_components/smartqasa)"
    extract_repo "$REPO_UTILITIES"

    SRC="$TMP/ha-utilities-main/custom_components/smartqasa"

    if [ ! -d "$SRC" ]; then
        echo "❌ ERROR: custom_components/smartqasa not found in ha-utilities repo"
        exit 1
    fi

    # Remove existing integration
    $RM -rf "$DIR_UTILITIES"
    $MKDIR -p "$(dirname "$DIR_UTILITIES")"

    # Copy integration folder
    $CP -r "$SRC" "$DIR_UTILITIES"

    echo "✅ HA Utilities updated."
}

###############################################
# DIST (Loader & Elements)
###############################################
sync_dist() {
    local REPO="$1"
    local TARGET="$2"
    local NAME=$(basename "$REPO")

    echo ""
    echo "📁 Syncing dist for $REPO"
    extract_repo "$REPO"

    SRC="$TMP/${NAME}-main/dist"
    if [ "$UPDATE_CHANNEL" = "beta" ] && repo_supports_beta "$REPO"; then
        SRC="$TMP/${NAME}-beta/dist"
        echo "🔍 Using BETA branch"
    fi

    if [ ! -d "$SRC" ]; then
        echo "❌ ERROR: dist folder missing in $REPO ($SRC)"
        exit 1
    fi

    # Clean target and copy
    $RM -rf "$TARGET"
    $MKDIR -p "$TARGET"
    $CP -r "$SRC"/* "$TARGET"/

    # Create gzip versions
    echo "💨 Generating .gz assets..."
    for JSFILE in "$TARGET"/*.js; do
        if [ -f "$JSFILE" ]; then
            gzip -c "$JSFILE" > "${JSFILE}.gz"
        fi
    done

    echo "✅ dist updated for $REPO (with gzip)"
}

###############################################
# EXECUTE SYNC
###############################################
sync_blueprints
sync_media
sync_essentials
sync_utilities
sync_dist "$REPO_LOADER" "$DIR_LOADER"
sync_dist "$REPO_ELEMENTS" "$DIR_ELEMENTS"

echo ""
echo "====================================="
echo " 🎉 SmartQasa Sync COMPLETE!"
echo "====================================="
