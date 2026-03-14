#!/usr/bin/env bash
# create_gamecube_json.sh
# Creates Nintendo GameCube games JSON from Named_Boxarts folder only
# Excludes symlinks (aliases)

set -e  # Exit on error

# Configuration
OUTPUT_JSON="gamecube_games_dolphin.json"
BOXARTS_DIR="Named_Boxarts"
PLACEHOLDER_IMAGE="https://raw.githubusercontent.com/igiteam/gamecube-covers/refs/heads/master/gamecube-cover-default.png"
RAW_BASE_URL="https://raw.githubusercontent.com/igiteam/gamecube-covers/refs/heads/master/Named_Boxarts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "📀 Nintendo GameCube JSON Generator"
echo "=================================="

# Check if directory exists
if [ ! -d "$BOXARTS_DIR" ]; then
    echo -e "${RED}❌ Error: $BOXARTS_DIR directory not found!${NC}"
    echo "Please run this script in the same directory as your Named_Boxarts folder"
    exit 1
fi

# Count total files (including symlinks)
total_files=$(find "$BOXARTS_DIR" -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) | wc -l)
# Count symlinks
symlink_files=$(find "$BOXARTS_DIR" -maxdepth 1 -type l \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) | wc -l)
real_files=$((total_files - symlink_files))

echo -e "${GREEN}📁 Found $total_files total images in $BOXARTS_DIR${NC}"
echo -e "${YELLOW}   - $real_files real files${NC}"
echo -e "${YELLOW}   - $symlink_files symlinks (aliases) - will be excluded${NC}"

if [ $real_files -eq 0 ]; then
    echo -e "${RED}❌ No real image files found in $BOXARTS_DIR${NC}"
    exit 1
fi

# Start JSON array
echo "[" > "$OUTPUT_JSON"

# Process each REAL image file (not symlinks)
first_file=true
count=0
skipped=0

# Process only real files (not symlinks) in sorted order
find "$BOXARTS_DIR" -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -not -type l | sort | while read -r file; do
    # Get filename without path
    filename=$(basename "$file")
    
    # Remove extension to get clean title
    # First remove extension
    title=$(echo "$filename" | sed -E 's/\.[^.]*$//')
    
    # Remove region in parentheses at the end (Europe), (USA), etc.
    title=$(echo "$title" | sed -E 's/ \([^)]+\)$//')
    
    # URL encode the filename for GitHub raw URL
    # This handles spaces and special characters properly
    encoded_filename=$(printf '%s' "$filename" | jq -sRr @uri 2>/dev/null || \
                       echo "$filename" | sed 's/ /%20/g' | sed 's/\[/%5B/g' | sed 's/\]/%5D/g' | sed 's/(/%28/g' | sed 's/)/%29/g' | sed 's/#/%23/g' | sed 's/&/%26/g' | sed 's/+/%2B/g')
    
    cover_url="${RAW_BASE_URL}/${encoded_filename}"
    
    # Add comma if not first file
    if [ "$first_file" = true ]; then
        first_file=false
    else
        echo "," >> "$OUTPUT_JSON"
    fi
    
    # Escape double quotes in title
    title_escaped=$(echo "$title" | sed 's/"/\\"/g')
    
    # Write JSON entry
    cat >> "$OUTPUT_JSON" <<EOF
  {
    "title": "$title_escaped",
    "cover_url": "$cover_url",
    "filename": "$filename"
  }
EOF
    
    # Progress indicator
    count=$((count + 1))
    if [ $((count % 50)) -eq 0 ]; then
        echo -e "${YELLOW}⏳ Processed $count/$real_files real files...${NC}"
    fi
done

# Close JSON array
echo "" >> "$OUTPUT_JSON"
echo "]" >> "$OUTPUT_JSON"

# Validate JSON if jq is available
if command -v jq &> /dev/null; then
    if jq empty "$OUTPUT_JSON" 2>/dev/null; then
        echo -e "${GREEN}✅ JSON is valid${NC}"
        
        # Show some stats
        total=$(jq length "$OUTPUT_JSON")
        echo -e "${GREEN}📊 Total games in JSON: $total${NC}"
        echo -e "${YELLOW}   (excluded $symlink_files symlinks)${NC}"
        
        # Show first 3 entries as sample
        echo -e "\n${YELLOW}📋 Sample entries:${NC}"
        jq '.[:3] | map({title: .title, filename: .filename})' "$OUTPUT_JSON"
    else
        echo -e "${RED}❌ JSON validation failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  jq not installed, skipping validation${NC}"
    echo -e "${GREEN}📊 Total games: $count (excluded $skipped symlinks)${NC}"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Successfully created $OUTPUT_JSON${NC}"
echo -e "${YELLOW}📝 File size: $(du -h "$OUTPUT_JSON" | cut -f1)${NC}"