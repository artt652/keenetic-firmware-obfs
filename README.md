# keenetic-firmware-obfs

Сборка KeeneticOS для роутеров без поддержки OPKG (первая цель — **Sprinter KN-3710**):

1. **OPKG во внутренней памяти**: включаются опции хранилища, как у Hopper KN-3810 (та же платформа
   EN7528). После прошивки ставится Entware и пакет
   [wg-obfuscator-keenetic](https://github.com/artt652/wg-obfuscator-keenetic).
2. **wg-obfuscator в модуле WireGuard** (в планах): обфускация в ядре, настройка штатно через
   параметр AmneziaWG `I5` — см. [docs/i5-format.md](docs/i5-format.md).

> **Статус: не проверено на устройстве.** Сборка ещё не запускалась на реальной прошивке.
> Прошивка неофициальной сборкой может окирпичить роутер и лишает гарантии. Восстановление —
> через TFTP (режим recovery Keenetic). Сохраните оригинальную прошивку до начала.

## Что нужно

- Linux x86_64 (Ubuntu LTS), пакеты из [README keenetic-sdk](https://github.com/keenetic/keenetic-sdk);
- **прошивка целевого роутера** — «Управление» → «Настройки системы» → «Системные файлы» →
  firmware → «Сохранить на компьютер»;
- **прошивка донора той же версии KeeneticOS** — Hopper KN-3810 для Sprinter. В прошивке Sprinter нет
  закрытых модулей NDM для хранилища, они берутся из донора.

## Сборка

```sh
./build.sh --firmware KN-3710-5.01.C.8.0-2.bin --donor KN-3810-5.01.C.8.0-2.bin
```

Скрипт клонирует [keenetic-sdk](https://github.com/keenetic/keenetic-sdk) нужной версии, распаковывает
обе прошивки, добавляет из донора недостающие бинарные пакеты, применяет `models/KN-3710/`
и патчи из `package/kernel/wireguard/patches/`, собирает. Образ — в `work/sdk/bin/`.

## Состав

| Путь | Что |
| --- | --- |
| `build.sh` | сборка |
| `models/KN-3710/config.overlay` | значения Kconfig: extended storage, UBIFS, модули хранилища |
| `models/KN-3710/target.mk.append` | `FEATURES += usb usbstorage extended_storage` |
| `package/kernel/wireguard/patches/` | патчи модуля WireGuard (пока нет) |
| `tools/wgobfs-i5.sh` | строка I5 для режима wg-obfuscator |
| `docs/i5-format.md` | формат I5 и что проверено на KeeneticOS |

Основа: [srgsf/keenetic-sdk](https://github.com/srgsf/keenetic-sdk/tree/KN-3710-storage) (OPKG на
KN-3710), значения обновлены по KN-3810 из keenetic-sdk 5.01.

## Чего здесь нет и не будет

Прошивок и файлов, извлечённых из них (модули NDM и т. п.): это проприетарное ПО Keenetic.
Они нужны только локально при сборке (`work/`, `*.bin` в `.gitignore`).

## Лицензия

GPL-2.0, как у keenetic-sdk и модуля WireGuard.
