#!/bin/bash
set -e

# UNIT3D Upload Checker - Container Entrypoint
# This minimal entrypoint launches the container and displays status
# Configuration happens via separate setup script

echo "=================================================="
echo "   UNIT3D Upload Checker"
echo "=================================================="

# Create necessary directories
mkdir -p /app/data /app/outputs

# ================================================
# AUTO-CONFIGURE FROM ENVIRONMENT VARIABLES
# ================================================

NEEDS_SETUP=false
if [ ! -f "/app/data/settings.json" ] || [ ! -s "/app/data/settings.json" ]; then
    NEEDS_SETUP=true
fi

if [ "$NEEDS_SETUP" = true ] || [ "${FORCE_SETUP:-false}" = "true" ]; then
    echo ""
    echo "Configuring from environment variables..."
    echo ""

    # TMDB key
    if [ -n "$TMDB_API_KEY" ]; then
        echo "  → Setting TMDB API key..."
        python3 check.py setting-add -t tmdb -s "$TMDB_API_KEY" 2>&1 | sed 's/^/    /'
    fi

    # Media directories
    if [ -n "$MEDIA_DIR" ]; then
        IFS=',' read -ra DIRS <<< "$MEDIA_DIR"
        for DIR in "${DIRS[@]}"; do
            DIR=$(echo "$DIR" | xargs)
            if [ -n "$DIR" ]; then
                echo "  → Adding directory: $DIR"
                python3 check.py setting-add -t dir -s "$DIR" 2>&1 | sed 's/^/    /'
            fi
        done
    fi

    # Tracker API keys
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

    for ENV_VAR in "${!TRACKERS[@]}"; do
        TRACKER="${TRACKERS[$ENV_VAR]}"
        if [ -n "${!ENV_VAR}" ]; then
            echo "  → Configuring $TRACKER API key..."
            python3 check.py setting-add -t "$TRACKER" -s "${!ENV_VAR}" 2>&1 | sed 's/^/    /'
        fi
    done

    # Enable sites
    if [ -n "$SITES_ENABLED" ]; then
        IFS=',' read -ra SITES <<< "$SITES_ENABLED"
        for SITE in "${SITES[@]}"; do
            SITE=$(echo "$SITE" | xargs)
            if [ -n "$SITE" ]; then
                echo "  → Enabling $SITE..."
                python3 check.py setting-add -t sites -s "$SITE" 2>&1 | sed 's/^/    /'
            fi
        done
    fi

    # Optional paths
    if [ -n "$GG_PATH" ]; then
        echo "  → Setting gg-bot path..."
        python3 check.py setting-add -t gg -s "$GG_PATH" 2>&1 | sed 's/^/    /'
    fi
    if [ -n "$UA_PATH" ]; then
        echo "  → Setting upload-assistant path..."
        python3 check.py setting-add -t ua_path -s "$UA_PATH" 2>&1 | sed 's/^/    /'
    fi

    echo ""
    echo "Auto-configuration complete!"
    echo ""
fi

# ================================================
# DISPLAY CONFIGURATION STATUS
# ================================================

if [ -f "/app/data/settings.json" ]; then
    echo ""
    echo "Current Configuration:"
    echo "---------------------"
    python3 << 'PYEOF' 2>/dev/null || echo "Unable to read settings"
import json
try:
    with open('/app/data/settings.json') as f:
        s = json.load(f)

    # TMDB Status
    tmdb_status = '✓ Configured' if s.get('tmdb_key') else '✗ Missing'
    print(f'TMDB Key:       {tmdb_status}')

    # Directories
    dirs = s.get('directories', [])
    print(f'Directories:    {len(dirs)} configured')

    # Enabled Sites
    enabled = s.get('enabled_sites', [])
    if enabled:
        print(f'Enabled Sites:  {", ".join(enabled)}')
    else:
        print('Enabled Sites:  None')

except Exception:
    pass
PYEOF
    echo ""
fi

# ================================================
# DISPLAY AVAILABLE COMMANDS
# ================================================

echo "Available Commands:"
echo "-------------------"
echo "  python3 check.py run-all -v      # Run full workflow"
echo "  python3 check.py scan -v         # Scan directories"
echo "  python3 check.py tmdb -v         # Match with TMDB"
echo "  python3 check.py search -v       # Search trackers"
echo "  python3 check.py setting -t dir  # View settings"
echo ""
echo "=================================================="

# Execute the provided command or default to bash
if [ $# -eq 0 ]; then
    exec /bin/bash
else
    exec "$@"
fi
