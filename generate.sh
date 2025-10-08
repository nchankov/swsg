#!/bin/bash

# current dir
SWSG_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Source the shared environment loader
source "$SWSG_DIR/lib/env-loader.sh"

# Parse command line arguments
PROJECT_DIR=$(parse_project_args "$@")

# Check if project parameter was provided
if [ -z "$PROJECT_DIR" ]; then
    echo "Usage: $0 --project <project_directory>"
    echo "Example: $0 --project /path/to/my-website"
    exit 1
fi

# Load environment from project directory
load_project_env "$PROJECT_DIR"

#execute
$SWSG_DIR/generate-assets.sh --project "$PROJECT_DIR"
$SWSG_DIR/generate-pages.sh --project "$PROJECT_DIR"
$SWSG_DIR/generate-index.sh --project "$PROJECT_DIR"
$SWSG_DIR/generate-sitemap.sh --project "$PROJECT_DIR"
