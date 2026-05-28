[English](#english) | [Русский](#русский)

---

# English

## podkop-xhttp-patch

One-command patch that adds **xHTTP transport** support to [Podkop](https://github.com/itdoginfo/podkop) so `URLTest` works with `vless://...type=xhttp...` links on OpenWrt.

### Problem

Podkop crashes with:

```text
Unknown transport 'xhttp' detected.
```

**Root cause:** `_add_outbound_transport()` in `/usr/lib/podkop/sing_box_config_facade.sh` has no `xhttp)` branch in its `case` statement.

---

### Prerequisites

Before applying this patch make sure **sing-box-extended** is installed — it is required for xHTTP transport support.

Install sing-box-extended with one command:

```sh
sh <(wget -O - https://raw.githubusercontent.com/EikeiDev/OpenWRT-sing-box-extended/refs/heads/main/install.sh)
```

> sing-box-extended adds xHTTP, XUDP and other modern transports that the stock sing-box package does not include.
> Tested with: **sing-box-extended 1.13.11-extended-2.1.0**

---

### Installation

```sh
sh <(wget -O - https://raw.githubusercontent.com/moix89/podkop-xhttp-patch/main/install.sh)
```

#### What the installer does

| Step | Action |
|------|--------|
| 1 | Verifies `/usr/lib/podkop/sing_box_config_facade.sh` exists |
| 2 | Verifies `jq` is available |
| 3 | Creates a timestamped backup: `/root/sing_box_config_facade.sh.backup.YYYYMMDD_HHMMSS` |
| 4 | Checks if the patch is already installed — safe to re-run |
| 5 | Inserts the `xhttp)` block before `*)` inside `_add_outbound_transport()` |
| 6 | Runs `sh -n` syntax check on the patched file |
| 7 | Restarts Podkop |

The script is **idempotent** — running it twice prints `Patch already installed.`

---

### What the patch does

Inserts an `xhttp)` block into `_add_outbound_transport()` right after the `grpc)` block:

1. Reads `path` and `host` from the VLESS URL query string
1. Generates the `transport` object in the sing-box config:

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

1. Automatically sets TLS ALPN to `["h2", "http/1.1"]`

This enables Podkop to use multiple `vless://...type=xhttp...` links in **URLTest** mode with automatic server failover.

---

### Verification

```sh
# Syntax check
sh -n /usr/lib/podkop/sing_box_config_facade.sh

# Restart Podkop manually if needed
/etc/init.d/podkop restart

# Check URLTest outbound
jq '.outbounds[] | select(.type=="urltest")' /etc/sing-box/config.json

# Check xHTTP outbound
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json
```

Expected output:

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

### Compatibility

| Component | Version |
|-----------|---------|
| OpenWrt | 25.12.2 |
| Podkop | 0.7.17 |
| sing-box-extended | 1.13.11-extended-2.1.0 |
| Protocol | VLESS Reality XHTTP |
| Mode | URLTest failover |

---

### After Podkop updates

If Podkop is updated via `opkg`, the original file is overwritten and the patch is lost. Simply re-run the install command to re-apply it.

---

### Uninstall / rollback

```sh
# List backups
ls /root/sing_box_config_facade.sh.backup.*

# Restore (replace timestamp with actual filename)
cp /root/sing_box_config_facade.sh.backup.20250101_120000 \
   /usr/lib/podkop/sing_box_config_facade.sh
/etc/init.d/podkop restart
```

---

### How it works

The `awk`-based installer locates the `*)` wildcard that immediately follows the `grpc ;;` closing line and inserts the new block before it:

```text
grpc)   ...  ;;
xhttp)  ...  ;;   <- inserted here
*)      log "Unknown transport..."
```

---

### License

MIT — see [LICENSE](LICENSE).

---

---

# Русский

## podkop-xhttp-patch

Патч одной командой, который добавляет поддержку **xHTTP transport** в [Podkop](https://github.com/itdoginfo/podkop), чтобы `URLTest` работал со ссылками `vless://...type=xhttp...` на OpenWrt.

### Проблема

Podkop падает с ошибкой:

```text
Unknown transport 'xhttp' detected.
```

**Причина:** в функции `_add_outbound_transport()` файла `/usr/lib/podkop/sing_box_config_facade.sh` отсутствует ветка `xhttp)` в `case`-блоке.

---

### Требования

Перед установкой патча убедитесь, что установлен **sing-box-extended** — он необходим для поддержки xHTTP transport.

Установить sing-box-extended одной командой:

```sh
sh <(wget -O - https://raw.githubusercontent.com/EikeiDev/OpenWRT-sing-box-extended/refs/heads/main/install.sh)
```

> sing-box-extended добавляет xHTTP, XUDP и другие современные транспорты, которых нет в стандартном пакете sing-box.
> Проверено с: **sing-box-extended 1.13.11-extended-2.1.0**

---

### Установка

```sh
sh <(wget -O - https://raw.githubusercontent.com/moix89/podkop-xhttp-patch/main/install.sh)
```

#### Что делает установщик

| Шаг | Действие |
|-----|----------|
| 1 | Проверяет наличие `/usr/lib/podkop/sing_box_config_facade.sh` |
| 2 | Проверяет наличие `jq` |
| 3 | Создаёт backup с временной меткой: `/root/sing_box_config_facade.sh.backup.YYYYMMDD_HHMMSS` |
| 4 | Проверяет, установлен ли патч уже — безопасно запускать повторно |
| 5 | Вставляет блок `xhttp)` перед `*)` внутри `_add_outbound_transport()` |
| 6 | Проверяет синтаксис через `sh -n` |
| 7 | Перезапускает Podkop |

Скрипт **идемпотентен** — повторный запуск выведет `Patch already installed.`

---

### Что делает патч

Добавляет ветку `xhttp)` в `_add_outbound_transport()` сразу после блока `grpc)`:

1. Читает `path` и `host` из query-параметров VLESS-ссылки
1. Генерирует объект `transport` в конфиге sing-box:

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

1. Автоматически выставляет TLS ALPN в `["h2", "http/1.1"]`

После патча Podkop может использовать несколько `vless://...type=xhttp...` ссылок в режиме **URLTest** с автоматическим переключением между серверами.

---

### Проверка

```sh
# Синтаксис-проверка
sh -n /usr/lib/podkop/sing_box_config_facade.sh

# Ручной перезапуск Podkop
/etc/init.d/podkop restart

# Проверить URLTest outbound
jq '.outbounds[] | select(.type=="urltest")' /etc/sing-box/config.json

# Проверить xHTTP outbound
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json
```

Ожидаемый вывод:

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

### Совместимость

| Компонент | Версия |
|-----------|--------|
| OpenWrt | 25.12.2 |
| Podkop | 0.7.17 |
| sing-box-extended | 1.13.11-extended-2.1.0 |
| Протокол | VLESS Reality XHTTP |
| Режим | URLTest failover |

---

### После обновления Podkop

Если Podkop обновляется через `opkg`, оригинальный файл перезаписывается и патч слетает. Просто запустите команду установки снова — патч переустановится.

---

### Откат / удаление патча

```sh
# Список backup-файлов
ls /root/sing_box_config_facade.sh.backup.*

# Восстановить (подставьте реальное имя файла)
cp /root/sing_box_config_facade.sh.backup.20250101_120000 \
   /usr/lib/podkop/sing_box_config_facade.sh
/etc/init.d/podkop restart
```

---

### Как это работает

Установщик на `awk` находит `*)` (wildcard), стоящий сразу после закрывающего `;;` блока `grpc)`, и вставляет новый блок перед ним:

```text
grpc)   ...  ;;
xhttp)  ...  ;;   <- вставляется здесь
*)      log "Unknown transport..."
```

---

### Лицензия

MIT — см. [LICENSE](LICENSE).
