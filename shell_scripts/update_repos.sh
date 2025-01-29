# Set the working directory to /config
cd /config || { echo "Failed to change directory to /config"; exit 1; }

# Update the submodules
git submodule update --remote --recursive --force


# Declare submodules with their repository and expected destination directory
declare -A SUBMODULES=(
    ["https://github.com/smartqasa/blueprints.git"]="/config/blueprints/automations/smartqasa"
    ["https://github.com/smartqasa/essentials.git"]="/config/essentials"
    ["https://github.com/smartqasa/backgrounds.git"]="/config/www/smartqasa/backgrounds"
)

# Ensure each submodule is present
for REPO in "${!SUBMODULES[@]}"; do
    DEST="${SUBMODULES[$REPO]}"
    
    if [ ! -d "$DEST/.git" ]; then
        echo "Submodule at $DEST is missing. Adding it..."
        git submodule add --force "$REPO" "$DEST"
    fi
done

# Initialize and update all submodules
git submodule init
git submodule update --remote --recursive --force
