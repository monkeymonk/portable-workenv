# Troubleshooting

## Container won't start

```bash
docker logs workenv-<project>
```

Common causes:
- UID mismatch after swapping machines → `shellc --rebuild`
- Volume missing → `docker volume create workenv-root`
- Image missing → `WORKENV_IMAGE=workenv:latest shellc --rebuild`

## File ownership issues on host

Container writes files owned by a UID that doesn't match yours.

Fix (Linux/WSL only):

```bash
shellc --rebuild    # rebuilds with your current UID/GID
sudo chown -R "$USER:$USER" path/to/files
```

macOS Docker Desktop should not hit this.

## SSH agent not forwarded

Inside container:

```bash
ssh-add -l
# "Could not open a connection to your authentication agent."
```

Causes:
- No agent running on host → `eval "$(ssh-agent -s)" && ssh-add`
- `$SSH_AUTH_SOCK` unset when launcher was invoked → start a fresh shell
- Fallback: `shellc --ssh-keys` to mount `~/.ssh` read-only

## Clipboard not working

Checklist:
1. On the host, install `socat` and a clipboard tool:
   - Linux Wayland: `wl-clipboard`
   - Linux X11: `xclip` or `xsel`
   - macOS: `pbcopy`/`pbpaste` are built in
   - WSL: `clip.exe` and `powershell.exe` come from Windows interop
2. Confirm the relay socket exists:
   `ls -l "$XDG_RUNTIME_DIR/workenv-relay.sock"` on Linux/WSL, or
   `ls -l "$TMPDIR/workenv-relay.sock"` on macOS.
3. Restart the project container after the socket exists so Docker can mount it:
   `workenv-stop && shellc`.
4. In Neovim, `:lua print(vim.g.clipboard.name)` should print
   `workenv host relay`.

If the relay is unavailable, workenv falls back to OSC 52 copy-only mode.
Copying from Neovim can still work through the terminal, but pasting from the
host clipboard is disabled to avoid terminal response timeouts.

## Host relay not responding

```bash
ls -l "$XDG_RUNTIME_DIR/workenv-relay.sock"   # Linux/WSL
ls -l "$TMPDIR/workenv-relay.sock"            # macOS
```

Start daemon manually:

```bash
workenv-relay.sh
```

Shims degrade gracefully — a missing socket just prints a warning; it never
crashes Neovim or the shell.

## Treesitter parser errors

```bash
:TSUpdate all
```

If persistent, `docker volume rm workenv-root` to reset all parsers (also
wipes plugins and runtimes — destructive).

## Mason install failures

Usually a curl/git proxy issue. Inside container:

```bash
curl https://github.com    # verify network
:Mason        # retry install
```

Corporate proxies: `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` are forwarded
automatically when set on the host or in `~/.config/workenv/config`, including
as Docker build args. You can also pass them explicitly:

```bash
shellc --env HTTPS_PROXY=http://proxy.example ~/project
```

## Slow startup

First launch builds the image and installs plugins on first nvim open.
Subsequent launches should feel instant (`docker exec` is fast).

If `docker exec` itself is slow, Docker Desktop has a known regression on
some macOS versions — restart Docker Desktop.
