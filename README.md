# docker-vm-manager

A small bash CLI that manages Docker containers like lightweight, persistent
"virtual machines" — create one from any Docker Hub image, jump into a shell,
stop it, and come back later with your data intact.

## Requirements

- `bash`
- Docker (daemon running)

## Install

Make the script executable and put it on your `PATH`:

```sh
chmod +x vm
sudo ln -s "$(pwd)/vm" /usr/local/bin/vm
```

## Usage

```
vm create <name> <image>   Create a new VM from a Docker image, with persistent storage
vm start <name>             Start the VM (if needed) and open an interactive shell
vm stop <name>               Stop the VM (data and container are kept)
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
exit
vm stop dev
vm start dev         # same container, same shell history/filesystem state
vm list
vm delete dev --purge
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
