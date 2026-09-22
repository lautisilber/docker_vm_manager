# docker-vm-manager

A small bash CLI that manages Docker containers like lightweight, persistent
"virtual machines" — create one from any Docker Hub image, jump into a shell,
stop it, and come back later with your data intact.

## Requirements

- `bash`
- Docker (daemon running)

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
vm stop <name | -a | --all>  Stop the VM, or all VMs (data and container are kept)
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
