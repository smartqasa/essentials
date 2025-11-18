#!/bin/bash

set -e

# Absolute binaries (fixes PATH issues)
CURL="/usr/bin/curl"
JQ="/usr/bin/jq"
MKDIR="/bin/mkdir"
RM="/bin/rm"
CP="/bin/cp"
MV="/bin/mv"
GIT="/usr/bin/git"

########################################
# Move to /config
########################################
cd /config || { echo "❌ Failed to change directory to /config"; exit 1; }

echo ""
echo "====================================="
echo "  🔧 SmartQasa Sync Script"
echo "====================================="
echo ""

########################################
# Ensure smartqasa is a NORMAL folder
########################################
if [ -d ".git/modules/smartqasa" ]; then
    echo "🧹 Removing old smartqasa submodule..."
    $GIT submodule deinit -f smartqasa || true
    $GIT rm -f smartqasa || true
    $RM -rf .git/modules/smartqasa || true
    $RM -rf smartqasa || true
fi

$MKDIR -p smartqasa
$MKDIR -p www/smartqasa/dash-loader
$MKDIR -p www/smartqasa/dash-elements

########################################
# REAL SUBMODULES
########################################
declare -A SUBMODULES=(
    ["https://github.com/smartqasa/blueprints.git"]="blueprints/automation/smartqasa"
    ["https://github.com/smartqasa/essentials.git"]="smartqasa"             # <-- updated
    ["https://github.com/smartqasa/media.git"]="www/smartqasa/media"
)

echo "📌 Checking submodules..."
for REPO in "${!SUBMODULES[@]}"; do
    DEST="${SUBMODULES[$REPO]}"

    # If missing in .gitmodules → add it
    if ! $GIT config --file .gitmodules --get-regexp path | grep -q "^$DEST$"; then
        echo "⚠️  Submodule missing: $DEST — adding..."

        $GIT submodule deinit -f "$DEST" 2>/dev/null || true
        $GIT rm -f "$DEST" 2>/dev/null || true
        $RM -rf ".git/modules/$DEST" "$DEST"

        $GIT submodule add "$REPO" "$DEST"
        echo "✅ Added: $DEST"
    fi
done

echo ""
echo "🔄 Updating Git submodules..."
$GIT submodule update --remote --recursive --force
echo "✅ Submodules updated."


########################################
# DIST DOWNLOADER
########################################
copy_dist() {
    local REPO="$1"    # smartqasa/dash-loader
    local TARGET="$2"  # www/smartqasa/dash-loader

    local NAME=$(basename "$REPO")
    local ZIP="/tmp/$NAME.zip"

    echo "⬇️ Downloading $REPO..."
    curl -Ls "https://github.com/$REPO/archive/refs/heads/main.zip" -o "$ZIP"

    rm -rf /tmp/extract
    unzip -q "$ZIP" "$NAME-main/dist/*" -d /tmp/extract

    echo "📦 Copying dist/ for $REPO..."
    rm -rf "$TARGET"/*
    cp -r /tmp/extract/"$NAME-main"/dist/* "$TARGET"/
}

########################################
# DIST-ONLY repos
########################################
echo ""
echo "🚀 Updating dist folders (HACS-style)..."

copy_dist "smartqasa/dash-loader"   "/config/www/smartqasa/dash-loader"
copy_dist "smartqasa/dash-elements" "/config/www/smartqasa/dash-elements"

echo ""
echo "====================================="
echo "  🎉 ALL UPDATES COMPLETE!"
echo "====================================="
