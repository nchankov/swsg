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
  cp "$ASSETS_DIR/*" "$OUTPUT_DIR/assets/" -Rf
fi