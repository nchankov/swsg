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
CSS="${CSS:-}"

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

            article_list+="<li style='margin-bottom:20px;'>"
            [ -n "$rel_path" ] && article_list+="<img src=\"$rel_path\" alt=\"$(echo "$title" | sed 's/&amp;/\&/g')\">"
            article_list+="<a href=\"$(basename "$file")\">$title</a>"
            [ -n "$excerpt" ] && article_list+="<p>$excerpt</p>"
            article_list+="</li>"
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
        content_body="<ul style='list-style:none;padding:0;'>$article_list</ul>$pagination"

        # Use INDEX_TEMPLATE if available, otherwise fallback to simple HTML
        if [ -f "$INDEX_TEMPLATE" ]; then
            # Use file-based replacement to handle special characters properly
            cp "$INDEX_TEMPLATE" "$index_file"
            
            # Replace variables one by one using temporary files
            sed -i "s/\$title/Articles - Page $page/g" "$index_file"
            sed -i "s|\$CSS|$CSS|g" "$index_file"
            sed -i "s/\$page/$page/g" "$index_file"
            
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
