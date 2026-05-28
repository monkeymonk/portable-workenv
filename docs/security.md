# Security model

workenv keeps secrets on the host. They are not copied into the image during
builds and are only exposed to containers through explicit runtime mounts or
environment passthrough.

## Mounted host files

The launcher mounts these automatically when present:

| Host path | Container path | Mode |
|-----------|----------------|------|
| `$SSH_AUTH_SOCK` | `/run/host-ssh/agent.sock` | socket |
| `~/.gitconfig` | `/home/dev/.gitconfig` | read-only |
| `~/.ssh/config` | `/home/dev/.ssh/config` | read-only |
| `~/.ssh/known_hosts` | `/home/dev/.ssh/known_hosts` | read-only |

`--ssh-keys` or `WORKENV_SSH_KEYS=true` additionally mounts all of `~/.ssh`
read-only. Prefer agent forwarding when possible; mounting private key files
gives every process in the project container read access to those keys.

## Environment variables

`HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` are passed through automatically
when set and are also supplied as Docker build args. Other values require opt-in
with `--env`, `WORKENV_ENV`, or `WORKENV_ENV_VARS`.

Examples:

```bash
workenv shell --env GITHUB_TOKEN ~/project
workenv shell --env FOO=bar ~/project
```

Environment variables are visible to processes in the container. Do not pass
long-lived credentials into untrusted project containers.

## Docker socket

`--docker` or `WORKENV_DOCKER=true` mounts `/var/run/docker.sock`. This gives
the container effective control over the host Docker daemon and should only be
enabled for trusted projects.

## Host relay

The host relay's `open` command refuses URLs whose scheme is not in
`WORKENV_RELAY_OPEN_SCHEMES` (a comma-separated allowlist, default
`http,https,mailto`). Other schemes such as `file:` or `javascript:` are
rejected, so a hostile project can't make the relay open arbitrary local files
or run script URLs.

The relay passes notify messages to the host notifier as a single argv element,
so there is no shell interpolation of message content, and the relay shims
reject newlines.

## Project Dockerfiles

`.workenv/Dockerfile` is built with the project root as context. Add a project
`.dockerignore` before copying large trees or sensitive local files into the
build context. The launcher warns once per project when the build context
exceeds `WORKENV_DOCKERIGNORE_WARN_MB` MB (default `100`) and no `.dockerignore`
is present.
