# podkop-xhttp-patch

[English](#english) | [Русский](#русский)

---

## English

One-command patch that fixes issues in [Podkop](https://github.com/itdoginfo/podkop) when using `vless://...type=xhttp...` links with **URLTest** on OpenWrt + sing-box-extended.

---

### Quick start

> Run all commands over SSH on your OpenWrt router.

#### Step 1 — Connect to the router

```sh
ssh root@192.168.1.1
```

> Replace `192.168.1.1` with your router's actual IP.
> Xiaomi AX6S default gateway is `192.168.31.1`.

#### Step 2 — Install sing-box-extended

Replaces the stock sing-box with an extended build that includes xHTTP transport:

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

Expected output:

```text
✅ Sing-box version is compatible (newer than 1.12.4)
```

After adding `vless://...type=xhttp...` links in Podkop, confirm the config was generated:

```sh
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json
```

---

### What it fixes

**Fix 1 — `sing_box_config_facade.sh`**
Adds the `xhttp)` transport branch. Without it Podkop crashes with `Unknown transport 'xhttp' detected`.

**Fix 2 — `/usr/bin/podkop`**
Strips the `-extended-2.x.x` suffix before version comparison so `1.13.11-extended-2.1.0` is parsed as `1.13.11`.

**Fix 3 — `/usr/bin/podkop`**
Replaces the subshell `(...)` comparison with POSIX-safe `{ ...; }` so the version check works correctly in `/bin/sh`.

After fixes 2+3, `podkop global_check` shows green instead of a false version error.

---

### What the installer does

1. Checks for `jq`, `sed`, `awk`, `sing-box`, and both Podkop files
1. Creates timestamped backups in `/root/`
1. Inserts or upgrades the `xhttp)` block in `_add_outbound_transport`
1. Patches version string parsing in `check_requirements` and `check_sing_box`
1. Patches version comparison to use POSIX-safe `{ ...; }` form
1. Runs `sh -n` syntax check on both patched files
1. Restarts Podkop
1. Prints verification commands

The script is **idempotent** — re-running it is safe. Each patch checks its marker before applying.

---

### Generated sing-box transport config

For a `vless://...type=xhttp...` link Podkop will produce:

```json
"transport": {
  "type": "xhttp",
  "path": "/api/v1/files",
  "mode": "auto",
  "host": "example.com",
  "x_padding_bytes": "100-1000",
  "sc_max_each_post_bytes": "1000000",
  "sc_min_posts_interval_ms": "30"
}
```

TLS ALPN is set automatically to `["h2", "http/1.1"]`.

---

### Verification commands

```sh
sing-box version
podkop global_check
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json
jq '.outbounds[] | select(.type=="urltest")' /etc/sing-box/config.json
```

---

### Compatibility

| Component         | Version                |
|-------------------|------------------------|
| OpenWrt           | 25.12.2                |
| Router            | Xiaomi Redmi AX6S      |
| Podkop            | 0.7.17                 |
| LuCI App Podkop   | 0.7.17                 |
| sing-box-extended | 1.13.11-extended-2.1.0 |
| Protocol          | VLESS Reality XHTTP    |
| Mode              | URLTest failover       |

---

### After Podkop updates

If Podkop is updated via `opkg`, both files are overwritten and patches are lost. Re-run the install command to re-apply.

---

### Rollback

```sh
ls /root/*.backup.*

cp /root/sing_box_config_facade.sh.backup.20250101_120000 \
   /usr/lib/podkop/sing_box_config_facade.sh

cp /root/podkop.backup.20250101_120000 /usr/bin/podkop

/etc/init.d/podkop restart
```

---

### License

MIT — see [LICENSE](LICENSE).

---

## Русский

Патч одной командой, который устраняет баги в [Podkop](https://github.com/itdoginfo/podkop) при использовании ссылок `vless://...type=xhttp...` с **URLTest** на OpenWrt + sing-box-extended.

---

### Быстрый старт

> Все команды выполняются на роутере через SSH.

#### Шаг 1 — Подключиться к роутеру

С компьютера в терминале:

```sh
ssh root@192.168.1.1
```

> Замените `192.168.1.1` на IP вашего роутера.
> У Xiaomi AX6S стандартный адрес `192.168.31.1`.

#### Шаг 2 — Установить sing-box-extended

Заменяет стандартный sing-box на расширенную версию с поддержкой xHTTP:

```sh
wget -O /tmp/sb-ext.sh https://raw.githubusercontent.com/EikeiDev/OpenWRT-sing-box-extended/refs/heads/main/install.sh && sh /tmp/sb-ext.sh
```

#### Шаг 3 — Установить патч

```sh
wget -O /tmp/patch.sh https://raw.githubusercontent.com/moix89/podkop-xhttp-patch/main/install.sh && sh /tmp/patch.sh
```

#### Шаг 4 — Проверить

```sh
podkop global_check
```

Ожидаемый результат:

```text
✅ Sing-box version is compatible (newer than 1.12.4)
```

> Текст `(newer than 1.12.4)` — это название условия совместимости, не номер версии. Фактическая версия видна в выводе `podkop global_check`.

После добавления ссылок `vless://...type=xhttp...` в Podkop — проверить конфиг:

```sh
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json
```

---

### Что исправляет

**Исправление 1 — `sing_box_config_facade.sh`**
Добавляет ветку `xhttp)`. Без неё Podkop падает с ошибкой `Unknown transport 'xhttp' detected`.

**Исправление 2 — `/usr/bin/podkop`**
Обрезает суффикс `-extended-2.x.x` перед сравнением версий, чтобы `1.13.11-extended-2.1.0` читалось как `1.13.11`.

**Исправление 3 — `/usr/bin/podkop`**
Заменяет `(...)` в сравнении версии на POSIX-совместимый `{ ...; }` для корректной работы в `/bin/sh`.

После исправлений 2+3 `podkop global_check` показывает зелёный статус вместо ложной ошибки.

---

### Что делает установщик

1. Проверяет наличие `jq`, `sed`, `awk`, `sing-box` и обоих файлов Podkop
1. Создаёт backup с timestamp в `/root/`
1. Вставляет или обновляет блок `xhttp)` в `_add_outbound_transport`
1. Патчит парсинг версии в `check_requirements` и `check_sing_box`
1. Патчит сравнение версии: заменяет `(...)` на `{ ...; }`
1. Проверяет синтаксис обоих файлов через `sh -n`
1. Перезапускает Podkop
1. Выводит команды для проверки

Скрипт **идемпотентен** — повторный запуск безопасен.

---

### Генерируемый конфиг sing-box

Для ссылки `vless://...type=xhttp...` Podkop генерирует:

```json
"transport": {
  "type": "xhttp",
  "path": "/api/v1/files",
  "mode": "auto",
  "host": "example.com",
  "x_padding_bytes": "100-1000",
  "sc_max_each_post_bytes": "1000000",
  "sc_min_posts_interval_ms": "30"
}
```

TLS ALPN выставляется автоматически в `["h2", "http/1.1"]`.

---

### Команды проверки

```sh
sing-box version
podkop global_check
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json
jq '.outbounds[] | select(.type=="urltest")' /etc/sing-box/config.json
```

---

### Совместимость

| Компонент         | Версия                 |
|-------------------|------------------------|
| OpenWrt           | 25.12.2                |
| Роутер            | Xiaomi Redmi AX6S      |
| Podkop            | 0.7.17                 |
| LuCI App Podkop   | 0.7.17                 |
| sing-box-extended | 1.13.11-extended-2.1.0 |
| Протокол          | VLESS Reality XHTTP    |
| Режим             | URLTest failover       |

---

### После обновления Podkop

Если Podkop обновляется через `opkg`, оба файла перезаписываются и патчи слетают. Достаточно снова запустить команду установки.

---

### Откат

```sh
ls /root/*.backup.*

cp /root/sing_box_config_facade.sh.backup.20250101_120000 \
   /usr/lib/podkop/sing_box_config_facade.sh

cp /root/podkop.backup.20250101_120000 /usr/bin/podkop

/etc/init.d/podkop restart
```

---

### Лицензия

MIT — см. [LICENSE](LICENSE).
