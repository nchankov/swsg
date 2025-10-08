#!/bin/bash

# current dir
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Source the shared environment loader
source "$DIR/lib/env-loader.sh"

# Parse command line arguments and load environment
PROJECT_DIR=$(parse_project_args "$@")
load_env_with_fallback "$PROJECT_DIR" "$DIR"

ASSETS_DIR="${ASSETS_DIR:-$DIR/src/assets}"

if [ -d "$ASSETS_DIR" ]; then
    # Create output assets directory if it doesn't exist
    mkdir -p "$OUTPUT_DIR/assets/"
    
    # Check if there are any files to copy
    if [ "$(ls -A "$ASSETS_DIR" 2>/dev/null)" ]; then
        echo "📁 Copying assets from $ASSETS_DIR to $OUTPUT_DIR/assets/"
        cp -Rf "$ASSETS_DIR"/* "$OUTPUT_DIR/assets/"
        echo "✅ Assets copied successfully!"
    else
        echo "⚠️  Assets directory is empty: $ASSETS_DIR"
    fi
else
    echo "⚠️  Assets directory does not exist: $ASSETS_DIR"
fi