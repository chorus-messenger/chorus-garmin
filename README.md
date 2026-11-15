# Chorus for Garmin watches

A small Connect IQ watch app (Monkey C) for the Garmin Venu 3 / Venu 3S that talks to your Chorus server through the phone.

- Chat list (archived chats and mailboxes are hidden unless you turn mail on)
- Last messages of a chat, voice messages as transcript ("Transcribe" on the watch if there is none yet)
- Reply with three AI suggestions (only in chats with AI enabled) or your own quick replies, shown in full before sending
- Mark as read

Listening to or recording voice messages is not possible: Connect IQ has no microphone or free audio playback API.

## Pairing

The watch shows a six-digit code. Enter it in Chorus under **Settings → Garmin watch**. The watch then gets its own key that can only read chats and send replies, stored hashed in your encrypted vault and revocable there. While your vault is locked, the watch gets nothing.

## Build and install

```sh
SERVER=https://chorus.example.org KEY=developer_key.der ./build.sh
```

Copy `bin/chorus-venu3.prg` to `GARMIN/APPS` on the watch (USB; on a Mac use OpenMTP). Device files for `venu3` come from the Connect IQ SDK Manager (Garmin account needed).

Watch endpoints on the server: `/api/w/*` (see `server/src/watch.ts`).
