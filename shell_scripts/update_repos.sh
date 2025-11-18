#!/bin/bash

########################################
# Move to /config
########################################
cd /config || { echo "❌ Failed to change directory to /config"; exit 1; }

echo ""
echo "====================================="
echo "  🔧 SmartQasa Submodule + Dist Sync  "
echo "====================================="
echo ""

########################################
# Make sure smartqasa/ exists (normal folder)
########################################
mkdir -p smartqasa
mkdir -p www/smartqasa/dash-loader
mkdir -p www/smartqasa/dash-elements

########################################
# REAL SUBMODULES (Git-managed)
########################################
declare -A SUBMODULES=(
    ["https://github.com/smartqasa/blueprints.git"]="blueprints/automation/smartqasa"
    ["https://github.com/smartqasa/essentials.git"]="smartqasa/essentials"
    ["https://github.com/smartqasa/media.git"]="www/smartqasa/media"
)

echo "📌 Checking submodules..."
for REPO in "${!SUBMODULES[@]}"; do
    DEST="${SUBMODULES[$REPO]}"

    if ! git config --file .gitmodules --get-regexp path | grep -q "^$DEST$"; then
        echo "⚠️  Submodule missing: $DEST — fixing..."

        git submodule deinit -f "$DEST" 2>/dev/null || true
        git rm -f "$DEST" 2>/dev/null || true
        rm -rf ".git/modules/$DEST" "$DEST"

        git submodule add "$REPO" "$DEST"
        echo "✅ Added: $DEST"
    fi
done

########################################
# Update actual git submodules
########################################
echo ""
echo "🔄 Updating submodules..."
git submodule update --remote --recursive --force
echo "✅ Submodules updated."


########################################
# HACS-STYLE DIST UPDATER (NO GIT)
########################################

download_folder() {
    REPO="$1"        # e.g. smartqasa/dash-loader
    SRC_FOLDER="$2"  # e.g. dist
    DEST_FOLDER="$3" # e.g. www/smartqasa/dash-loader

    API="https://api.github.com/repos/$REPO/contents/$SRC_FOLDER"

    echo ""
    echo "📡 Fetching file list from: $API"

    mkdir -p "$DEST_FOLDER"

    curl -s "$API" | jq -c '.[]' | while read -r ITEM; do
        TYPE=$(echo "$ITEM" | jq -r '.type')
        NAME=$(echo "$ITEM" | jq -r '.name')
        DOWNLOAD=$(echo "$ITEM" | jq -r '.download_url')
        PATH=$(echo "$ITEM" | jq -r '.path')

        if [ "$TYPE" = "file" ]; then
            echo "⬇️  Downloading: $NAME"
            curl -sL "$DOWNLOAD" -o "$DEST_FOLDER/$NAME"
        elif [ "$TYPE" = "dir" ]; then
            echo "📁 Entering directory: $NAME"
            mkdir -p "$DEST_FOLDER/$NAME"
            download_folder "$REPO" "$PATH" "$DEST_FOLDER/$NAME"
        fi
    done
}

########################################
# DIST-ONLY REPOS (loader & elements)
########################################

echo ""
echo "🚀 Updating dist folders (HACS-style)..."

# dash-loader
download_folder "smartqasa/dash-loader" "dist" "www/smartqasa/dash-loader"

# dash-elements
download_folder "smartqasa/dash-elements" "dist" "www/smartqasa/dash-elements"

echo ""
echo "====================================="
echo "  🎉 All updates complete!"
echo "====================================="
