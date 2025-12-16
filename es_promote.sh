#!/bin/bash
set -e

echo "Promoting beta → main for smartqasa/essentials..."

# Ensure no dirty working tree
if [[ -n "$(git status --porcelain)" ]]; then
    echo "ERROR: Working tree not clean. Commit or stash changes first."
    exit 1
fi

# Fetch latest
echo "Fetching latest from origin..."
git fetch origin

# Switch to main
echo "Checking out main..."
git checkout main

# Make main identical to beta
echo "Resetting main to origin/beta..."
git reset --hard origin/beta

# Push updated main
echo "Pushing updated main to origin..."
git push --force origin main

# Switch back to beta
echo "Switching back to beta..."
git checkout beta

echo "✓ Promotion complete. You are now back on beta."

