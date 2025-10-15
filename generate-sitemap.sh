#!/bin/bash
# generate-sitemap.sh - Generate XML sitemap for all pages and index pages

# current dir
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Source the shared environment loader
source "$DIR/lib/env-loader.sh"

# Parse command line arguments and load environment
PROJECT_DIR=$(parse_project_args "$@")
load_env_with_fallback "$PROJECT_DIR" "$DIR"

OUTPUT_DIR="${OUTPUT_DIR:-$DIR/dist}"
# Resolve symlinks to get the actual path
if [ -L "$OUTPUT_DIR" ]; then
    OUTPUT_DIR=$(readlink -f "$OUTPUT_DIR")
fi
DOMAIN="${DOMAIN:-https://example.com}"
SITEMAP_FILE="${SITEMAP_FILE:-sitemap.xml}"
SITEMAP_XSL="${SITEMAP_XSL:-}"

sitemap_path="$OUTPUT_DIR/$SITEMAP_FILE"

# Start sitemap XML
{
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    # Add XSL stylesheet reference if SITEMAP_XSL is provided
    if [ -n "$SITEMAP_XSL" ]; then
        echo "<?xml-stylesheet type=\"text/xsl\" href=\"$SITEMAP_XSL\"?>"
    fi
    echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
} > "$sitemap_path"

echo "🗺️  Generating sitemap: $sitemap_path"

# Function to get last modified date of a file
get_lastmod() {
    local file="$1"
    if [ -f "$file" ]; then
        # Get file modification date in ISO 8601 format
        date -r "$file" "+%Y-%m-%dT%H:%M:%S+00:00"
    else
        # Fallback to current date
        date "+%Y-%m-%dT%H:%M:%S+00:00"
    fi
}

# Function to add URL to sitemap
add_url() {
    local url="$1"
    local file_path="$2"
    local priority="${3:-0.5}"
    local changefreq="${4:-monthly}"
    
    local lastmod=$(get_lastmod "$file_path")
    
    cat >> "$sitemap_path" << EOF
  <url>
    <loc>$DOMAIN$url</loc>
    <lastmod>$lastmod</lastmod>
    <changefreq>$changefreq</changefreq>
    <priority>$priority</priority>
  </url>
EOF
}

# Add the main domain (root)
add_url "/" "$OUTPUT_DIR/index.html" "1.0" "weekly"

# Find and add all HTML files (excluding index files for now)
find "$OUTPUT_DIR" -type f -name "*.html" ! -name "index*.html" | sort | while read -r file; do
    # Get relative path from OUTPUT_DIR
    rel_path="${file#$OUTPUT_DIR}"
    
    # Ensure path starts with /
    if [[ ! "$rel_path" =~ ^/ ]]; then
        rel_path="/$rel_path"
    fi
    
    add_url "$rel_path" "$file" "0.8" "monthly"
done

# Find and add all index files (with higher priority)
find "$OUTPUT_DIR" -type f -name "index*.html" | sort | while read -r file; do
    # Get relative path from OUTPUT_DIR
    rel_path="${file#$OUTPUT_DIR}"
    
    # Convert index.html to directory path
    if [[ "$rel_path" =~ /index\.html$ ]]; then
        # Replace /index.html with /
        rel_path="${rel_path%/index.html}/"
    elif [[ "$rel_path" =~ /index([0-9]+)\.html$ ]]; then
        # For index2.html, index3.html etc, keep as is but ensure leading /
        if [[ ! "$rel_path" =~ ^/ ]]; then
            rel_path="/$rel_path"
        fi
    elif [[ "$rel_path" == "/index.html" ]] || [[ "$rel_path" == "index.html" ]]; then
        # Skip root index.html as it's already added
        continue
    fi
    
    # Skip if it's the root path (already added)
    if [ "$rel_path" != "/" ]; then
        add_url "$rel_path" "$file" "0.9" "weekly"
    fi
done

# Close sitemap XML
cat >> "$sitemap_path" << 'EOF'
</urlset>
EOF

echo "✅ Sitemap generated: $sitemap_path"

# Show stats
total_urls=$(grep -c "<loc>" "$sitemap_path")
echo "📊 Total URLs in sitemap: $total_urls"