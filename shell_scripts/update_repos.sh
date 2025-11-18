#!/bin/bash

cd /config || { echo "❌ Failed to change directory to /config"; exit 1; }

#----------------------------------------
# Ensure required folders exist
#----------------------------------------
mkdir -p smartqasa
mkdir -p www/smartqasa/dash-loader
mkdir -p www/smartqasa/dash-elements

#----------------------------------------
# True Submodules (allowed)
#----------------------------------------
declare -A SUBMODULES=(
    ["https://github.com/smartqasa/blueprints.git"]="blueprints/automation/smartqasa"
    ["https://github.com/smartqasa/essentials.git"]="smartqasa/essentials"
    ["https://github.com/smartqasa/media.git"]="www/smartqasa/media"
)

echo "📌 Checking real submodules..."
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

#----------------------------------------
# Update proper submodules
#----------------------------------------
echo "🔄 Updating true submodules..."
git submodule update --remote --recursive --force


#----------------------------------------
# DIST-ONLY repos (NO submodules)
#----------------------------------------
echo "📦 Updating dist-only repositories..."

TEMP_DIR="/tmp/sq-update"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# dash-loader
echo "⬇️  Fetching dash-loader dist..."
git clone --depth=1 https://github.com/smartqasa/dash-loader.git "$TEMP_DIR/dash-loader"
rm -rf www/smartqasa/dash-loader/dist
cp -r "$TEMP_DIR/dash-loader/dist" www/smartqasa/dash-loader/

# dash-elements
echo "⬇️  Fetching dash-elements dist..."
git clone --depth=1 https://github.com/smartqasa/dash-elements.git "$TEMP_DIR/dash-elements"
rm -rf www/smartqasa/dash-elements/dist
cp -r "$TEMP_DIR/dash-elements/dist" www/smartqasa/dash-elements/

echo "🧹 Cleaning temp files..."
rm -rf "$TEMP_DIR"

echo "✅ Dist folders updated."
echo "🎉 All updates complete."
