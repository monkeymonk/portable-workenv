# Linux

## Install Docker

Debian/Ubuntu:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
newgrp docker
```

Verify: `docker run hello-world`.

## SSH agent

```bash
# ~/.profile or systemd-user unit
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

The launcher mounts `$SSH_AUTH_SOCK` automatically.

## Host relay

Install the relay dependency and one clipboard backend:

```bash
sudo apt-get install socat wl-clipboard
# X11 alternative:
# sudo apt-get install socat xclip
```

`shellc`, `tmuxc`, and `nvimc` auto-start `workenv-relay.sh` when `socat` is
available. To run it persistently instead, use a systemd user unit.

systemd user unit at `~/.config/systemd/user/workenv-relay.service`:

```ini
[Unit]
Description=workenv host relay

[Service]
ExecStart=%h/src/workenv/bin/workenv-relay.sh
Restart=on-failure

[Install]
WantedBy=default.target
```

```bash
systemctl --user enable --now workenv-relay.service
```

## Clipboard

When the host relay socket is mounted, Neovim uses the host clipboard directly
through `wl-copy`/`wl-paste`, `xclip`, or `xsel`.

Without the relay, OSC 52 works in Kitty, Ghostty, WezTerm, Alacritty (with
`enable_kitty_keyboard yes`) when terminal clipboard access is enabled.

Gnome Terminal / Konsole require enabling OSC 52 in profile settings.

## Known issues

- AppArmor on some distros blocks `docker exec` into containers. If you see
  permission denied on the SSH agent socket, add `apparmor=unconfined` to
  the docker run args.
