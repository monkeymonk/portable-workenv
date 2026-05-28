# Multi-project

## Model

One container per project. All containers share a single Docker volume
`workenv-root`. This means:

- Plugins, parsers, mise-installed runtimes, TPM plugins, shell history,
  LSP caches are shared across every project container.
- Install `mise install python@3.12` in project A → immediately available in
  project B.
- Each container has its own `/workspace` bind-mount, its own `/tmp`, and
  its own process space.

## Naming

For automatically named containers, workenv uses the sanitized project basename
and appends a short hash of the absolute project path:

```
workenv-<sanitized-basename>-<path-hash>
```

E.g. `~/work/My App` → `workenv-my-app-a1b2c3d4`. The hash prevents two
projects with the same basename from sharing a container.

Override with `--name foo` or `WORKENV_NAME=foo` in `.workenv`.

## Running two projects at once

```bash
workenv shell ~/work/proj-a   # terminal 1: enters workenv-proj-a-<hash>
workenv shell ~/work/proj-b   # terminal 2: enters workenv-proj-b-<hash>

docker ps --format 'table {{.Names}}\t{{.Status}}'
# workenv-proj-a-a1b2c3d4  Up 1 minute
# workenv-proj-b-e5f6a7b8  Up 30 seconds
```

## Persistence boundaries

| State                  | Shared? | Location                  |
|------------------------|---------|---------------------------|
| Plugins (vim.pack/Mason) | Yes   | Volume `data/nvim` |
| Treesitter parsers     | Yes     | Volume `data/nvim/site/parser` |
| mise runtimes          | Yes     | Volume `data/mise`        |
| TPM plugins            | Yes     | Volume `data/tmux`        |
| Shell history          | Yes     | Volume `state/zsh`      |
| Session data (tmux)    | Yes     | Volume `state/tmux`       |
| nvim session files     | Yes     | Volume `state/nvim` |
| Per-project notes      | No      | Lives in the mounted repo |
| `/tmp`                 | No      | Container-local           |

## Cleaning up

```bash
workenv stop --all       # stop all workenv-* containers
workenv clean            # remove stopped containers + dangling images
docker volume rm workenv-root   # nuke shared state (factory reset)
```

`workenv stop` accepts a project directory, an exact container name, or a
basename **prefix**:

```bash
workenv stop ~/work/proj-a   # by project directory
workenv stop proj            # prefix: stops every workenv-proj*… container
workenv stop --strict proj-a-a1b2c3d4   # exact-name match only
```

Use `--strict` to force exact-name matching and skip prefix expansion.

## Runtime changes

workenv labels each container with a hash of the image id, project path, mounts,
config overlays, and forwarded environment. If any of those inputs changes, the
next launcher call recreates the container automatically while keeping the
shared volume intact.

## Future: per-project state

Splitting the single volume into per-project state (e.g. per-project LSP
caches) is a Phase 2 concern. The current design accepts that shared state is
the right default for a single-user, single-machine personal setup.
