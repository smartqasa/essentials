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
# HACS-STYLE DIST DOWNLOADER FOR loader/elements
########################################
download_folder() {
    REPO="$1"        # e.g. smartqasa/dash-loader
    SRC_FOLDER="$2"  # "dist"
    DEST_FOLDER="$3" # e.g. www/smartqasa/dash-loader

    API="https://api.github.com/repos/$REPO/contents/$SRC_FOLDER"

    echo ""
    echo "📡 Fetching file list: $API"

    $MKDIR -p "$DEST_FOLDER"

    $CURL -s "$API" | $JQ -c '.[]' | while read -r ITEM; do
        TYPE=$(echo "$ITEM" | $JQ -r '.type')
        NAME=$(echo "$ITEM" | $JQ -r '.name')
        URL=$(echo "$ITEM" | $JQ -r '.download_url')
        PATH=$(echo "$ITEM" | $JQ -r '.path')

        if [ "$TYPE" = "file" ]; then
            echo "⬇️  Downloading: $NAME"
            $CURL -sL "$URL" -o "$DEST_FOLDER/$NAME"
        elif [ "$TYPE" = "dir" ]; then
            echo "📁 Entering folder: $NAME"
            $MKDIR -p "$DEST_FOLDER/$NAME"
            download_folder "$REPO" "$PATH" "$DEST_FOLDER/$NAME"
        fi
    done
}

########################################
# DIST-ONLY repos
########################################
echo ""
echo "🚀 Updating dist folders (HACS-style)..."

download_folder "smartqasa/dash-loader"   "dist" "www/smartqasa/dash-loader"
download_folder "smartqasa/dash-elements" "dist" "www/smartqasa/dash-elements"

echo ""
echo "====================================="
echo "  🎉 ALL UPDATES COMPLETE!"
echo "====================================="
