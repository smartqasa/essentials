#!/bin/bash

# Set the working directory to /config
cd /config || { echo "❌ Failed to change directory to /config"; exit 1; }

echo "🔄 Checking and ensuring submodules (blueprints, essentials, backgrounds) are in place..."

# Declare submodules with their repository and expected destination directory
declare -A SUBMODULES=(
    ["https://github.com/smartqasa/blueprints.git"]="blueprints/automations/smartqasa"
    ["https://github.com/smartqasa/essentials.git"]="essentials"
    ["https://github.com/smartqasa/backgrounds.git"]="www/smartqasa/backgrounds"
)

# Ensure each submodule is present
for REPO in "${!SUBMODULES[@]}"; do
    DEST="${SUBMODULES[$REPO]}"

    # Check if the directory exists but is not a Git repository
    if [ -d "$DEST" ] && [ ! -d "$DEST/.git" ]; then
        echo "⚠️  Warning: Directory $DEST already exists but is not a Git repo. Removing it..."
        
        # Fully remove the submodule from Git's tracking system
        git submodule deinit -f "$DEST" 2>/dev/null || true
        git rm -f "$DEST" 2>/dev/null || true
        rm -rf ".git/modules/$DEST" 2>/dev/null || true
        rm -rf "$DEST"

        echo "✅ Cleaned up submodule: $DEST"
    fi

    # Add the submodule if it's missing
    if [ ! -d "$DEST/.git" ]; then
        echo "➕ Adding submodule: $REPO -> $DEST"
        git submodule add --force "$REPO" "$DEST"
    fi
done

# Run update ONCE after adding missing submodules
echo "🔄 Updating submodules..."
git submodule update --remote --recursive --force

echo "✅ Submodules successfully updated."
