#!/bin/bash
# generate index pages with correct relative paths for featured images

# current dir
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Source the shared environment loader
source "$DIR/lib/env-loader.sh"

# Parse command line arguments and load environment
PROJECT_DIR=$(parse_project_args "$@")
load_env_with_fallback "$PROJECT_DIR" "$DIR"

OUTPUT_DIR="${OUTPUT_DIR:-$DIR/dist}"
# Convert relative path to absolute and resolve symlinks
if [[ "$OUTPUT_DIR" == ./* ]]; then
    OUTPUT_DIR="$DIR/${OUTPUT_DIR#./}"
fi
# Resolve symlinks to get the actual path
if [ -L "$OUTPUT_DIR" ]; then
    OUTPUT_DIR=$(readlink -f "$OUTPUT_DIR")
fi
ITEMS_PER_PAGE="${ITEMS_PER_PAGE:-10}"
INDEX_TEMPLATE="${INDEX_TEMPLATE:-$DIR/templates/index.html}"
ARTICLE_TEMPLATE="${ARTICLE_TEMPLATE:-$DIR/templates/article.html}"
CSS="${CSS:-}"

# Function to render article using template
render_article() {
    local title="$1"
    local file_path="$2"
    local featured_img="$3"
    local excerpt="$4"
    local current_year=$(date +%Y)
    
    if [ -f "$ARTICLE_TEMPLATE" ]; then
        # Use article template
        local article_html
        article_html=$(cat "$ARTICLE_TEMPLATE")
        
        # Handle featured image conditionally
        local featured_style=""
        if [ -z "$featured_img" ]; then
            featured_style="display:none;"
            featured_img=""
        fi
        
        # Handle excerpt conditionally  
        local excerpt_display="$excerpt"
        if [ -z "$excerpt" ]; then
            excerpt_display=""
        fi
        
        # Use a Python one-liner for safe string replacement
        article_html=$(python3 -c "
import sys
template = '''$article_html'''
title = '''$title'''
link = '''$(basename "$file_path")'''
featured = '''$featured_img'''
featured_style = '''$featured_style'''
excerpt = '''$excerpt_display'''
year = '''$current_year'''

result = template.replace('\$title', title)
result = result.replace('\$link', link)
result = result.replace('\$featured', featured)
result = result.replace('\$featured_style', featured_style)
result = result.replace('\$excerpt', excerpt)
result = result.replace('\$year', year)

print(result, end='')
")
        
        echo "$article_html"
    else
        # Fallback to inline HTML
        local article_html="<li style='margin-bottom:20px;'>"
        [ -n "$featured_img" ] && article_html+="<img src=\"$featured_img\" alt=\"$(echo "$title" | sed 's/&amp;/\&/g')\">"
        article_html+="<a href=\"$(basename "$file_path")\">$title</a>"
        [ -n "$excerpt" ] && article_html+="<p>$excerpt</p>"
        article_html+="</li>"
        echo "$article_html"
    fi
}

# Process each directory containing HTML files
find "$OUTPUT_DIR" -type f -name "*.html" ! -name "index*.html" \
    -exec dirname {} \; | sort -u | while read -r dir; do

    echo "📂 Generating index for $dir"

    mapfile -t files < <(find "$dir" -maxdepth 1 -type f -name "*.html" ! -name "index*.html" | sort)
    total_files=${#files[@]}
    total_pages=$(( (total_files + ITEMS_PER_PAGE - 1) / ITEMS_PER_PAGE ))

    for ((page=1; page<=total_pages; page++)); do
        start=$(( (page - 1) * ITEMS_PER_PAGE ))
        end=$(( start + ITEMS_PER_PAGE - 1 ))
        index_file="$dir/index${page}.html"
        [ $page -eq 1 ] && index_file="$dir/index.html"

        # Generate article list content
        article_list=""
        first_excerpt=""
        for ((i=start; i<=end && i<total_files; i++)); do
            file="${files[$i]}"
            # Extract title from HTML <title> tag, fallback to filename
            title=$(grep -oP '(?<=<title>)[^<]+' "$file" | head -n1)
            [ -z "$title" ] && title=$(basename "$file" .html)

            # Extract featured image from HTML only if it's within the featured image section
            # Look for images that appear right after the <body> tag and before <header>
            featured=$(sed -n '/<body>/,/<header>/p' "$file" | grep -oP '(?<=<img src=")[^"]+' | head -n1)
            rel_path=""

            # Compute relative path from index page to featured image
            if [ -n "$featured" ]; then
                # Path of the HTML page containing the image
                html_dir=$(dirname "$file")
                rel_path=$(realpath --relative-to="$dir" "$html_dir/$featured")
            fi

            # Extract excerpt from the first paragraph in <main> section
            excerpt=$(sed -n '/<main>/,/<\/main>/p' "$file" | grep -oP '(?<=<p>)[^<]+' | head -n1 | cut -c1-150)
            [ ${#excerpt} -gt 147 ] && excerpt="${excerpt}..."

            # Capture the first article's excerpt for meta description (first article on each page)
            if [ $i -eq $start ] && [ -n "$excerpt" ]; then
                first_excerpt="$excerpt"
            fi

            # Render article using template or fallback
            article_html=$(render_article "$title" "$file" "$rel_path" "$excerpt")
            article_list+="$article_html"
        done

        # Generate pagination links
        pagination=""
        pagination+="<nav style='margin-top:20px;'>"
        if (( page > 1 )); then
            prev=$((page - 1))
            prev_link="index${prev}.html"
            [ $prev -eq 1 ] && prev_link="index.html"
            pagination+="<a href=\"$prev_link\">Previous</a>"
        fi
        pagination+=" Page $page of $total_pages "
        if (( page < total_pages )); then
            next=$((page + 1))
            pagination+="<a href=\"index${next}.html\">Next</a>"
        fi
        pagination+="</nav>"

        # Generate the complete content body
        if [ -f "$ARTICLE_TEMPLATE" ]; then
            # When using article template, don't wrap in ul/li - let template handle structure
            content_body="$article_list$pagination"
        else
            # Fallback: wrap in list for backward compatibility
            content_body="<ul style='list-style:none;padding:0;'>$article_list</ul>$pagination"
        fi

        # Use INDEX_TEMPLATE if available, otherwise fallback to simple HTML
        if [ -f "$INDEX_TEMPLATE" ]; then
            # Get current year for template replacement
            current_year=$(date +%Y)
            
            # Use file-based replacement to handle special characters properly
            cp "$INDEX_TEMPLATE" "$index_file"
            
            # Replace variables one by one using temporary files
            sed -i "s/\$title/Articles - Page $page/g" "$index_file"
            sed -i "s|\$CSS|$CSS|g" "$index_file"
            sed -i "s/\$page/$page/g" "$index_file"
            sed -i "s/\$year/$current_year/g" "$index_file"
            
            # Handle first_excerpt - escape special characters for sed
            if [ -n "$first_excerpt" ]; then
                # Escape special characters for sed
                escaped_excerpt=$(echo "$first_excerpt" | sed 's/[[\.*^$()+?{|]/\\&/g' | sed 's/&/\\&/g')
                sed -i "s|\$first_excerpt|$escaped_excerpt|g" "$index_file"
            else
                sed -i "s/\$first_excerpt//g" "$index_file"
            fi
            
            # Handle body content with temporary file to avoid sed special character issues
            echo "$content_body" > "${index_file}.body"
            sed -i "/\$body/r ${index_file}.body" "$index_file"
            sed -i "/\$body/d" "$index_file"
            rm -f "${index_file}.body"
        else
            # Fallback to simple HTML generation
            {
                echo "<!DOCTYPE html><html><head><meta charset='utf-8'><title>Articles - Page $page</title><link rel='stylesheet' href='$CSS'></head><body><h1>Articles - Page $page</h1>"
                echo "$content_body"
                echo "</body></html>"
            } > "$index_file"
        fi
    done
done

echo "✅ Directory indexes generated with featured images (relative paths corrected)!"
