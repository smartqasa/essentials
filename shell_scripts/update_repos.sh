#!/bin/bash

# Set the working directory to /config
cd /config || { echo "❌ Failed to change directory to /config"; exit 1; }

# Declare submodules with their repository and expected destination directory
declare -A SUBMODULES=(
    ["https://github.com/smartqasa/blueprints.git"]="blueprints/automation/smartqasa"
    ["https://github.com/smartqasa/essentials.git"]="smartqasa"
    ["https://github.com/smartqasa/dash-loader.git"]="www/smartqasa/dash-loader"
    ["https://github.com/smartqasa/dash-elements.git"]="www/smartqasa/dash-elements"
    ["https://github.com/smartqasa/media.git"]="www/smartqasa/media"
)

# Ensure each submodule is present
for REPO in "${!SUBMODULES[@]}"; do
    DEST="${SUBMODULES[$REPO]}"

    # Check if the submodule is correctly registered in .gitmodules
    if ! git config --file .gitmodules --get-regexp path | grep -q "$DEST"; then
        echo "⚠️  Warning: Submodule $DEST is not registered in .gitmodules. Fixing it..."

        # Fully remove submodule traces before re-adding
        git submodule deinit -f "$DEST" 2>/dev/null || true
        git rm -f "$DEST" 2>/dev/null || true
        rm -rf ".git/modules/$DEST" 2>/dev/null || true
        rm -rf "$DEST"

        echo "✅ Cleaned up submodule: $DEST"

        # Re-add the submodule
        echo "➕ Adding submodule: $REPO -> $DEST"
        git submodule add --force "$REPO" "$DEST"
    fi
done

# Run update ONCE after adding missing submodules
echo "🔄 Updating submodules..."
git submodule update --remote --recursive --force

echo "✅ Submodules successfully updated."
