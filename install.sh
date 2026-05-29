#!/bin/sh
# Podkop xHTTP patch
# - Adds xhttp transport with full parameter support (mode, x_padding_bytes, sc_* fields)
# - Adds spider_x support for Reality (spx URL param -> tls.reality.spider_x)
# - Fixes sing-box-extended version detection in /usr/bin/podkop
# https://github.com/moix89/podkop-xhttp-patch

FACADE="/usr/lib/podkop/sing_box_config_facade.sh"
PODKOP="/usr/bin/podkop"
BACKUP_DIR="/root"

# Markers: unique strings present only after the respective patch is applied.
# Changing a marker forces re-apply even if an older version of the patch exists.
MARKER_XHTTP="xhttp_sc_min_posts_interval_ms"
MARKER_SPIDER="spider_x"
MARKER_VERSION="cut -d'-' -f1"

ERRORS=0

log()  { echo "[podkop-xhttp-patch] $1"; }
warn() { echo "[podkop-xhttp-patch] WARN: $1" >&2; }
err()  { echo "[podkop-xhttp-patch] ERROR: $1" >&2; ERRORS=$((ERRORS + 1)); }
die()  { echo "[podkop-xhttp-patch] FATAL: $1" >&2; exit 1; }

# ── preflight ─────────────────────────────────────────────────────────────────

for cmd in jq sed awk; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd not found. Install: opkg install $cmd"
done
command -v sing-box >/dev/null 2>&1 \
    || warn "sing-box not found. Make sure sing-box-extended is installed."

[ -f "$FACADE" ] || die "Not found: $FACADE — is Podkop installed?"
[ -f "$PODKOP" ] || die "Not found: $PODKOP — is Podkop installed?"

# ── backup ────────────────────────────────────────────────────────────────────

TS="$(date +%Y%m%d_%H%M%S)"
cp "$FACADE" "$BACKUP_DIR/sing_box_config_facade.sh.backup.$TS"
log "Backup: $BACKUP_DIR/sing_box_config_facade.sh.backup.$TS"
cp "$PODKOP"  "$BACKUP_DIR/podkop.backup.$TS"
log "Backup: $BACKUP_DIR/podkop.backup.$TS"

# ─────────────────────────────────────────────────────────────────────────────
# PATCH 1 — xhttp transport block
# Reads path/host/mode/x_padding_bytes/sc_* from URL query params with defaults.
# Idempotent: marker = sc_min_posts_interval_ms
# If old xhttp) block exists without marker → replace it.
# If no xhttp) block at all → insert before *) after grpc closes.
# ─────────────────────────────────────────────────────────────────────────────

if grep -q "$MARKER_XHTTP" "$FACADE"; then
    log "[1/3] xhttp block — already up to date, skipping."
else
    log "[1/3] Inserting/updating xhttp transport block..."

    BLOCK_FILE="/tmp/_podkop_xhttp_block.$$"
    cat > "$BLOCK_FILE" << 'XHTTP_BLOCK_EOF'
    xhttp)
        local xhttp_path xhttp_host xhttp_mode xhttp_x_padding_bytes
        local xhttp_sc_max_each_post_bytes xhttp_sc_min_posts_interval_ms

        xhttp_path=$(url_get_query_param "$url" "path")
        xhttp_host=$(url_get_query_param "$url" "host")
        xhttp_mode=$(url_get_query_param "$url" "mode")
        xhttp_x_padding_bytes=$(url_get_query_param "$url" "xPaddingBytes")

        # extra.* fields encoded as JSON in the "extra" query param
        local xhttp_extra xhttp_extra_max xhttp_extra_min xhttp_extra_xpad
        xhttp_extra=$(url_get_query_param "$url" "extra")
        if [ -n "$xhttp_extra" ]; then
            xhttp_extra_max=$(echo "$xhttp_extra" | jq -r '.scMaxEachPostBytes // empty' 2>/dev/null)
            xhttp_extra_min=$(echo "$xhttp_extra" | jq -r '.scMinPostsIntervalMs // empty' 2>/dev/null)
            xhttp_extra_xpad=$(echo "$xhttp_extra" | jq -r '.xPaddingBytes // empty' 2>/dev/null)
        fi

        # Apply defaults where value is missing
        [ -z "$xhttp_mode" ]              && xhttp_mode="auto"
        [ -z "$xhttp_x_padding_bytes" ]   && xhttp_x_padding_bytes="${xhttp_extra_xpad:-100-1000}"
        # Values from extra may be quoted strings like "1000000" — strip quotes, use as numbers
        xhttp_sc_max_each_post_bytes="${xhttp_extra_max:-1000000}"
        xhttp_sc_min_posts_interval_ms="${xhttp_extra_min:-30}"
        # sc_* fields must be strings (not numbers) per sing-box-extended schema
        # Strip surrounding quotes from extra values just in case
        xhttp_sc_max_each_post_bytes=$(echo "$xhttp_sc_max_each_post_bytes" | tr -d '"')
        xhttp_sc_min_posts_interval_ms=$(echo "$xhttp_sc_min_posts_interval_ms" | tr -d '"')

        config=$(echo "$config" | jq \
            --arg outbound_tag "$outbound_tag" \
            --arg path "$xhttp_path" \
            --arg host "$xhttp_host" \
            --arg mode "$xhttp_mode" \
            --arg x_padding_bytes "$xhttp_x_padding_bytes" \
            --arg sc_max_each_post_bytes "$xhttp_sc_max_each_post_bytes" \
            --arg sc_min_posts_interval_ms "$xhttp_sc_min_posts_interval_ms" '
            (.outbounds[] | select(.tag == $outbound_tag)) += {
                transport: (
                    { type: "xhttp", path: $path, mode: $mode, host: $host }
                    + if $x_padding_bytes != "" then { x_padding_bytes: $x_padding_bytes } else {} end
                    + if $sc_max_each_post_bytes != "" then { sc_max_each_post_bytes: $sc_max_each_post_bytes } else {} end
                    + if $sc_min_posts_interval_ms != "" then { sc_min_posts_interval_ms: $sc_min_posts_interval_ms } else {} end
                )
            }'
        )

        # Set ALPN: use value from URL if present, otherwise default to h2+http/1.1
        local xhttp_alpn
        xhttp_alpn=$(url_get_query_param "$url" "alpn")
        if [ -n "$xhttp_alpn" ]; then
            local alpn_json
            alpn_json=$(echo "$xhttp_alpn" | tr ',' '\n' | jq -R . | jq -s .)
            config=$(echo "$config" | jq \
                --arg outbound_tag "$outbound_tag" \
                --argjson alpn "$alpn_json" '
                (.outbounds[] | select(.tag == $outbound_tag).tls.alpn) = $alpn
                '
            )
        else
            config=$(echo "$config" | jq \
                --arg outbound_tag "$outbound_tag" '
                (.outbounds[] | select(.tag == $outbound_tag).tls.alpn) = ["h2", "http/1.1"]
                '
            )
        fi
        ;;
XHTTP_BLOCK_EOF

    HAS_OLD_XHTTP=0
    grep -q "xhttp)" "$FACADE" && HAS_OLD_XHTTP=1

    if [ "$HAS_OLD_XHTTP" -eq 1 ]; then
        # Replace old xhttp) block in-place (skip lines from xhttp) through its ;;)
        awk '
        BEGIN { skip=0; inserted=0 }
        {
            if (!inserted && $0 ~ /^[[:space:]]*xhttp\)/) { skip=1 }
            if (skip && $0 ~ /^[[:space:]]*;;[[:space:]]*$/) {
                skip=0; inserted=1
                while ((getline line < BLOCK_FILE) > 0) { print line }
                close(BLOCK_FILE)
                next
            }
            if (!skip) { print $0 }
        }
        ' BLOCK_FILE="$BLOCK_FILE" "$FACADE" > "${FACADE}.tmp"
    else
        # Fresh insert before *) after grpc ;; closes inside _add_outbound_transport()
        # Use line-number approach: find *) that comes after grpc) closing ;;
        # Step 1: find line number of *) inside _add_outbound_transport that follows grpc
        INSERT_LINE=$(awk '
            /^_add_outbound_transport\(\)/ { in_func=1 }
            in_func && /^[[:space:]]*grpc\)/ { after_grpc=1 }
            in_func && after_grpc && /^[[:space:]]*;;/ { after_grpc=2 }
            in_func && after_grpc==2 && /^[[:space:]]*\*\)/ { print NR; exit }
        ' "$FACADE")

        if [ -z "$INSERT_LINE" ]; then
            rm -f "$BLOCK_FILE"
            err "xhttp: cannot find insertion point (*) after grpc) in $FACADE"
        else
            awk -v line="$INSERT_LINE" '
            NR == line {
                while ((getline l < BLOCK_FILE) > 0) { print l }
                close(BLOCK_FILE)
            }
            { print }
            ' BLOCK_FILE="$BLOCK_FILE" "$FACADE" > "${FACADE}.tmp"
        fi
    fi

    rm -f "$BLOCK_FILE"

    sh -n "${FACADE}.tmp" || { rm -f "${FACADE}.tmp"; err "Syntax check failed: $FACADE"; }

    if ! grep -q "$MARKER_XHTTP" "${FACADE}.tmp"; then
        rm -f "${FACADE}.tmp"
        err "xhttp block not found after patch — check grpc block indentation in $FACADE"
    else
        mv "${FACADE}.tmp" "$FACADE"
        log "[1/3] xhttp transport block applied."
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# PATCH 2 — remove spider_x if previously applied
# sing-box 1.13.12 does NOT support spider_x field in tls.reality.
# If the old patch added it, remove it now.
# ─────────────────────────────────────────────────────────────────────────────

if grep -q "$MARKER_SPIDER" "$FACADE"; then
    log "[2/3] Removing spider_x block (not supported by sing-box 1.13.12+)..."

    # Remove lines from "local spx spider_x" through the closing ) of the jq call
    awk '
    BEGIN { skip=0 }
    /[[:space:]]*local spx spider_x/ { skip=1 }
    {
        if (!skip) { print $0 }
    }
    /^[[:space:]]*\)[[:space:]]*$/ && skip { skip=0; next }
    ' "$FACADE" > "${FACADE}.tmp"

    sh -n "${FACADE}.tmp" || { rm -f "${FACADE}.tmp"; err "Syntax check failed removing spider_x: $FACADE"; }

    if grep -q "$MARKER_SPIDER" "${FACADE}.tmp"; then
        rm -f "${FACADE}.tmp"
        err "spider_x block removal failed"
    else
        mv "${FACADE}.tmp" "$FACADE"
        log "[2/3] spider_x block removed."
    fi
else
    log "[2/3] spider_x — not present, skipping."
fi

# ─────────────────────────────────────────────────────────────────────────────
# PATCH 3 — sing-box version detection in /usr/bin/podkop
# Strips -extended-* suffix so version comparison works with sing-box-extended.
# Idempotent: marker = cut -d'-' -f1
# ─────────────────────────────────────────────────────────────────────────────

if grep -q "$MARKER_VERSION" "$PODKOP"; then
    log "[3/3] Version detection fix — already installed, skipping."
else
    log "[3/3] Fixing sing-box version detection..."

    cp "$PODKOP" "${PODKOP}.tmp"

    SQ="'"

    # 3a. check_requirements(): add | cut -d'-' -f1 after awk '{print $3}'
    NEEDLE_A="sing-box version | head -n1 | awk ${SQ}{print \$3}${SQ})\""
    REPLACE_A="sing-box version | head -n1 | awk ${SQ}{print \$3}${SQ} | cut -d${SQ}-${SQ} -f1)\""

    # 3b. check_sing_box(): same for the 2>/dev/null form
    NEEDLE_B="sing-box version 2> /dev/null | head -n 1 | awk ${SQ}{print \$3}${SQ})"
    REPLACE_B="sing-box version 2> /dev/null | head -n 1 | awk ${SQ}{print \$3}${SQ} | cut -d${SQ}-${SQ} -f1)"

    # Use index()+substr() — gsub() would treat needles as regex (breaks on $, (, [)
    awk -v na="$NEEDLE_A" -v ra="$REPLACE_A" \
        -v nb="$NEEDLE_B" -v rb="$REPLACE_B" '
    {
        line = $0
        if ((p = index(line, na)) > 0)
            line = substr(line, 1, p-1) ra substr(line, p+length(na))
        if ((p = index(line, nb)) > 0)
            line = substr(line, 1, p-1) rb substr(line, p+length(nb))
        print line
    }
    ' "${PODKOP}.tmp" > "${PODKOP}.tmp2"
    mv "${PODKOP}.tmp2" "${PODKOP}.tmp"

    # 3c. Version comparison: replace subshell (...)  with POSIX-safe { ...; }
    # Original two-line pattern:
    #   if [ "$major" -gt 1 ] || ([ "$major" -eq 1 ] && [ "$minor" -gt 12 ]) || \
    #      ([ "$major" -eq 1 ] && [ "$minor" -eq 12 ] && [ "$patch" -ge 4 ]); then
    awk '
    /if \[ "\$major" -gt 1 \] \|\| \(/ {
        getline  # discard second line of original pattern
        print "    if [ \"$major\" -gt 1 ] || \\"
        print "       { [ \"$major\" -eq 1 ] && [ \"$minor\" -gt 12 ]; } || \\"
        print "       { [ \"$major\" -eq 1 ] && [ \"$minor\" -eq 12 ] && [ \"$patch\" -ge 4 ]; }; then"
        next
    }
    { print $0 }
    ' "${PODKOP}.tmp" > "${PODKOP}.tmp2"
    mv "${PODKOP}.tmp2" "${PODKOP}.tmp"

    sh -n "${PODKOP}.tmp" || { rm -f "${PODKOP}.tmp"; err "Syntax check failed: $PODKOP"; }

    if ! grep -q "$MARKER_VERSION" "${PODKOP}.tmp"; then
        rm -f "${PODKOP}.tmp"
        err "Version fix not applied — pattern not found in $PODKOP. Podkop may have been updated."
    else
        mv "${PODKOP}.tmp" "$PODKOP"
        chmod +x "$PODKOP"
        log "[3/3] Version detection fix applied."
    fi
fi

# ── restart ───────────────────────────────────────────────────────────────────

if [ "$ERRORS" -gt 0 ]; then
    warn "One or more patches failed — see errors above. Backups: $BACKUP_DIR"
    warn "Skipping Podkop restart."
    exit 1
fi

if [ -x /etc/init.d/podkop ]; then
    log "Restarting Podkop..."
    /etc/init.d/podkop restart && log "Podkop restarted." \
        || warn "Restart failed — run manually: /etc/init.d/podkop restart"
else
    warn "/etc/init.d/podkop not found — restart Podkop manually."
fi

# ── verify hints ──────────────────────────────────────────────────────────────

log ""
log "Done. Verify with:"
log "  podkop global_check"
log "  sing-box check -c /etc/sing-box/config.json"
log "  jq '.outbounds[] | select(.transport.type==\"xhttp\")' /etc/sing-box/config.json"
log "  jq '.outbounds[] | select(.type==\"urltest\")' /etc/sing-box/config.json"
