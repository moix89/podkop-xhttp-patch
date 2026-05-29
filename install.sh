#!/bin/sh
# Podkop xHTTP patch — adds xhttp transport + fixes sing-box-extended version detection
# https://github.com/moix89/podkop-xhttp-patch

FACADE="/usr/lib/podkop/sing_box_config_facade.sh"
PODKOP="/usr/bin/podkop"
BACKUP_DIR="/root"

MARKER_XHTTP="sc_min_posts_interval_ms"
MARKER_VERSION="cut -d'-' -f1"

ERRORS=0

log()  { echo "[podkop-xhttp-patch] $1"; }
warn() { echo "[podkop-xhttp-patch] WARN: $1" >&2; }
err()  { echo "[podkop-xhttp-patch] ERROR: $1" >&2; ERRORS=$((ERRORS + 1)); }
die()  { echo "[podkop-xhttp-patch] FATAL: $1" >&2; exit 1; }

# ── preflight checks ──────────────────────────────────────────────────────────

for cmd in jq sed awk; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd not found. Install: opkg install $cmd"
done

command -v sing-box >/dev/null 2>&1 || warn "sing-box not found in PATH. Make sure sing-box-extended is installed."

[ -f "$FACADE" ] || die "Not found: $FACADE  — is Podkop installed?"
[ -f "$PODKOP" ] || die "Not found: $PODKOP  — is Podkop installed?"

# ── backup ────────────────────────────────────────────────────────────────────

TS="$(date +%Y%m%d_%H%M%S)"

cp "$FACADE" "$BACKUP_DIR/sing_box_config_facade.sh.backup.$TS"
log "Backup: $BACKUP_DIR/sing_box_config_facade.sh.backup.$TS"

cp "$PODKOP" "$BACKUP_DIR/podkop.backup.$TS"
log "Backup: $BACKUP_DIR/podkop.backup.$TS"

# ── patch 1: xhttp transport block in sing_box_config_facade.sh ───────────────

if grep -q "$MARKER_XHTTP" "$FACADE"; then
    log "[1/2] xhttp transport block — already up to date, skipping."
else
    log "[1/2] Inserting/updating xhttp transport block..."

    # Write the new block to a temp file (single quotes in jq filters are safe inside heredoc).
    BLOCK_FILE="/tmp/_podkop_xhttp_block.$$"
    cat > "$BLOCK_FILE" << 'XHTTP_BLOCK_EOF'
    xhttp)
        local xhttp_path xhttp_host xhttp_sc_max_each_post_bytes xhttp_sc_min_posts_interval_ms

        xhttp_path=$(url_get_query_param "$url" "path")
        xhttp_host=$(url_get_query_param "$url" "host")
        xhttp_sc_max_each_post_bytes="1000000"
        xhttp_sc_min_posts_interval_ms="30"

        config=$(echo "$config" | jq \
            --arg outbound_tag "$outbound_tag" \
            --arg path "$xhttp_path" \
            --arg host "$xhttp_host" \
            --arg sc_max_each_post_bytes "$xhttp_sc_max_each_post_bytes" \
            --arg sc_min_posts_interval_ms "$xhttp_sc_min_posts_interval_ms" '
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
                    + if $sc_min_posts_interval_ms != "" then {
                        sc_min_posts_interval_ms: $sc_min_posts_interval_ms
                    } else {} end
                )
            }'
        )

        config=$(echo "$config" | jq \
            --arg outbound_tag "$outbound_tag" '
            (.outbounds[] | select(.tag == $outbound_tag).tls.alpn) = ["h2", "http/1.1"]
            '
        )
        ;;
XHTTP_BLOCK_EOF

    # awk strategy:
    # - If an old xhttp) block exists (without sc_min_posts_interval_ms):
    #     skip lines from xhttp) through its closing ;; and insert new block instead.
    # - If no xhttp) block exists:
    #     insert new block before *) after grpc ;; closes.
    HAS_OLD_XHTTP=0
    grep -q "xhttp)" "$FACADE" && HAS_OLD_XHTTP=1

    if [ "$HAS_OLD_XHTTP" -eq 1 ]; then
        # Replace old xhttp block: skip from "xhttp)" up to and including its "    ;;"
        awk '
        BEGIN { skip=0; inserted=0 }
        {
            # Start skipping at the old xhttp) line
            if (!inserted && $0 ~ /^[[:space:]]*xhttp\)/) {
                skip=1
            }
            # End skipping at the ;; that closes xhttp), then emit new block
            if (skip && $0 ~ /^[[:space:]]*;;[[:space:]]*$/) {
                skip=0
                inserted=1
                while ((getline line < BLOCK_FILE) > 0) { print line }
                close(BLOCK_FILE)
                next
            }
            if (!skip) { print $0 }
        }
        ' BLOCK_FILE="$BLOCK_FILE" "$FACADE" > "${FACADE}.tmp"
    else
        # Fresh insert: find _add_outbound_transport(), wait for grpc ;; to close,
        # insert before the *) wildcard.
        awk '
        BEGIN { in_func=0; after_grpc=0; inserted=0 }
        {
            if ($0 ~ /_add_outbound_transport\(\)/) { in_func=1 }

            if (in_func && !inserted && after_grpc==1 && $0 ~ /^[[:space:]]*;;[[:space:]]*$/) {
                after_grpc=2
            }
            if (in_func && !inserted && $0 ~ /grpc\)/) { after_grpc=1 }

            if (in_func && !inserted && after_grpc==2 && $0 ~ /^[[:space:]]*\*\)/) {
                while ((getline line < BLOCK_FILE) > 0) { print line }
                close(BLOCK_FILE)
                inserted=1
            }
            print $0
        }
        ' BLOCK_FILE="$BLOCK_FILE" "$FACADE" > "${FACADE}.tmp"
    fi

    rm -f "$BLOCK_FILE"

    sh -n "${FACADE}.tmp" || {
        rm -f "${FACADE}.tmp"
        err "Syntax check failed on patched $FACADE"
    }

    if ! grep -q "$MARKER_XHTTP" "${FACADE}.tmp"; then
        rm -f "${FACADE}.tmp"
        err "Block insertion failed — marker not found in ${FACADE}.tmp"
    else
        mv "${FACADE}.tmp" "$FACADE"
        log "[1/2] xhttp transport block updated (sc_min_posts_interval_ms added)."
    fi
fi

# ── patch 2: sing-box version detection in /usr/bin/podkop ───────────────────

if grep -q "$MARKER_VERSION" "$PODKOP"; then
    log "[2/2] Version detection fix — already installed, skipping."
else
    log "[2/2] Fixing sing-box version detection..."

    cp "$PODKOP" "${PODKOP}.tmp"

    # All three substitutions use awk with exact string matching.
    # Replacement lines are written to a temp file to avoid any quoting issues.

    # Patch 2a: check_requirements() — add | cut -d'-' -f1 after awk '{print $3}'
    # We match the unique substring and replace the whole line with a known-good version.
    # Using python-free pure sh: read line by line and do exact string replacement.

    # Build needle/replacement strings using a single-quote variable trick
    # so that awk's {print $3} is never interpreted by the shell.
    SQ="'"

    NEEDLE_A="sing-box version | head -n1 | awk ${SQ}{print \$3}${SQ})\""
    REPLACE_A="sing-box version | head -n1 | awk ${SQ}{print \$3}${SQ} | cut -d${SQ}-${SQ} -f1)\""

    NEEDLE_B="sing-box version 2> /dev/null | head -n 1 | awk ${SQ}{print \$3}${SQ})"
    REPLACE_B="sing-box version 2> /dev/null | head -n 1 | awk ${SQ}{print \$3}${SQ} | cut -d${SQ}-${SQ} -f1)"

    # Use awk with -v and index()+substr() for literal string replacement
    # (gsub would treat the needle as a regex, which breaks on $, (, [ etc.)
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

    # Patch 2c: version comparison — replace subshell form with POSIX-safe braces.
    # The original two lines look like:
    #   if [ "$major" -gt 1 ] || ([ "$major" -eq 1 ] && [ "$minor" -gt 12 ]) || \
    #      ([ "$major" -eq 1 ] && [ "$minor" -eq 12 ] && [ "$patch" -ge 4 ]); then
    awk '
    /if \[ "\$major" -gt 1 \] \|\| \(/ {
        getline  # discard continuation line
        print "    if [ \"$major\" -gt 1 ] || \\"
        print "       { [ \"$major\" -eq 1 ] && [ \"$minor\" -gt 12 ]; } || \\"
        print "       { [ \"$major\" -eq 1 ] && [ \"$minor\" -eq 12 ] && [ \"$patch\" -ge 4 ]; }; then"
        next
    }
    { print $0 }
    ' "${PODKOP}.tmp" > "${PODKOP}.tmp2"
    mv "${PODKOP}.tmp2" "${PODKOP}.tmp"

    sh -n "${PODKOP}.tmp" || {
        rm -f "${PODKOP}.tmp"
        err "Syntax check failed on patched $PODKOP"
    }

    if ! grep -q "$MARKER_VERSION" "${PODKOP}.tmp"; then
        rm -f "${PODKOP}.tmp"
        err "Version fix not applied — original pattern not found in $PODKOP. Podkop may have been updated."
    else
        mv "${PODKOP}.tmp" "$PODKOP"
        log "[2/2] Version detection fix applied."
    fi
fi

# ── restart ───────────────────────────────────────────────────────────────────

if [ "$ERRORS" -gt 0 ]; then
    warn "One or more patches failed. Review errors above. Backups are in $BACKUP_DIR"
    warn "Skipping Podkop restart."
    exit 1
fi

if [ -x /etc/init.d/podkop ]; then
    log "Restarting Podkop..."
    /etc/init.d/podkop restart && log "Podkop restarted." \
        || warn "Podkop restart failed — restart manually: /etc/init.d/podkop restart"
else
    warn "/etc/init.d/podkop not found — restart Podkop manually."
fi

# ── verification hints ────────────────────────────────────────────────────────

log ""
log "All patches applied. Run these to verify:"
log ""
log "  podkop global_check"
log "  jq '.outbounds[] | select(.transport.type==\"xhttp\")' /etc/sing-box/config.json"
log "  jq '.outbounds[] | select(.type==\"urltest\")' /etc/sing-box/config.json"
