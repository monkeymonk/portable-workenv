# macOS

## Install Docker Desktop

https://docs.docker.com/desktop/install/mac-install/

Enable:
- File sharing for `/Users`, `/tmp`, `/private`

workenv does not use Docker Compose — only `docker run` / `docker exec`.

## UID/GID

Docker Desktop maps host UIDs automatically via its gRPC FUSE filesystem.
The launcher skips `--build-arg USER_ID` on macOS.

## SSH agent

macOS ships a keychain-backed agent. Add to `~/.ssh/config`:

```
Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
```

The launcher mounts `$SSH_AUTH_SOCK` via Docker Desktop's socket forwarding.

## Host relay

Install the relay dependency:

```bash
brew install socat
```

`workenv shell`, `workenv tmux`, and `workenv edit` auto-start
`workenv-relay.sh` when `socat` is available. macOS uses `pbcopy`/`pbpaste`
for relay clipboard support.

LaunchAgent at `~/Library/LaunchAgents/com.workenv.relay.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>          <string>com.workenv.relay</string>
  <key>ProgramArguments</key><array>
    <string>/Users/you/src/workenv/bin/workenv-relay.sh</string>
  </array>
  <key>RunAtLoad</key>      <true/>
  <key>KeepAlive</key>      <true/>
</dict>
</plist>
```

```bash
launchctl load -w ~/Library/LaunchAgents/com.workenv.relay.plist
```

## Clipboard

When the host relay socket is mounted, Neovim uses `pbcopy`/`pbpaste` directly.

Without the relay, OSC 52 works in Terminal.app, iTerm2 (enable "Applications
in terminal may access clipboard"), Ghostty, Kitty, WezTerm.

## Performance

Bind-mount I/O on Docker Desktop is noticeably slower than Linux. For huge
monorepos, consider keeping `node_modules` inside the container volume
instead of the bind-mounted `/workspace`.
