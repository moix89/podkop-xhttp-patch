# podkop-xhttp-patch

One-command patch that adds **xHTTP transport** support to [Podkop](https://github.com/itdoginfo/podkop) so `URLTest` works with `vless://...type=xhttp...` links.

---

## Problem

Podkop crashes with the error:

```
Unknown transport 'xhttp' detected.
```

**Root cause:** `_add_outbound_transport()` in `/usr/lib/podkop/sing_box_config_facade.sh` has no `xhttp)` branch in its `case` statement.

---

## What the patch does

Inserts an `xhttp)` block into `_add_outbound_transport()` right after the `grpc)` block. The inserted code:

1. Reads `path` and `host` from the VLESS URL query parameters.
2. Builds a `transport` object in the sing-box config:

```json
"transport": {
  "type": "xhttp",
  "path": "/api/v1/files",
  "mode": "auto",
  "host": "example.com",
  "x_padding_bytes": "100-1000",
  "sc_max_each_post_bytes": "1000000"
}
```

3. Automatically sets TLS ALPN to `["h2", "http/1.1"]`.

This makes Podkop fully capable of using multiple `vless://...type=xhttp...` links in **URLTest** mode with automatic server failover.

---

## Installation

```sh
sh <(wget -O - https://raw.githubusercontent.com/moix89/podkop-xhttp-patch/main/install.sh)
```

### What the installer does

| Step | Action |
|------|--------|
| 1 | Verifies `/usr/lib/podkop/sing_box_config_facade.sh` exists |
| 2 | Verifies `jq` is available |
| 3 | Creates a timestamped backup at `/root/sing_box_config_facade.sh.backup.YYYYMMDD_HHMMSS` |
| 4 | Checks if the patch is already installed (safe to re-run) |
| 5 | Inserts the `xhttp)` block before `*)` inside `_add_outbound_transport()` |
| 6 | Runs `sh -n` syntax check on the patched file |
| 7 | Restarts Podkop |

The script is **idempotent** — running it twice is safe and prints `Patch already installed.`

---

## Verification

```sh
# Syntax check the patched file
sh -n /usr/lib/podkop/sing_box_config_facade.sh

# Restart Podkop manually if needed
/etc/init.d/podkop restart

# Confirm URLTest outbound is present in the generated config
jq '.outbounds[] | select(.type=="urltest")' /etc/sing-box/config.json

# Confirm xHTTP transport outbound is present
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json
```

Expected output for an xHTTP outbound:

```json
{
  "type": "vless",
  "tag": "...",
  "transport": {
    "type": "xhttp",
    "path": "/api/v1/files",
    "mode": "auto",
    "host": "example.com",
    "x_padding_bytes": "100-1000",
    "sc_max_each_post_bytes": "1000000"
  },
  "tls": {
    "alpn": ["h2", "http/1.1"]
  }
}
```

---

## Compatibility

| Component | Version |
|-----------|---------|
| OpenWrt | 25.12.2 |
| Podkop | 0.7.17 |
| sing-box-extended | 1.13.11-extended-2.1.0 |
| Protocol | VLESS Reality XHTTP |
| Mode | URLTest failover |

---

## After Podkop updates

If Podkop is updated via `opkg`, the original file is overwritten and the patch is lost. Simply re-run the install command to re-apply it.

---

## Uninstall / rollback

Restore the backup that was created during installation:

```sh
# List available backups
ls /root/sing_box_config_facade.sh.backup.*

# Restore (replace the timestamp with the actual file name)
cp /root/sing_box_config_facade.sh.backup.20250101_120000 /usr/lib/podkop/sing_box_config_facade.sh
/etc/init.d/podkop restart
```

---

## How it works (technical detail)

Podkop parses `vless://` share links and builds a sing-box JSON config. The transport type is read from the `type=` query parameter. Before this patch, the following transports were handled:

- `tcp` / `raw` — no-op
- `ws` — WebSocket
- `grpc` — gRPC

The patch adds:

- `xhttp` — HTTP/2 multiplexed transport (XHTTP)

The `awk`-based installer locates the `*)` wildcard case that immediately follows the `grpc ;;` closing line and inserts the new block before it, so the structure remains:

```
grpc)   ...  ;;
xhttp)  ...  ;;   ← inserted here
*)      log "Unknown transport..."
```

---

## License

MIT — see [LICENSE](LICENSE).
