# docker-vm-manager

A small bash CLI that manages Docker containers like lightweight, persistent
"virtual machines" — create one from any Docker Hub image, jump into a shell,
stop it, and come back later with your data intact.

## Requirements

- `bash`
- Docker (daemon running)
- For SSH agent forwarding (on by default, see below): `socat` or `python3`
  on the host, and `socat` or `python3` inside the VM's image

## Install

```sh
make install
```

This copies `vm` into `~/.local/bin` (no `sudo` needed). If that directory
isn't already on your `PATH`, the install prints the line to add to your
shell profile (e.g. `~/.zshrc`).

To install elsewhere, override `BINDIR`:

```sh
make install BINDIR=/usr/local/bin   # system-wide, may need sudo
```

To remove it:

```sh
make uninstall
```

`uninstall` searches every directory on your `PATH` (plus `BINDIR`) for an
installed `vm` and removes it — so it finds the script regardless of where
`make install` put it, without touching an unrelated `vm` command.

## Usage

```
vm create <name> <image> [options]  Create a new VM from a Docker image, with persistent storage
  --platform <platform>              Force a specific platform, e.g. linux/amd64 (useful when
                                      an image has no native build for your CPU architecture)
vm start <name> [options]   Start the VM (if needed) and open an interactive shell
  -k, --keep-running           Leave the VM running in the background after the shell exits
                                (default: stop the VM when the shell exits)
  --share-ssh                   Forward the host's SSH agent into the VM (default: off)
vm stop <name | -a | --all>  Stop the VM, or all VMs (data, container, and any active SSH
                              agent forwarding for it are cleaned up)
vm list                      List all VMs
vm delete <name> [options]   Delete a VM
  -y, --yes                    Skip confirmation prompt
  --purge                       Also delete the VM's persistent data volume
```

### Example

```sh
vm create dev ubuntu:22.04
vm start dev        # opens a shell inside the VM
# ... do stuff, files under /data persist across stop/start ...
exit                 # VM stops automatically
vm start dev         # same container, same filesystem state
vm list
vm delete dev --purge
```

Pass `-k`/`--keep-running` to leave the VM running in the background after
you exit the shell, instead of stopping it:

```sh
vm start dev -k
exit                 # VM keeps running
vm list              # shows it as "running"
vm stop dev          # stop it explicitly later
```

Stop every VM at once with `vm stop -a` / `vm stop --all`.

If an image doesn't publish a build for your CPU architecture (common with
`archlinux` on Apple Silicon / arm64), force Docker to run it under
emulation with `--platform`:

```sh
vm create arch archlinux --platform linux/amd64
```

### SSH access from inside the VM

Pass `--share-ssh` to `vm start` to forward your host's live SSH agent into
the VM, so you can `ssh` out from inside the VM to anywhere you can `ssh` to
from the host, using your existing identities — **without ever copying any
private key material into the VM**. This works with passphrase-protected
keys, hardware-backed keys (Secure Enclave, YubiKey), and agents like
1Password's, since the VM only ever relays signing requests to your host's
agent, which does the actual signing. It's off by default:

```sh
vm start dev --share-ssh
ssh git@github.com   # works, using your host's agent and keys
```

Under the hood, Docker Desktop can't bind-mount a live UNIX socket straight
into a container (its VirtioFS file sharing doesn't support that), so this
works by bridging the connection over loopback TCP instead: a relay on the
host forwards `127.0.0.1:<port>` to your `ssh-agent`'s socket, and a second
relay inside the VM forwards its own `$SSH_AUTH_SOCK` to that port via
`host.docker.internal`. Both relays use `socat` if available, falling back
to a small bundled Python relay otherwise. The relay only runs while the VM
is running — `vm stop` (or the auto-stop after `vm start` without `-k`)
tears it down, so forwarding access ends when the VM does.

**Security note:** the host-side relay's TCP port (bound to `127.0.0.1`) is
reachable from *any* container on the machine via `host.docker.internal`,
not just this VM's — anything that guesses the port while your agent is
forwarded could ask it to sign requests. Fine for a personal dev machine
running your own containers; don't rely on this if you run untrusted
containers on the same host.

## How it works

- Each VM is a Docker container named `vmm-<name>`, kept alive in the
  background with `tail -f /dev/null` so it can be started once and shelled
  into any number of times.
- Persistent storage is a dedicated named Docker volume (`vmm-<name>-data`)
  mounted at `/data` inside the container.
- `vm start` opens `bash` if available in the image, falling back to `sh`.
- `vm delete` removes the container but keeps the data volume by default;
  pass `--purge` to delete the volume too.
- All VMs are tagged with the `vmm.managed=true` label so the tool only ever
  touches containers/volumes it created.
- Each VM is created with `SSH_AUTH_SOCK` pointing at a fixed in-container
  path and an `--add-host host.docker.internal:host-gateway` mapping, so it
  can reach the host regardless of platform; see "SSH access from inside
  the VM" above for what uses that.
