# Патчи модуля WireGuard (keenetic/wireguard)

Сюда кладутся `.patch` к исходникам модуля, SDK применяет их при сборке
(`package/kernel/wireguard`, версия из Makefile SDK, сейчас `1.0.20200623-23-1`).

Статус: **патч ещё не написан.** Пока его нет, `build.sh` собирает прошивку только с OPKG.

План (`docs/i5-format.md`):
- `netlink.c`: распознать метку `WGOB` в `WGDEVICE_A_I5`, сохранить ключ, маскировку, max-dummy в
  `struct wg_device`, не регистрировать I5 как junk-пакет;
- `send.c` / `receive.c` (или `socket.c`): кодировать исходящие и раскодировать входящие UDP-пакеты
  по протоколу wg-obfuscator v1.6; при STUN — обёртка Data Indication, Binding Request перед
  рукопожатием и каждые 10 с;
- ответ на STUN Binding Request от сервера.

## Лицензия

Модуль — GPL-2.0, wg-obfuscator — GPL-3.0, лицензии несовместимы. Код wg-obfuscator в патч не
копируется: протокол реализуется заново по описанию (формат пакета, XOR-поток CRC8 от ключа, STUN),
либо с разрешения автора (ClusterM) на использование его кода под GPL-2.0.
