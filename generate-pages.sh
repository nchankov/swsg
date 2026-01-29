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
    
    # Get current year for template replacement
    current_year=$(date +%Y)
    current_date=$(date +%Y-%m-%d)
    
    # Create temporary file with year and date replacements in content
    temp_file="${file}.tmp"
    sed -e "s/{{year}}/$current_year/g" -e "s/{{date}}/$current_date/g" "$file" > "$temp_file"
    
    echo "📝 Converting: $file → $output_path (featured: $featured, year: $current_year)"

    # First, convert markdown to HTML without template
    pandoc_cmd=(pandoc "$temp_file" -f markdown -t html -o "${output_path}.body")
    "${pandoc_cmd[@]}"
    
    # Read the body content
    body_content=$(cat "${output_path}.body")
    
    # Now apply the template manually if it exists
    if [ -f "$PAGE_TEMPLATE" ]; then
        cp "$PAGE_TEMPLATE" "$output_path"
        
        # Get the title from the markdown file
        title=$(grep -oP '^title:\s*\K.*' "$file" | head -n1)
        [ -z "$title" ] && title=$(basename "$file" .md)
        
        # Get the description from the markdown file
        description=$(grep -oP '^description:\s*\K.*' "$file" | head -n1)
        
        # Escape special characters for sed (& \ and |)
        title_escaped=$(echo "$title" | sed 's/[&\|]/\\&/g')
        description_escaped=$(echo "$description" | sed 's/[&\|]/\\&/g')
        css_escaped=$(echo "$CSS" | sed 's/[&\|]/\\&/g')
        featured_escaped=$(echo "$featured" | sed 's/[&\|]/\\&/g')
        
        # Replace placeholders using sed with new {{}} syntax
        sed -i "s|{{title}}|$title_escaped|g" "$output_path"
        sed -i "s|{{description}}|$description_escaped|g" "$output_path"
        sed -i "s|{{css}}|$css_escaped|g" "$output_path"
        sed -i "s|{{date}}|$(date +%Y-%m-%d)|g" "$output_path"
        sed -i "s|{{year}}|$current_year|g" "$output_path"
        
        # Handle conditional featured image
        if [ -n "$featured" ]; then
            # Replace {{featured}} with actual path
            sed -i "s|{{featured}}|$featured_escaped|g" "$output_path"
            # Remove @if/@endif markers
            sed -i '/@if(featured)/d' "$output_path"
            sed -i '/@endif/d' "$output_path"
        else
            # Remove the entire @if(featured) block
            sed -i '/@if(featured)/,/@endif/d' "$output_path"
        fi
        
        # Insert body content
        echo "$body_content" > "${output_path}.body.tmp"
        sed -i "/{{body}}/r ${output_path}.body.tmp" "$output_path"
        sed -i "/{{body}}/d" "$output_path"
        rm -f "${output_path}.body.tmp"
    else
        # No template, just move the body to output
        mv "${output_path}.body" "$output_path"
    fi
    
    # Clean up temporary files
    rm -f "$temp_file" "${output_path}.body"
done

echo "✅ Markdown conversion complete!"
