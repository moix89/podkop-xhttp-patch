# podkop-xhttp-patch

[Русский](#русский) | [English](#english)

---

## Русский

Патч одной командой — добавляет полную поддержку **VLESS Reality XHTTP** в [Podkop](https://github.com/itdoginfo/podkop) на OpenWrt + sing-box-extended.

---

> [!CAUTION]
> **ВНИМАНИЕ: ПРОВЕРЬТЕ ВЕРСИИ ПЕРЕД УСТАНОВКОЙ**
>
> Патч разработан и протестирован **строго** для этих версий:
>
> - OpenWrt **25.12.2**
> - Podkop **0.7.17**
> - LuCI App Podkop **0.7.17**
> - sing-box-extended **1.13.11-extended-2.1.0**
>
> Перед установкой проверьте свои версии:
>
> ```sh
> cat /etc/openwrt_release | grep VERSION
> opkg list-installed | grep podkop
> sing-box version
> ```
>
> Если ваши версии **отличаются** — патч может не примениться, примениться неправильно и сломать Podkop, или потребовать ручной доработки.
>
> При обновлении Podkop через `opkg` патч **слетает** — нужно запустить установку повторно.

---

### Быстрый старт

> Все команды выполняются на роутере через SSH.

#### Шаг 1 — Подключиться к роутеру

С компьютера в терминале:

```sh
ssh root@192.168.1.1
```

> Замените `192.168.1.1` на IP вашего роутера.
> Xiaomi AX6S: стандартный адрес `192.168.31.1`.

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
sing-box check -c /etc/sing-box/config.json
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json
jq '.outbounds[] | select(.type=="urltest")' /etc/sing-box/config.json
```

---

### Что исправляет

**Исправление 1 — xhttp transport** (`sing_box_config_facade.sh`)

Добавляет ветку `xhttp)` в `_add_outbound_transport()`. Без неё Podkop падает с `Unknown transport 'xhttp' detected`. Параметры читаются из VLESS URL с дефолтами:

- `path` — из `path=`
- `host` — из `host=`
- `mode` — из `mode=`, дефолт: `auto`
- `x_padding_bytes` — из `xPaddingBytes=` или `extra.xPaddingBytes`, дефолт: `100-1000`
- `sc_max_each_post_bytes` — из `extra.scMaxEachPostBytes`, дефолт: `1000000`
- `sc_min_posts_interval_ms` — из `extra.scMinPostsIntervalMs`, дефолт: `30`
- `alpn` — из `alpn=`, дефолт: `h2,http/1.1`

**Исправление 2 — spider_x для Reality** (`sing_box_config_facade.sh`)

Парсит `spx` из VLESS URL и записывает в `tls.reality.spider_x`. Без этого поле всегда отсутствует в конфиге.

- `spx=%2F` → `"spider_x": "/"`
- `spx=%2Fabc123` → `"spider_x": "/abc123"`
- `spx` отсутствует → `"spider_x": "/"`

Патч берёт значение из ссылки как есть — **не принудительно заменяет** на `/`.

**Исправление 3 — версия sing-box-extended** (`/usr/bin/podkop`)

Обрезает суффикс `-extended-2.x.x`, чтобы `1.13.11-extended-2.1.0` читалось как `1.13.11`. Заменяет `(...)` в сравнении версии на POSIX-совместимый `{ ...; }`. После этого `podkop global_check` показывает зелёный статус вместо ложной ошибки.

> Текст `(newer than 1.12.4)` — это название условия совместимости, не номер версии. Фактическая версия видна в выводе `podkop global_check`.

---

### Генерируемый конфиг

```json
{
  "type": "vless",
  "tag": "...",
  "tls": {
    "alpn": ["h2", "http/1.1"],
    "reality": {
      "enabled": true,
      "public_key": "...",
      "short_id": "...",
      "spider_x": "/"
    }
  },
  "transport": {
    "type": "xhttp",
    "path": "/v1/api",
    "mode": "auto",
    "host": "example.com",
    "x_padding_bytes": "100-1000",
    "sc_max_each_post_bytes": "1000000",
    "sc_min_posts_interval_ms": "30"
  }
}
```

---

### Как работает установщик

1. Проверяет наличие `jq`, `sed`, `awk`, `sing-box` и обоих файлов Podkop
1. Создаёт backup с timestamp в `/root/`
1. Вставляет или обновляет блок `xhttp)` (маркер: `sc_min_posts_interval_ms`)
1. Добавляет парсинг `spider_x` после `_add_outbound_security` в ветке `vless)` (маркер: `spider_x`)
1. Патчит парсинг версии в `check_requirements` и `check_sing_box` (маркер: `cut -d'-' -f1`)
1. Патчит сравнение версии: заменяет `(...)` на `{ ...; }`
1. Проверяет синтаксис обоих файлов через `sh -n`
1. Перезапускает Podkop
1. Выводит команды для проверки

Скрипт **идемпотентен** — повторный запуск безопасен, каждый патч проверяет свой маркер.

---

### Откат

```sh
ls /root/*.backup.*
cp /root/sing_box_config_facade.sh.backup.TIMESTAMP /usr/lib/podkop/sing_box_config_facade.sh
cp /root/podkop.backup.TIMESTAMP /usr/bin/podkop
/etc/init.d/podkop restart
```

---

### Лицензия

MIT — см. [LICENSE](LICENSE).

---

## English

One-command patch that adds full **VLESS Reality XHTTP** support to [Podkop](https://github.com/itdoginfo/podkop) on OpenWrt + sing-box-extended.

---

> [!CAUTION]
> **WARNING: CHECK YOUR VERSIONS BEFORE INSTALLING**
>
> This patch was developed and tested **only** for these specific versions:
>
> - OpenWrt **25.12.2**
> - Podkop **0.7.17**
> - LuCI App Podkop **0.7.17**
> - sing-box-extended **1.13.11-extended-2.1.0**
>
> Check your versions before installing:
>
> ```sh
> cat /etc/openwrt_release | grep VERSION
> opkg list-installed | grep podkop
> sing-box version
> ```
>
> If your versions **differ** — the patch may fail to apply, apply incorrectly and break Podkop, or require manual adjustment.
>
> When Podkop is updated via `opkg`, the patch is **overwritten** — re-run the installer to re-apply.

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
sing-box check -c /etc/sing-box/config.json
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json
jq '.outbounds[] | select(.type=="urltest")' /etc/sing-box/config.json
```

---

### What it fixes

**Fix 1 — xhttp transport** (`sing_box_config_facade.sh`)

Adds the `xhttp)` branch to `_add_outbound_transport()`. Without it Podkop crashes with `Unknown transport 'xhttp' detected`. Parameters are read from the VLESS URL with fallback defaults:

- `path` — from `path=`
- `host` — from `host=`
- `mode` — from `mode=`, default: `auto`
- `x_padding_bytes` — from `xPaddingBytes=` or `extra.xPaddingBytes`, default: `100-1000`
- `sc_max_each_post_bytes` — from `extra.scMaxEachPostBytes`, default: `1000000`
- `sc_min_posts_interval_ms` — from `extra.scMinPostsIntervalMs`, default: `30`
- `alpn` — from `alpn=`, default: `h2,http/1.1`

**Fix 2 — spider_x for Reality** (`sing_box_config_facade.sh`)

Parses `spx` from the VLESS URL and writes it to `tls.reality.spider_x`. Without this fix `spider_x` is always missing.

- `spx=%2F` → `"spider_x": "/"`
- `spx=%2Fabc123` → `"spider_x": "/abc123"`
- `spx` absent → `"spider_x": "/"`

The patch uses the value from the link as-is — does **not** force `/`.

**Fix 3 — sing-box-extended version detection** (`/usr/bin/podkop`)

Strips `-extended-2.x.x` suffix so `1.13.11-extended-2.1.0` is parsed as `1.13.11`. Also replaces subshell `(...)` comparison with POSIX-safe `{ ...; }`. After this `podkop global_check` shows green.

---

### Generated sing-box config

```json
{
  "type": "vless",
  "tag": "...",
  "tls": {
    "alpn": ["h2", "http/1.1"],
    "reality": {
      "enabled": true,
      "public_key": "...",
      "short_id": "...",
      "spider_x": "/"
    }
  },
  "transport": {
    "type": "xhttp",
    "path": "/v1/api",
    "mode": "auto",
    "host": "example.com",
    "x_padding_bytes": "100-1000",
    "sc_max_each_post_bytes": "1000000",
    "sc_min_posts_interval_ms": "30"
  }
}
```

---

### After Podkop updates

If Podkop is updated via `opkg`, both files are overwritten and patches are lost. Re-run the install command to re-apply.

---

### Rollback

```sh
ls /root/*.backup.*
cp /root/sing_box_config_facade.sh.backup.TIMESTAMP /usr/lib/podkop/sing_box_config_facade.sh
cp /root/podkop.backup.TIMESTAMP /usr/bin/podkop
/etc/init.d/podkop restart
```

---

### License

MIT — see [LICENSE](LICENSE).
