#!/bin/bash
# convert-md-to-html-with-featured.sh

# current dir
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Source the shared environment loader
source "$DIR/lib/env-loader.sh"

# Parse command line arguments and load environment
PROJECT_DIR=$(parse_project_args "$@")
load_env_with_fallback "$PROJECT_DIR" "$DIR"

INPUT_DIR="${INPUT_DIR:-$DIR/src}"
OUTPUT_DIR="${OUTPUT_DIR:-$DIR/dist}"
PAGE_TEMPLATE="${PAGE_TEMPLATE:-$DIR/templates/page.html}"
CSS="${CSS:-}"

mkdir -p "$OUTPUT_DIR"

find "$INPUT_DIR" -type f -name "*.md" | while read -r file; do
    rel_path="${file#$INPUT_DIR/}"
    output_path="$OUTPUT_DIR/${rel_path%.md}.html"
    mkdir -p "$(dirname "$output_path")"

    # Extract featured image: Only from YAML metadata (no fallback)
    featured=$(grep -oP '^featured:\s*\K.*' "$file" | head -n1)
    
    echo "📝 Converting: $file → $output_path (featured: $featured)"

    pandoc_cmd=(pandoc "$file" -f markdown -t html -s -o "$output_path")
    [ -f "$PAGE_TEMPLATE" ] && pandoc_cmd+=(--template="$PAGE_TEMPLATE")
    [ -n "$CSS" ] && pandoc_cmd+=(-c "$CSS")
    # Only add featured metadata if it actually exists in the file
    [ -n "$featured" ] && pandoc_cmd+=(--metadata featured="$featured")
    "${pandoc_cmd[@]}"
done

echo "✅ Markdown conversion complete!"
