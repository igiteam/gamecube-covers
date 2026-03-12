# create_gamecube_json_complete.sh
# Creates Nintendo GameCube JSON with Boxarts, Logos, Snaps, and Titles

set -e

OUTPUT_JSON="nintendo_gamecube_complete.json"
BASE_DIR="."  # Current directory where the folders are
PLACEHOLDER_IMAGE="https://raw.githubusercontent.com/igiteam/wii-covers/main/covers/wii-cover-default.png"
RAW_BASE_URL="https://raw.githubusercontent.com/igiteam/Nintendo_-_GameCube/refs/heads/master"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📀 Nintendo GameCube Complete JSON Generator${NC}"
echo "================================================"

# Define folders to process
declare -A FOLDERS=(
    ["Boxarts"]="Named_Boxarts"
    ["Logos"]="Named_Logos"
    ["Snaps"]="Named_Snaps"
    ["Titles"]="Named_Titles"
)

# Check if at least one folder exists
found_folders=0
for folder_type in "${!FOLDERS[@]}"; do
    folder_path="${FOLDERS[$folder_type]}"
    if [ -d "$folder_path" ]; then
        echo -e "${GREEN}✅ Found $folder_type folder: $folder_path${NC}"
        found_folders=$((found_folders + 1))
    else
        echo -e "${YELLOW}⚠️  $folder_type folder not found: $folder_path${NC}"
    fi
done

if [ $found_folders -eq 0 ]; then
    echo -e "${RED}❌ Error: No GameCube folders found!${NC}"
    echo "Please run this script in the directory containing:"
    echo "  - Named_Boxarts/"
    echo "  - Named_Logos/"
    echo "  - Named_Snaps/"
    echo "  - Named_Titles/"
    exit 1
fi

# Get all unique game names from Boxarts (or first available folder)
echo -e "\n${BLUE}📁 Scanning for games...${NC}"

# Determine primary folder for game list (prefer Boxarts, then others)
primary_folder=""
if [ -d "Named_Boxarts" ]; then
    primary_folder="Named_Boxarts"
elif [ -d "Named_Titles" ]; then
    primary_folder="Named_Titles"
elif [ -d "Named_Logos" ]; then
    primary_folder="Named_Logos"
elif [ -d "Named_Snaps" ]; then
    primary_folder="Named_Snaps"
fi

if [ -z "$primary_folder" ]; then
    echo -e "${RED}❌ No game folders found!${NC}"
    exit 1
fi

echo -e "${GREEN}📁 Using primary folder: $primary_folder${NC}"

# Create associative array to store all game data
declare -A game_data
declare -A game_regions

# First, collect all unique game names from the primary folder
temp_file=$(mktemp)
trap 'rm -f "$temp_file"' EXIT

find "$primary_folder" -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) | sort > "$temp_file"
total_games=$(wc -l < "$temp_file")
echo -e "${GREEN}📊 Found $total_games base games${NC}"

# Start JSON
echo "[" > "$OUTPUT_JSON"

count=0
first=true

# Process each game
while IFS= read -r file; do
    filename=$(basename "$file")
    
    # Extract base name without extension
    basename_noext=$(echo "$filename" | sed 's/\.[^.]*$//')
    
    # Extract region if present (e.g., "Game Name (Europe)")
    region="Unknown"
    if [[ "$basename_noext" =~ ^(.*)[[:space:]]*\(([^)]+)\)$ ]]; then
        clean_title="${BASH_REMATCH[1]%% }"
        region="${BASH_REMATCH[2]}"
    else
        clean_title="$basename_noext"
    fi
    
    # URL encode for GitHub raw URLs
    encoded_filename=$(printf '%s' "$filename" | jq -sRr @uri 2>/dev/null || echo "$filename" | sed 's/ /%20/g')
    
    # Build URLs for all available folders
    boxart_url="$PLACEHOLDER_IMAGE"
    logo_url="$PLACEHOLDER_IMAGE"
    snap_url="$PLACEHOLDER_IMAGE"
    title_url="$PLACEHOLDER_IMAGE"
    
    # Check each folder and add URL if file exists
    if [ -f "Named_Boxarts/$filename" ]; then
        boxart_url="${RAW_BASE_URL}/Named_Boxarts/${encoded_filename}"
    fi
    
    if [ -f "Named_Logos/$filename" ]; then
        logo_url="${RAW_BASE_URL}/Named_Logos/${encoded_filename}"
    fi
    
    if [ -f "Named_Snaps/$filename" ]; then
        snap_url="${RAW_BASE_URL}/Named_Snaps/${encoded_filename}"
    fi
    
    if [ -f "Named_Titles/$filename" ]; then
        title_url="${RAW_BASE_URL}/Named_Titles/${encoded_filename}"
    fi
    
    # Add comma if not first
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$OUTPUT_JSON"
    fi
    
    # Write JSON with all media types
    cat >> "$OUTPUT_JSON" <<EOF
  {
    "title": "$clean_title",
    "region": "$region",
    "filename": "$filename",
    "cover_url": "$boxart_url",
    "logo_url": "$logo_url",
    "snap_url": "$snap_url",
    "title_url": "$title_url",
    "has_boxart": $(if [ "$boxart_url" != "$PLACEHOLDER_IMAGE" ]; then echo "true"; else echo "false"; fi),
    "has_logo": $(if [ "$logo_url" != "$PLACEHOLDER_IMAGE" ]; then echo "true"; else echo "false"; fi),
    "has_snap": $(if [ "$snap_url" != "$PLACEHOLDER_IMAGE" ]; then echo "true"; else echo "false"; fi),
    "has_title": $(if [ "$title_url" != "$PLACEHOLDER_IMAGE" ]; then echo "true"; else echo "false"; fi)
  }
EOF
    
    count=$((count + 1))
    if [ $((count % 50)) -eq 0 ]; then
        echo -e "${YELLOW}⏳ Processed $count/$total_games games...${NC}"
    fi
    
done < "$temp_file"

# Close JSON array
echo "" >> "$OUTPUT_JSON"
echo "]" >> "$OUTPUT_JSON"

# Statistics
echo -e "\n${GREEN}✅ JSON created successfully${NC}"
echo -e "${GREEN}📊 Statistics:${NC}"
echo "   - Total games: $count"

# Count media by type if jq is available
if command -v jq &> /dev/null; then
    echo -e "\n${BLUE}📊 Media coverage:${NC}"
    boxart_count=$(jq '[.[] | select(.has_boxart == true)] | length' "$OUTPUT_JSON")
    logo_count=$(jq '[.[] | select(.has_logo == true)] | length' "$OUTPUT_JSON")
    snap_count=$(jq '[.[] | select(.has_snap == true)] | length' "$OUTPUT_JSON")
    title_count=$(jq '[.[] | select(.has_title == true)] | length' "$OUTPUT_JSON")
    
    echo "   - Boxarts:  $boxart_count/$count ($(echo "scale=1; $boxart_count*100/$count" | bc)%)"
    echo "   - Logos:    $logo_count/$count ($(echo "scale=1; $logo_count*100/$count" | bc)%)"
    echo "   - Snaps:    $snap_count/$count ($(echo "scale=1; $snap_count*100/$count" | bc)%)"
    echo "   - Titles:   $title_count/$count ($(echo "scale=1; $title_count*100/$count" | bc)%)"
    
    # Region breakdown
    echo -e "\n${BLUE}📊 Region breakdown:${NC}"
    jq -r 'group_by(.region) | map({region: .[0].region, count: length}) | sort_by(-.count) | .[] | "   - \(.region): \(.count) games"' "$OUTPUT_JSON" 2>/dev/null || true
fi

echo -e "\n${YELLOW}📝 Output file:${NC} $OUTPUT_JSON"
echo -e "${YELLOW}📁 File size:${NC} $(du -h "$OUTPUT_JSON" | cut -f1)"