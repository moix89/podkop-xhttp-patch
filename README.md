[English](#english) | [Русский](#русский)

---

# English

## podkop-xhttp-patch

One-command patch that fixes two issues in [Podkop](https://github.com/itdoginfo/podkop) when using `vless://...type=xhttp...` links with **URLTest** on OpenWrt + sing-box-extended.

---

### Quick start (step by step)

> Run all commands over SSH on your OpenWrt router.

#### Step 1 — Connect to the router

```sh
ssh root@192.168.1.1
```

#### Step 2 — Install sing-box-extended (replaces the stock sing-box, adds xHTTP support)

```sh
wget -O /tmp/sb-ext.sh https://raw.githubusercontent.com/EikeiDev/OpenWRT-sing-box-extended/refs/heads/main/install.sh && sh /tmp/sb-ext.sh
```

#### Step 3 — Install this patch

```sh
wget -O /tmp/patch.sh https://raw.githubusercontent.com/moix89/podkop-xhttp-patch/main/install.sh && sh /tmp/patch.sh
```

#### Step 4 — Verify

```sh
podkop global_check
```

Expected result:

```text
✅ Sing-box version is compatible (newer than 1.12.4)
```

After adding your `vless://...type=xhttp...` links in Podkop, confirm the config was generated:

```sh
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json
```

---

### What it fixes

| # | File | Fix |
|---|------|-----|
| 1 | `/usr/lib/podkop/sing_box_config_facade.sh` | Adds `xhttp)` transport branch — without it Podkop crashes with `Unknown transport 'xhttp' detected` |
| 2 | `/usr/bin/podkop` | Strips `-extended-2.x.x` suffix before version comparison so `1.13.11-extended-2.1.0` is parsed as `1.13.11` |
| 3 | `/usr/bin/podkop` | Replaces subshell `(...)` comparison with POSIX-safe `{ ...; }` so the version check works in `/bin/sh` |

After patch 2+3 `podkop global_check` shows:

```text
✅ Sing-box version is compatible (newer than 1.12.4)
```

instead of the false red error.

---

### Prerequisites

Install **sing-box-extended** first — it provides the xHTTP transport engine that the stock `sing-box` package does not include:

```sh
sh <(wget -O - https://raw.githubusercontent.com/EikeiDev/OpenWRT-sing-box-extended/refs/heads/main/install.sh)
```

> Tested with: sing-box-extended **1.13.11-extended-2.1.0**

---

### Installation

**Option 1 — one-liner** (requires process substitution, works on most shells):

```sh
sh <(wget -O - https://raw.githubusercontent.com/moix89/podkop-xhttp-patch/main/install.sh)
```

**Option 2 — explicit download** (always works on OpenWrt `ash`):

```sh
wget -O /tmp/podkop-xhttp-install.sh \
  https://raw.githubusercontent.com/moix89/podkop-xhttp-patch/main/install.sh
sh /tmp/podkop-xhttp-install.sh
```

---

### What the installer does

| Step | Action |
|------|--------|
| 1 | Checks for `jq`, `sed`, `awk`, `sing-box`, both Podkop files |
| 2 | Creates timestamped backups in `/root/` |
| 3 | Inserts `xhttp)` block before `*)` in `_add_outbound_transport()` |
| 4 | Patches version string parsing in `check_requirements()` and `check_sing_box()` |
| 5 | Patches version comparison to use POSIX-safe `{ ...; }` form |
| 6 | Runs `sh -n` syntax check on both patched files |
| 7 | Restarts Podkop |
| 8 | Prints verification commands |

The script is **idempotent** — re-running it is safe and prints `already installed, skipping` for each applied patch.

---

### Generated sing-box config

For a `vless://...type=xhttp...` link Podkop will now produce:

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

and automatically sets TLS ALPN to `["h2", "http/1.1"]`.

---

### Verification

```sh
# Check sing-box version detection
sing-box version
podkop global_check

# Check xHTTP outbound was generated
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json

# Check URLTest outbound
jq '.outbounds[] | select(.type=="urltest")' /etc/sing-box/config.json
```

---

### Compatibility

| Component | Version |
|-----------|---------|
| OpenWrt | 25.12.2 |
| Router | Xiaomi Redmi AX6S |
| Podkop | 0.7.17 |
| LuCI App Podkop | 0.7.17 |
| sing-box-extended | 1.13.11-extended-2.1.0 |
| Protocol | VLESS Reality XHTTP |
| Mode | URLTest failover |

---

### After Podkop updates

If Podkop is updated via `opkg`, both files are overwritten and the patches are lost. Re-run the install command to re-apply them.

---

### Rollback

```sh
# List backups
ls /root/*.backup.*

# Restore facade (replace timestamp)
cp /root/sing_box_config_facade.sh.backup.20250101_120000 \
   /usr/lib/podkop/sing_box_config_facade.sh

# Restore podkop binary
cp /root/podkop.backup.20250101_120000 /usr/bin/podkop

/etc/init.d/podkop restart
```

---

### License

MIT — see [LICENSE](LICENSE).

---

---

# Русский

## podkop-xhttp-patch

Патч одной командой, который устраняет два бага в [Podkop](https://github.com/itdoginfo/podkop) при использовании ссылок `vless://...type=xhttp...` с **URLTest** на OpenWrt + sing-box-extended.

### Что исправляет

| # | Файл | Исправление |
|---|------|-------------|
| 1 | `/usr/lib/podkop/sing_box_config_facade.sh` | Добавляет ветку `xhttp)` — без неё Podkop падает с `Unknown transport 'xhttp' detected` |
| 2 | `/usr/bin/podkop` | Обрезает суффикс `-extended-2.x.x` перед сравнением версий, чтобы `1.13.11-extended-2.1.0` читалось как `1.13.11` |
| 3 | `/usr/bin/podkop` | Заменяет подоболочку `(...)` в сравнении версии на POSIX-совместимую форму `{ ...; }` |

После патчей 2+3 команда `podkop global_check` показывает:

```text
✅ Sing-box version is compatible (newer than 1.12.4)
```

вместо ложной красной ошибки.

> **Примечание:** текст `(newer than 1.12.4)` — это название условия совместимости, а не номер установленной версии. Фактическая версия отображается в выводе `podkop global_check`.

---

### Требования

Сначала установите **sing-box-extended** — он обеспечивает движок xHTTP transport, которого нет в стандартном пакете `sing-box`:

```sh
sh <(wget -O - https://raw.githubusercontent.com/EikeiDev/OpenWRT-sing-box-extended/refs/heads/main/install.sh)
```

> Проверено с: sing-box-extended **1.13.11-extended-2.1.0**

---

### Установка

**Вариант 1 — однострочник** (требует подстановки процессов, работает в большинстве оболочек):

```sh
sh <(wget -O - https://raw.githubusercontent.com/moix89/podkop-xhttp-patch/main/install.sh)
```

**Вариант 2 — явное скачивание** (всегда работает на `ash` в OpenWrt):

```sh
wget -O /tmp/podkop-xhttp-install.sh \
  https://raw.githubusercontent.com/moix89/podkop-xhttp-patch/main/install.sh
sh /tmp/podkop-xhttp-install.sh
```

---

### Что делает установщик

| Шаг | Действие |
|-----|----------|
| 1 | Проверяет наличие `jq`, `sed`, `awk`, `sing-box` и обоих файлов Podkop |
| 2 | Создаёт backup с timestamp в `/root/` |
| 3 | Вставляет блок `xhttp)` перед `*)` в `_add_outbound_transport()` |
| 4 | Патчит парсинг версии в `check_requirements()` и `check_sing_box()` |
| 5 | Патчит сравнение версии: заменяет `(...)` на POSIX-совместимый `{ ...; }` |
| 6 | Проверяет синтаксис обоих файлов через `sh -n` |
| 7 | Перезапускает Podkop |
| 8 | Выводит команды для проверки |

Скрипт **идемпотентен** — повторный запуск безопасен, для каждого уже применённого патча выводит `already installed, skipping`.

---

### Генерируемый конфиг sing-box

Для ссылки `vless://...type=xhttp...` Podkop теперь генерирует:

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

и автоматически выставляет TLS ALPN в `["h2", "http/1.1"]`.

---

### Проверка

```sh
# Проверить определение версии sing-box
sing-box version
podkop global_check

# Проверить xHTTP outbound в конфиге
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json

# Проверить URLTest outbound
jq '.outbounds[] | select(.type=="urltest")' /etc/sing-box/config.json
```

---

### Совместимость

| Компонент | Версия |
|-----------|--------|
| OpenWrt | 25.12.2 |
| Роутер | Xiaomi Redmi AX6S |
| Podkop | 0.7.17 |
| LuCI App Podkop | 0.7.17 |
| sing-box-extended | 1.13.11-extended-2.1.0 |
| Протокол | VLESS Reality XHTTP |
| Режим | URLTest failover |

---

### После обновления Podkop

Если Podkop обновляется через `opkg`, оба файла перезаписываются и патчи слетают. Достаточно снова запустить команду установки.

---

### Откат

```sh
# Список backup-файлов
ls /root/*.backup.*

# Восстановить sing_box_config_facade.sh (подставьте timestamp)
cp /root/sing_box_config_facade.sh.backup.20250101_120000 \
   /usr/lib/podkop/sing_box_config_facade.sh

# Восстановить podkop
cp /root/podkop.backup.20250101_120000 /usr/bin/podkop

/etc/init.d/podkop restart
```

---

### Лицензия

MIT — см. [LICENSE](LICENSE).
