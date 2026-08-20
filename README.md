# podkop-xhttp-patch

[Русский](#русский) | [English](#english)

---

## Русский

Патч одной командой — добавляет полную поддержку **VLESS Reality XHTTP** в [Podkop](https://github.com/itdoginfo/podkop) на OpenWrt + sing-box-extended.

---

### Что нового (2026-08-20)

Апстрим Podkop дошёл до версии **0.7.22** и по пути (18.08.2026) переписал функцию `check_sing_box()`, заменив собственный баговый разбор версии sing-box на общую `is_min_package_version()`. Это ровно та проблема, которую раньше чинил патч 3/4 в этом репозитории точечной заменой строк — на новых версиях Podkop точечный фикс просто не находил свою цель.

- Патч теперь **автоматически определяет**, какая версия `check_sing_box()` установлена, и:
  - на Podkop **0.7.17–0.7.21** — заменяет весь баговый блок сравнения версии на исправленный вариант (тот же, что и в 0.7.22);
  - на Podkop **0.7.22+** — ничего не делает, апстрим уже всё исправил сам.
- Транспорт `xhttp` **по-прежнему не поддерживается нативно** ни в одной версии Podkop, включая 0.7.22 и main (мейнтейнеры закрыли feature-запрос как invalid) — патч 1 (вставка блока `xhttp)`) нужен и применяется всегда, независимо от версии.
- Убран жёсткий список поддерживаемых версий (раньше патч предупреждал на всём, что не `0.7.17`/`0.7.18`) — теперь предупреждение показывается только если версию вообще не удалось определить.
- Добавлена поддержка `apk` для определения версии Podkop (OpenWrt 24.10+ использует `apk` вместо `opkg`).

**Официально протестировано:** Podkop 0.7.17 – 0.7.22 (подробности — в блоке ниже и в разделе «Протестировано на»).

---

> [!CAUTION]
> **ВНИМАНИЕ: ПРОВЕРЬТЕ ВЕРСИИ ПЕРЕД УСТАНОВКОЙ**
>
> Патч поддерживает Podkop **0.7.17 – 0.7.22** (актуальный релиз апстрима на 2026-08-20).
> В upstream-репозитории [itdoginfo/podkop](https://github.com/itdoginfo/podkop) транспорт
> `xhttp` **не поддерживается нативно ни в одной версии** (включая 0.7.22 и main) — патч 1
> нужен всегда. Логика проверки версии sing-box (патч 3/4) детектируется автоматически:
> на 0.7.17–0.7.21 заменяется баговый ручной код сравнения версий на исправленный вариант
> из 0.7.22; на 0.7.22+ (где апстрим уже поправил это сам) патч ничего не делает.
>
> Патч протестирован на следующих конфигурациях:
>
> **OpenWrt 25.12.2 r32802-f505120278:**
> - Podkop **0.7.18**
> - LuCI App Podkop **0.7.18** (branch 26.082.75780~067535e)
> - sing-box-extended **1.13.12-extended-2.1.3**
>
> **OpenWrt 24.10.3 r28872-daca7c049b:**
> - Podkop **0.7.17**
> - LuCI App Podkop **0.7.14** (branch 25.250.61039~923f8d9)
> - sing-box-extended **1.13.12-extended-2.3.0**
>
> Перед установкой проверьте свои версии:
>
> ```sh
> cat /etc/openwrt_release | grep VERSION
> apk list -I | grep podkop   # OpenWrt 24.10+ (apk)
> opkg list-installed | grep podkop   # старые прошивки (opkg)
> sing-box version
> ```
>
> Если версия Podkop новее 0.7.22 — патч всё равно попытается применить xhttp-блок
> (он ещё не появился в апстриме на момент написания) и молча пропустит патч версии,
> если апстрим его уже поправил. Если структура файлов Podkop изменится кардинально —
> патч сообщит об ошибке, а не сломает файл молча.
>
> При обновлении Podkop через `opkg`/`apk` патч **слетает** — нужно запустить установку повторно.

---

> [!WARNING]
> **Важно: постквантовое шифрование не поддерживается**
>
> Podkop **не поддерживает** `encryption=mlkem768x25519plus` и другие постквантовые алгоритмы.
> Если ваша ссылка содержит этот параметр — соединение не установится, пинг будет N/A.
>
> В панели сервера (3x-ui и др.) на вкладке **Протокол** установите **Шифрование = none**, кнопку **Очистить** — убрать выбранные алгоритмы. Ссылка должна содержать `encryption=none`.

---

> [!WARNING]
> ⚠️ **Отказ от ответственности**
>
> Скрипт предоставляется «как есть». Рекомендуется ознакомиться с кодом перед запуском.

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

#### Шаг 4 — Настроить ссылку в 3x-ui

**Вкладка Протокол:**

- Шифрование: `none`
- Нажать **Очистить** — убрать X25519 и ML-KEM-768

**Вкладка Поток:**

- Транспорт: `XHTTP`
- Режим: `auto`
- Padding Bytes: `100-1000`

**Вкладка Безопасность:**

- Тип: `Reality`
- uTLS: `chrome`

Скопировать ссылку — она должна содержать `encryption=none&...type=xhttp`.

#### Шаг 5 — Добавить ссылку в Podkop

В LuCI → Podkop создать секцию с типом подключения **URL** или **URLTest**, вставить ссылку.

#### Шаг 6 — Проверить

```sh
podkop global_check
sing-box check -c /etc/sing-box/config.json
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json
```

---

### Что исправляет патч

**Исправление 1 — xhttp transport** (`sing_box_config_facade.sh`)

Добавляет ветку `xhttp)` в `_add_outbound_transport()`. Без неё Podkop падает с `Unknown transport 'xhttp' detected`. Параметры читаются из VLESS URL с дефолтами:

- `path` — из `path=`
- `host` — из `host=`
- `mode` — из `mode=`, дефолт: `auto`
- `x_padding_bytes` — из `xPaddingBytes=` или `extra.xPaddingBytes`, дефолт: `100-1000`
- `sc_max_each_post_bytes` — из `extra.scMaxEachPostBytes`, дефолт: `"1000000"` (строка)
- `sc_min_posts_interval_ms` — из `extra.scMinPostsIntervalMs`, дефолт: `"30"` (строка)
- `alpn` — из `alpn=`, дефолт: `h2,http/1.1`

**Исправление 2 — версия sing-box-extended** (`/usr/bin/podkop`, функция `check_sing_box()`)

В Podkop 0.7.17–0.7.21 эта функция сравнивает версию sing-box вручную через `cut -d. -f1/2/3` и цепочку `[ A ] || [ B ] && [ C ]`. В POSIX ash `&&` связывает сильнее `||`, поэтому условие срабатывает некорректно; вдобавок суффикс `-extended-2.1.3` ломает `cut -d. -f3` (нечисловое значение). В итоге `podkop global_check`/LuCI показывает sing-box как несовместимый, даже если он работает.

Патч заменяет тело `check_sing_box()` на версию, которую сам апстрим Podkop внедрил в **0.7.22** — через общую функцию `is_min_package_version()` (сравнение через `sort -V`, устойчива к суффиксу `-extended-...`). На Podkop 0.7.22+ этот код уже стоит из коробки, патч это определяет и ничего не делает.

> Функция `check_requirements()` (стартовый gate-check при запуске сервиса) не патчится — она с самого начала использует `is_min_package_version()` и работает корректно на всех версиях.

---

### Генерируемый конфиг

Для ссылки `vless://...encryption=none&type=xhttp...` Podkop генерирует:

```json
{
  "type": "vless",
  "tag": "...",
  "tls": {
    "enabled": true,
    "server_name": "www.amd.com",
    "alpn": ["h2", "http/1.1"],
    "reality": {
      "enabled": true,
      "public_key": "...",
      "short_id": "..."
    },
    "utls": {
      "enabled": true,
      "fingerprint": "chrome"
    }
  },
  "transport": {
    "type": "xhttp",
    "path": "/v1/excuse/api",
    "mode": "auto",
    "host": "example.com",
    "x_padding_bytes": "100-1000",
    "sc_max_each_post_bytes": "1000000",
    "sc_min_posts_interval_ms": "30"
  }
}
```

---

### Возможные ошибки и решения

#### `Unknown transport 'xhttp' detected`

Патч не применён или слетел после обновления Podkop.

```sh
wget -O /tmp/patch.sh https://raw.githubusercontent.com/moix89/podkop-xhttp-patch/main/install.sh && sh /tmp/patch.sh
```

---

#### `Sing-box version is not compatible (older than 1.12.4)`

Патч версии не применён, либо установлен стандартный sing-box вместо extended.

Проверить:

```sh
sing-box version
```

Должно быть `1.13.x-extended-...`. Если нет — установить sing-box-extended:

```sh
wget -O /tmp/sb-ext.sh https://raw.githubusercontent.com/EikeiDev/OpenWRT-sing-box-extended/refs/heads/main/install.sh && sh /tmp/sb-ext.sh
```

Затем переустановить патч.

---

#### `Sing-box configuration is invalid. Aborted`

Причины:

1. **`encryption=mlkem...`** в ссылке — убрать постквантовое шифрование, установить `encryption=none`
2. **`spider_x`** в конфиге — старый патч добавлял это поле, sing-box 1.13.12 его не поддерживает. Переустановить патч — он удалит `spider_x` автоматически
3. **Сломанный файл** после многократных патчей — восстановить из backup (см. ниже)

Как проверить конкретную ошибку:

```sh
# Найти временный файл конфига
ls /tmp/tmp.*
# Проверить его
sing-box check -c /tmp/tmp.XXXXXX 2>&1
```

---

#### `Permission denied` при запуске podkop

Патч потерял бит исполнения при записи файла.

```sh
chmod +x /usr/bin/podkop
/etc/init.d/podkop restart
```

---

#### Пинг N/A в Clash API / Yacd

1. Проверить что ссылка содержит `encryption=none`
2. Проверить доступность сервера:

```sh
sing-box check -c /etc/sing-box/config.json 2>&1
```

1. Проверить что конфиг сгенерировался правильно:

```sh
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json
```

---

#### Патч слетел после обновления Podkop через opkg

Это нормально — `opkg upgrade podkop` перезаписывает файлы. Просто запустить патч снова:

```sh
wget -O /tmp/patch.sh https://raw.githubusercontent.com/moix89/podkop-xhttp-patch/main/install.sh && sh /tmp/patch.sh
```

---

### Откат из backup

Каждый запуск патча создаёт backup с timestamp в `/root/`.

```sh
# Посмотреть список backup-файлов
ls -la /root/*.backup.*

# Восстановить sing_box_config_facade.sh (подставьте timestamp)
cp /root/sing_box_config_facade.sh.backup.20260529_181427 \
   /usr/lib/podkop/sing_box_config_facade.sh

# Восстановить podkop
cp /root/podkop.backup.20260529_181427 /usr/bin/podkop
chmod +x /usr/bin/podkop

# Перезапустить
/etc/init.d/podkop restart
```

> Берите самый ранний (наименьший по размеру) backup — это оригинальный файл Podkop без патчей.

---

### Откат к полностью чистому Podkop

Если всё сломалось и нужно начать с нуля:

```sh
# Переустановить Podkop через opkg
opkg update
opkg install --force-reinstall podkop luci-app-podkop

# Проверить что файл чистый
grep -c "xhttp" /usr/lib/podkop/sing_box_config_facade.sh
# Должно вернуть 0

# Затем снова установить sing-box-extended и патч
wget -O /tmp/sb-ext.sh https://raw.githubusercontent.com/EikeiDev/OpenWRT-sing-box-extended/refs/heads/main/install.sh && sh /tmp/sb-ext.sh
wget -O /tmp/patch.sh https://raw.githubusercontent.com/moix89/podkop-xhttp-patch/main/install.sh && sh /tmp/patch.sh
```

---

### Диагностика

```sh
# Версии компонентов
cat /etc/openwrt_release | grep VERSION
apk list -I | grep podkop || opkg list-installed | grep podkop
sing-box version

# Проверка патча
grep -c "xhttp_sc_min_posts_interval_ms" /usr/lib/podkop/sing_box_config_facade.sh
# Должно вернуть 4+ если патч применён

# Общая проверка
podkop global_check

# Конфиг
sing-box check -c /etc/sing-box/config.json 2>&1
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json
jq '.outbounds[] | select(.type=="urltest")' /etc/sing-box/config.json

# Логи
logread | grep podkop | tail -30
```

---

### Протестировано на

| OpenWrt | Podkop | LuCI App | sing-box-extended |
|---|---|---|---|
| 25.12.2 r32802 | 0.7.17 / 0.7.18 | 0.7.17 / 0.7.18 | 1.13.12-extended-2.1.3 |
| 24.10.3 r28872 | 0.7.17 | 0.7.14 | 1.13.12-extended-2.3.0 |

- Роутер: Xiaomi Redmi AX6S
- Podkop 0.7.17 – 0.7.22 (версия детектируется автоматически, патчи применяются по обстоятельствам)
- Протокол: VLESS Reality XHTTP
- Режим: URLTest failover / одиночный URL

> Патч правит только программные файлы Podkop и не зависит от модели роутера.
> Должен работать на любом OpenWrt-роутере с совпадающими версиями софта.

---

### Лицензия

MIT — см. [LICENSE](LICENSE).

---

## English

One-command patch that adds full **VLESS Reality XHTTP** support to [Podkop](https://github.com/itdoginfo/podkop) on OpenWrt + sing-box-extended.

---

### What's new (2026-08-20)

Upstream Podkop reached version **0.7.22**, and along the way (2026-08-18) rewrote `check_sing_box()`, replacing its own buggy sing-box version parsing with the shared `is_min_package_version()`. That's exactly the bug this repo's patch 3/4 used to fix with a targeted string replacement — on newer Podkop versions, that targeted fix simply had nothing to match anymore.

- The patch now **auto-detects** which version of `check_sing_box()` is installed:
  - on Podkop **0.7.17–0.7.21** — it replaces the entire buggy version-comparison block with the fixed version (the same one shipped in 0.7.22);
  - on Podkop **0.7.22+** — it's a no-op, since upstream already fixed it.
- The `xhttp` transport is **still not natively supported** by any Podkop version, including 0.7.22 and main (maintainers closed the feature request as invalid) — patch 1 (inserting the `xhttp)` block) is still needed and always applies, regardless of version.
- Removed the hardcoded supported-version allowlist (previously the patch warned on anything other than `0.7.17`/`0.7.18`) — now it only warns if the version couldn't be detected at all.
- Added `apk` support for Podkop version detection (OpenWrt 24.10+ ships `apk` instead of `opkg`).

**Officially tested on:** Podkop 0.7.17 – 0.7.22 (see the caution block below and the "Tested on" section for exact configurations).

---

> [!CAUTION]
> **WARNING: CHECK YOUR VERSIONS BEFORE INSTALLING**
>
> The patch supports Podkop **0.7.17 – 0.7.22** (latest upstream release as of 2026-08-20).
> Upstream [itdoginfo/podkop](https://github.com/itdoginfo/podkop) does **not** support the
> `xhttp` transport natively in any version (including 0.7.22 and main) — patch 1 always
> applies. The sing-box version-check logic (patch 3/4) is auto-detected: on 0.7.17–0.7.21
> it replaces the buggy hand-rolled comparison with the fixed version from 0.7.22; on
> 0.7.22+ (where upstream already fixed it) the patch is a no-op.
>
> Tested configurations:
>
> **OpenWrt 25.12.2 r32802-f505120278:**
> - Podkop **0.7.18**
> - LuCI App Podkop **0.7.18** (branch 26.082.75780~067535e)
> - sing-box-extended **1.13.12-extended-2.1.3**
>
> **OpenWrt 24.10.3 r28872-daca7c049b:**
> - Podkop **0.7.17**
> - LuCI App Podkop **0.7.14** (branch 25.250.61039~923f8d9)
> - sing-box-extended **1.13.12-extended-2.3.0**
>
> Check your versions before installing:
>
> ```sh
> cat /etc/openwrt_release | grep VERSION
> apk list -I | grep podkop   # OpenWrt 24.10+ (apk)
> opkg list-installed | grep podkop   # older firmware (opkg)
> sing-box version
> ```
>
> When Podkop is updated via `opkg`/`apk`, the patch is **overwritten** — re-run the installer to re-apply.

---

> [!WARNING]
> **Important: post-quantum encryption is not supported**
>
> Podkop does **not support** `encryption=mlkem768x25519plus` or other post-quantum algorithms.
> If your link contains this parameter — the connection will fail with N/A ping.
>
> In your server panel (3x-ui etc.) on the **Protocol** tab set **Encryption = none** and click **Clear** to remove selected algorithms. The link must contain `encryption=none`.

---

> [!WARNING]
> ⚠️ **Disclaimer**
>
> The script is provided "as is". It is recommended to review the code before running.

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

#### Step 4 — Configure the link in 3x-ui

**Protocol tab**: Encryption = `none`, click Clear (remove X25519 and ML-KEM-768)

**Stream tab**: Transport = `XHTTP`, Mode = `auto`, Padding Bytes = `100-1000`

**Security tab**: Type = `Reality`, uTLS = `chrome`

Copy the link — it must contain `encryption=none&...type=xhttp`.

#### Step 5 — Verify

```sh
podkop global_check
sing-box check -c /etc/sing-box/config.json
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json
```

---

### Common issues

#### xhttp transport not found

Patch not applied or reset after Podkop update. Re-run the install command.

---

#### `Sing-box version is not compatible`

Either the version patch failed or standard sing-box is installed instead of extended.

```sh
sing-box version  # must show 1.13.x-extended-...
```

If not — install sing-box-extended first, then re-run the patch.

---

#### `Sing-box configuration is invalid`

1. Link contains `encryption=mlkem...` — set `encryption=none` in server panel
2. Old patch left `spider_x` field — re-run patch, it removes it automatically
3. File corrupted by repeated patching — restore from backup (see below)

```sh
ls /tmp/tmp.*
sing-box check -c /tmp/tmp.XXXXXX 2>&1
```

---

#### N/A ping in Clash API

1. Check link has `encryption=none`
2. Check config was generated correctly:

```sh
jq '.outbounds[] | select(.transport.type=="xhttp")' /etc/sing-box/config.json
```

---

### Rollback from backup

```sh
ls -la /root/*.backup.*

cp /root/sing_box_config_facade.sh.backup.TIMESTAMP \
   /usr/lib/podkop/sing_box_config_facade.sh

cp /root/podkop.backup.TIMESTAMP /usr/bin/podkop
chmod +x /usr/bin/podkop

/etc/init.d/podkop restart
```

Use the earliest (smallest) backup — that is the original unpatched Podkop file.

---

### Full reset

```sh
opkg update
opkg install --force-reinstall podkop luci-app-podkop

grep -c "xhttp" /usr/lib/podkop/sing_box_config_facade.sh
# Must return 0

wget -O /tmp/sb-ext.sh https://raw.githubusercontent.com/EikeiDev/OpenWRT-sing-box-extended/refs/heads/main/install.sh && sh /tmp/sb-ext.sh
wget -O /tmp/patch.sh https://raw.githubusercontent.com/moix89/podkop-xhttp-patch/main/install.sh && sh /tmp/patch.sh
```

---

### Tested on

| OpenWrt | Podkop | LuCI App | sing-box-extended |
|---|---|---|---|
| 25.12.2 r32802 | 0.7.17 / 0.7.18 | 0.7.17 / 0.7.18 | 1.13.12-extended-2.1.3 |
| 24.10.3 r28872 | 0.7.17 | 0.7.14 | 1.13.12-extended-2.3.0 |

- Router: Xiaomi Redmi AX6S
- Podkop 0.7.17 – 0.7.22 (version is auto-detected, patches applied accordingly)
- Protocol: VLESS Reality XHTTP
- Mode: URLTest failover / single URL

> The patch only modifies Podkop's software files and is not router-specific.
> Should work on any OpenWrt router with matching software versions.

---

### License

MIT — see [LICENSE](LICENSE).
