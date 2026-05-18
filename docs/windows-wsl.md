# Windows / WSL2

## Prerequisites

- Windows 11 or recent Windows 10
- WSL2 with a Debian/Ubuntu distro
- Docker Desktop with "Use WSL2 based engine" enabled, and "Enable integration
  with my default WSL distro" checked for your distro

## UID/GID

Inside WSL2 the launcher runs as a normal Linux process — UID/GID build args
work exactly like native Linux.

## SSH agent

From your WSL shell:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Optional: share Windows's `ssh-agent` via `npiperelay`.

## Host relay

Install the relay dependency:

```bash
sudo apt-get install socat
```

`shellc`, `tmuxc`, and `nvimc` auto-start `workenv-relay.sh` when `socat` is
available.

The shim uses `xdg-open` which WSL forwards to `wslview` → Windows default
browser. Alternatively, set `WORKENV_RELAY_OPENER=wslview`.

## Clipboard

When the host relay socket is mounted, Neovim uses `clip.exe` for copy and
`powershell.exe Get-Clipboard` for paste.

Without the relay, Windows Terminal supports OSC 52 (enable in settings →
"Redirect clipboard operations"). WSL Interop handles paste natively.

## File system

Keep projects on the WSL filesystem (`~/...`), not `/mnt/c/...`, to avoid the
9p performance penalty.
