#!/bin/sh
# Podkop xHTTP transport patch for URLTest mode
# https://github.com/moix89/podkop-xhttp-patch

set -e

TARGET="/usr/lib/podkop/sing_box_config_facade.sh"
BACKUP_DIR="/root"
PATCH_MARKER="xhttp)"

log() {
    echo "[podkop-xhttp-patch] $1"
}

die() {
    echo "[podkop-xhttp-patch] ERROR: $1" >&2
    exit 1
}

# Check target file exists
[ -f "$TARGET" ] || die "File not found: $TARGET. Is Podkop installed?"

# Check jq is available
command -v jq >/dev/null 2>&1 || die "jq not found. Install it with: opkg install jq"

# Check if patch is already installed
if grep -q "$PATCH_MARKER" "$TARGET"; then
    log "Patch already installed."
    exit 0
fi

# Create backup
BACKUP="$BACKUP_DIR/sing_box_config_facade.sh.backup.$(date +%Y%m%d_%H%M%S)"
cp "$TARGET" "$BACKUP"
log "Backup created: $BACKUP"

# Build the xhttp block to insert.
# It is inserted before the wildcard *) case inside _add_outbound_transport().
# We locate the line with "    *)" that follows "grpc)" and insert before it.
XHTTP_BLOCK='    xhttp)
        local xhttp_path xhttp_host xhttp_sc_max_each_post_bytes

        xhttp_path=$(url_get_query_param "$url" "path")
        xhttp_host=$(url_get_query_param "$url" "host")
        xhttp_sc_max_each_post_bytes="1000000"

        config=$(echo "$config" | jq \
            --arg outbound_tag "$outbound_tag" \
            --arg path "$xhttp_path" \
            --arg host "$xhttp_host" \
            --arg sc_max_each_post_bytes "$xhttp_sc_max_each_post_bytes" '"'"'
            (.outbounds[] | select(.tag == $outbound_tag)) += {
                transport: (
                    {
                        type: "xhttp",
                        path: $path,
                        mode: "auto",
                        host: $host,
                        x_padding_bytes: "100-1000"
                    }
                    + if $sc_max_each_post_bytes != "" then {
                        sc_max_each_post_bytes: $sc_max_each_post_bytes
                    } else {} end
                )
            }'"'"'
        )

        config=$(echo "$config" | jq \
            --arg outbound_tag "$outbound_tag" '"'"'
            (.outbounds[] | select(.tag == $outbound_tag).tls.alpn) = ["h2", "http/1.1"]
            '"'"'
        )
        ;;'

# Use awk to insert the xhttp block before the *) wildcard inside _add_outbound_transport().
# Strategy: track when we are inside _add_outbound_transport(), find the grpc ;; line,
# then insert before the next *) line.
awk -v block="$XHTTP_BLOCK" '
BEGIN {
    in_func = 0
    after_grpc = 0
    inserted = 0
}
{
    # Detect entry into _add_outbound_transport
    if ($0 ~ /_add_outbound_transport\(\)/) {
        in_func = 1
    }

    # Inside the function, track that we passed the grpc ;; close
    if (in_func && !inserted && $0 ~ /^[[:space:]]*;;[[:space:]]*$/ && after_grpc == 1) {
        after_grpc = 2
    }
    if (in_func && !inserted && $0 ~ /grpc\)/) {
        after_grpc = 1
    }

    # Insert before the *) wildcard after grpc has closed
    if (in_func && !inserted && after_grpc == 2 && $0 ~ /^[[:space:]]*\*\)/) {
        print block
        inserted = 1
    }

    print $0
}
' "$TARGET" > "${TARGET}.tmp"

# Validate the patched file
sh -n "${TARGET}.tmp" || {
    rm -f "${TARGET}.tmp"
    die "Syntax check failed on patched file. Restoring from backup."
}

# Verify the marker ended up in the patched file
grep -q "$PATCH_MARKER" "${TARGET}.tmp" || {
    rm -f "${TARGET}.tmp"
    die "Patch insertion failed (marker not found). Check grpc block formatting in $TARGET."
}

mv "${TARGET}.tmp" "$TARGET"
log "Patch applied successfully."

# Restart Podkop
if [ -x /etc/init.d/podkop ]; then
    log "Restarting Podkop..."
    /etc/init.d/podkop restart && log "Podkop restarted." || log "WARNING: Podkop restart failed. Restart manually."
else
    log "WARNING: /etc/init.d/podkop not found. Restart Podkop manually."
fi

log "Done. xHTTP transport support is now active."
