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

# Targets
DIR_BLUEPRINTS="$ROOT/blueprints/automation/smartqasa"
DIR_MEDIA="$ROOT/www/smartqasa/media"
DIR_ESSENTIALS="$ROOT/smartqasa"
DIR_LOADER="$ROOT/www/smartqasa/dash-loader"
DIR_ELEMENTS="$ROOT/www/smartqasa/dash-elements"

TMP="/tmp/sq_extract"

###############################################
# Read update channel (main | beta)
###############################################
CHANNEL_FILE="$ROOT/channel.txt"
UPDATE_CHANNEL="main"   # <-- DEFAULT

if [ -f "$CHANNEL_FILE" ]; then
    CONTENT=$(cat "$CHANNEL_FILE" | tr -d '[:space:]' | tr 'A-Z' 'a-z')
    if [ "$CONTENT" = "beta" ]; then
        UPDATE_CHANNEL="beta"
    fi
fi

###############################################
# Utility: download & extract repo ZIP
###############################################
extract_repo() {
    local REPO="$1"
    local ZIP="/tmp/$(basename "$REPO").zip"

    # Determine branch → main or beta
    local BRANCH="$UPDATE_CHANNEL"

    echo "⬇️ Downloading $REPO ($BRANCH branch)..."
    $CURL -Ls "https://github.com/$REPO/archive/refs/heads/$BRANCH.zip" -o "$ZIP"

    echo "📦 Extracting ($BRANCH)..."
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
    echo "📁 Syncing Media (all files)"
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
    echo "📁 Syncing Essentials (all files)"
    extract_repo "$REPO_ESSENTIALS"

    $RM -rf "$DIR_ESSENTIALS"
    $MKDIR -p "$DIR_ESSENTIALS"

    SRC="$TMP/essentials-main"
    $CP -r "$SRC"/* "$DIR_ESSENTIALS"/

    echo "✅ Essentials updated."
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

    if [ ! -d "$SRC" ]; then
        echo "❌ ERROR: dist folder missing in $REPO"
        exit 1
    fi

    # Clean target
    $RM -rf "$TARGET"
    $MKDIR -p "$TARGET"

    # Copy dist folder
    $CP -r "$SRC"/* "$TARGET"/

    echo "💨 Generating .gz compressed JS files (HACS-style)..."

    for JSFILE in "$TARGET"/*.js; do
        if [ -f "$JSFILE" ]; then
            GZFILE="${JSFILE}.gz"
            echo "⬆️  $JSFILE → $GZFILE"
            gzip -c "$JSFILE" > "$GZFILE"
        fi
    done

    echo "✅ dist updated for $REPO (with gzip)"
}

###############################################
# EXECUTE SYNC
###############################################
echo ""
echo "====================================="
echo "   🚀 SmartQasa Sync Starting"
echo "====================================="

echo "🔍 Update channel selected: $UPDATE_CHANNEL"

sync_blueprints
sync_media
sync_essentials
sync_dist "$REPO_LOADER" "$DIR_LOADER"
sync_dist "$REPO_ELEMENTS" "$DIR_ELEMENTS"

echo ""
echo "====================================="
echo "   🎉 SmartQasa Sync COMPLETE!"
echo "====================================="
