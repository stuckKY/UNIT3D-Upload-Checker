#!/bin/bash
set -e

# UNIT3D Upload Checker - One-Time Setup Script
# This script configures the application from environment variables
# Run once before first use with: docker compose --profile setup run --rm setup

echo "=================================================="
echo "   UNIT3D Upload Checker - Initial Setup"
echo "=================================================="
echo ""
echo "This script will configure your container using"
echo "environment variables from your .env file."
echo ""
echo "Press CTRL+C to cancel, or press ENTER to continue..."
read -r

# Error counter
ERRORS=0

# ================================================
# 1. CREATE DEFAULT SETTINGS.JSON
# ================================================

if [ ! -f "/app/data/settings.json" ] || [ ! -s "/app/data/settings.json" ]; then
    echo ""
    echo "Creating default settings.json..."
    python3 << 'PYEOF'
import json
import os

default_settings = {
    'directories': [],
    'tmdb_key': '',
    'enabled_sites': [],
    'keys': {
        'aither': '',
        'blutopia': '',
        'fearnopeer': '',
        'reelflix': '',
        'lst': '',
        'ulcx': '',
        'onlyencodes': '',
        'rastastugan': '',
        'homiehelpdesk': '',
        'luminaar': '',
        'midnightscene': '',
    },
    'gg_path': '',
    'ua_path': '',
    'search_cooldown': 5,
    'min_file_size': 800,
    'allow_dupes': True,
    'banned_groups': [],
    'ignored_qualities': ['dvdrip', 'webrip', 'bdrip', 'cam', 'ts', 'telesync', 'hdtv'],
    'ignored_keywords': ['10bit', '10-bit', 'DVD'],
}

os.makedirs('/app/data', exist_ok=True)
with open('/app/data/settings.json', 'w') as f:
    json.dump(default_settings, f, indent=2)
print('✓ Created default settings')
PYEOF

    if [ $? -eq 0 ]; then
        echo "✓ Default settings.json created"
    else
        echo "✗ Failed to create settings.json"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "✓ Existing settings.json found"
fi

# ================================================
# 2. CONFIGURE TMDB API KEY
# ================================================

echo ""
echo "=================================================="
echo "   Configuring TMDB API Key"
echo "=================================================="

if [ -n "$TMDB_API_KEY" ]; then
    echo "Configuring TMDB key..."
    # Capture output to check for errors
    OUTPUT=$(python3 check.py setting-add -t tmdb -s "$TMDB_API_KEY" 2>&1)
    if echo "$OUTPUT" | grep -q "was added to tmdb"; then
        echo "✓ TMDB API key configured"
    else
        echo "✗ Failed to configure TMDB key"
        if echo "$OUTPUT" | grep -q "Invalid API Key"; then
            echo "  API key validation failed"
        elif [ -n "$OUTPUT" ]; then
            echo "  $(echo "$OUTPUT" | head -n 1)"
        fi
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "⚠ TMDB_API_KEY environment variable not provided"
    echo "  Set TMDB_API_KEY in your .env file"
    ERRORS=$((ERRORS + 1))
fi

# ================================================
# 3. CONFIGURE MEDIA DIRECTORY
# ================================================

echo ""
echo "=================================================="
echo "   Configuring Media Directories"
echo "=================================================="

if [ -n "$MEDIA_DIR" ]; then
    echo "Processing directories from MEDIA_DIR: $MEDIA_DIR"

    # Split comma-separated list
    IFS=',' read -ra DIRS <<< "$MEDIA_DIR"
    ADDED_COUNT=0

    for i in "${!DIRS[@]}"; do
        # Trim whitespace
        DIR=$(echo "${DIRS[$i]}" | xargs)

        if [ -n "$DIR" ]; then
            echo "  → Adding directory: $DIR"
            # Capture output to check for errors
            OUTPUT=$(python3 check.py setting-add -t dir -s "$DIR" 2>&1)
            if echo "$OUTPUT" | grep -q "Successfully added"; then
                echo "    ✓ $DIR added"
                ADDED_COUNT=$((ADDED_COUNT + 1))
            else
                echo "    ✗ Failed to add $DIR"
                if echo "$OUTPUT" | grep -q "Path doesn't exist"; then
                    echo "      Directory does not exist"
                elif echo "$OUTPUT" | grep -q "Already in"; then
                    echo "      Already configured"
                    ADDED_COUNT=$((ADDED_COUNT + 1))
                    continue
                elif [ -n "$OUTPUT" ]; then
                    echo "      $(echo "$OUTPUT" | head -n 1)"
                fi
                ERRORS=$((ERRORS + 1))
            fi
        fi
    done

    echo ""
    echo "Summary: $ADDED_COUNT directories configured"
else
    echo "⚠ MEDIA_DIR environment variable not provided"
    echo "  Set MEDIA_DIR in your .env file"
    echo "  You can specify multiple directories separated by commas:"
    echo "  MEDIA_DIR=/data/movies,/data/tv,/data/anime"
    ERRORS=$((ERRORS + 1))
fi

# ================================================
# 4. CONFIGURE TRACKER API KEYS
# ================================================

echo ""
echo "=================================================="
echo "   Configuring Tracker API Keys"
echo "=================================================="

# Map environment variables to tracker names
declare -A TRACKERS=(
    ["AITH_API_KEY"]="aith"
    ["BLU_API_KEY"]="blu"
    ["FNP_API_KEY"]="fnp"
    ["LST_API_KEY"]="lst"
    ["OE_API_KEY"]="oe"
    ["RFX_API_KEY"]="rfx"
    ["UPLOADCX_API_KEY"]="ulcx"
    ["RAS_API_KEY"]="ras"
    ["HHD_API_KEY"]="hhd"
    ["LUME_API_KEY"]="lume"
    ["MNS_API_KEY"]="mns"
)

CONFIGURED_KEYS=0
for ENV_VAR in "${!TRACKERS[@]}"; do
    TRACKER="${TRACKERS[$ENV_VAR]}"
    if [ -n "${!ENV_VAR}" ]; then
        echo "  → Configuring $TRACKER..."
        # Capture output to check for errors
        OUTPUT=$(python3 check.py setting-add -t "$TRACKER" -s "${!ENV_VAR}" 2>&1)
        if echo "$OUTPUT" | grep -q "was added to\|Successfully added"; then
            echo "    ✓ $TRACKER API key added"
            CONFIGURED_KEYS=$((CONFIGURED_KEYS + 1))
        else
            echo "    ✗ Failed to add $TRACKER key"
            if echo "$OUTPUT" | grep -q "Invalid API Key"; then
                echo "      API key validation failed"
            elif [ -n "$OUTPUT" ]; then
                # Show first line of error only to keep output clean
                echo "      $(echo "$OUTPUT" | head -n 1)"
            fi
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

if [ $CONFIGURED_KEYS -eq 0 ]; then
    echo "⚠ No tracker API keys provided"
    echo "  Set tracker keys in your .env file (e.g., FNP_API_KEY, RAS_API_KEY)"
fi

echo ""
echo "Summary: $CONFIGURED_KEYS tracker keys configured"

# ================================================
# 5. ENABLE SITES
# ================================================

echo ""
echo "=================================================="
echo "   Enabling Tracker Sites"
echo "=================================================="

if [ -n "$SITES_ENABLED" ]; then
    echo "Enabling trackers from SITES_ENABLED: $SITES_ENABLED"

    # Split comma-separated list
    IFS=',' read -ra SITES <<< "$SITES_ENABLED"
    ENABLED_COUNT=0

    for SITE in "${SITES[@]}"; do
        # Trim whitespace
        SITE=$(echo "$SITE" | xargs)

        if [ -n "$SITE" ]; then
            echo "  → Enabling $SITE..."
            # Capture output to check for errors
            OUTPUT=$(python3 check.py setting-add -t sites -s "$SITE" 2>&1)
            if echo "$OUTPUT" | grep -q "Successfully added"; then
                echo "    ✓ $SITE enabled"
                ENABLED_COUNT=$((ENABLED_COUNT + 1))
            else
                echo "    ✗ Failed to enable $SITE"
                if echo "$OUTPUT" | grep -q "is not a supported site"; then
                    echo "      Invalid tracker code"
                elif echo "$OUTPUT" | grep -q "no api key"; then
                    echo "      API key not configured yet"
                elif echo "$OUTPUT" | grep -q "Already in"; then
                    echo "      Already enabled"
                    ENABLED_COUNT=$((ENABLED_COUNT + 1))
                    continue
                elif [ -n "$OUTPUT" ]; then
                    echo "      $(echo "$OUTPUT" | head -n 1)"
                fi
                ERRORS=$((ERRORS + 1))
            fi
        fi
    done

    echo ""
    echo "Summary: $ENABLED_COUNT sites enabled"
else
    echo "⚠ SITES_ENABLED environment variable not provided"
    echo "  Set SITES_ENABLED in your .env file (e.g., 'ras,hhd,fnp')"
    echo "  Available: aith, blu, fnp, lst, oe, rfx, ulcx, ras, hhd, lume, mns"
fi

# ================================================
# 6. CONFIGURE OPTIONAL PATHS
# ================================================

echo ""
echo "=================================================="
echo "   Configuring Optional Paths"
echo "=================================================="

if [ -n "$GG_PATH" ]; then
    echo "Configuring gg-bot path: $GG_PATH"
    if python3 check.py setting-add -t gg -s "$GG_PATH" > /dev/null 2>&1; then
        echo "✓ gg-bot path configured"
    else
        echo "✗ Failed to configure gg-bot path"
    fi
fi

if [ -n "$UA_PATH" ]; then
    echo "Configuring upload-assistant path: $UA_PATH"
    if python3 check.py setting-add -t ua -s "$UA_PATH" > /dev/null 2>&1; then
        echo "✓ upload-assistant path configured"
    else
        echo "✗ Failed to configure upload-assistant path"
    fi
fi

if [ -z "$GG_PATH" ] && [ -z "$UA_PATH" ]; then
    echo "⚠ No optional paths configured (GG_PATH, UA_PATH)"
    echo "  These are optional - only needed for export commands"
fi

# ================================================
# 7. FINAL SUMMARY
# ================================================

echo ""
echo "=================================================="
echo "   Setup Complete!"
echo "=================================================="
echo ""

# Display final configuration status
python3 << 'PYEOF'
import json
import os

try:
    with open('/app/data/settings.json') as f:
        s = json.load(f)

        print("Configuration Summary:")
        print("---------------------")
        print(f"TMDB Key:       {'✓ Configured' if s.get('tmdb_key') else '✗ Missing'}")
        print(f"Directories:    {len(s.get('directories', []))} configured")

        enabled = s.get('enabled_sites', [])
        if enabled:
            print(f"Enabled Sites:  {', '.join(enabled)}")
        else:
            print("Enabled Sites:  ✗ None")

        keys = s.get('keys', {})
        configured = [k for k, v in keys.items() if v]
        print(f"Tracker Keys:   {len(configured)}/{len(keys)} configured")

        if s.get('gg_path'):
            print(f"gg-bot path:    ✓ Configured")
        if s.get('ua_path'):
            print(f"UA path:        ✓ Configured")

except Exception as e:
    print(f"Unable to read settings: {e}")
PYEOF

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✓ Setup completed successfully with no errors!"
else
    echo "⚠ Setup completed with $ERRORS error(s)"
    echo "  Review the output above and fix any issues"
    echo "  You can re-run this script safely to reconfigure"
fi

echo ""
echo "Next steps:"
echo "1. Start your container:"
echo "   docker compose up -d"
echo ""
echo "2. Access the shell:"
echo "   docker exec -it unit3d-upload-checker bash"
echo ""
echo "3. Run the checker:"
echo "   python3 check.py run-all -v"
echo ""
echo "=================================================="

if [ $ERRORS -eq 0 ]; then
    exit 0
else
    exit 1
fi
