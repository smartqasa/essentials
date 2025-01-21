#!/bin/bash
# Navigate to the config directory
cd /config

# Update the submodules
git submodule update --remote --recursive

# Call the Home Assistant "Refresh All YAML" service  TEST
curl -X POST \
    -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI0NDdjN2U3ZmJkNzM0YzFjOGI2MWYyYTM2ZGE5MjU4NyIsImlhdCI6MTczNzQ2ODM0MywiZXhwIjoyMDUyODI4MzQzfQ.rjn6HGsvGbsB3lEMol0B1jGdxDuUZ56bE3m3kyhDo2I" \
    -H "Content-Type: application/json" \
    http://192.168.75.10:10075/api/services/homeassistant/reload_core_config
