This project has been created as part of the 42 curriculum by rcaillie, jhervoch.

# Inception-of-Things-42

## Description
This project provisions a lightweight Kubernetes lab on Debian 12 VMs using Vagrant + libvirt + K3s.

The environment creates:
- 1 control-plane node (`<user>S`)
- 1 worker node (`<user>SW`)

The VMs are connected through a private network (`192.168.56.0/24`) and share the project folder via NFS.

## Instructions
Requirements:
- Linux host (tested on Debian 12)
- `vagrant` with `vagrant-libvirt` plugin
- `libvirt`/`qemu` stack
- `nfs-kernel-server`

### Quick Start
```bash
# 1) Start the environment
vagrant up

# 2) Check VM status
vagrant status

# 3) Verify cluster nodes from server VM
vagrant ssh <user>S -- kubectl get nodes -o wide

# 4) (Optional) Apply worker role label
vagrant provision <user>S --provision-with label-worker
```

If you need a clean rebuild:
```bash
vagrant destroy -f
vagrant up
```


# Vagrant
## install
```bash
sudo apt update
sudo apt install -y vagrant
vagrant plugin install vagrant-libvirt
```

Check installation:
```bash
vagrant --version
vagrant plugin list
```

## key commands
```bash
vagrant up
vagrant halt
vagrant reload
vagrant provision
vagrant provision <vm_name>
vagrant ssh <vm_name>
vagrant destroy -f
vagrant status
```

## vagrantfile
Main points in this project Vagrantfile:
- `config.vm.box = "generic/debian12"`
- Provider: `libvirt` with 2 vCPU / 2 GB RAM per VM
- Shared folder: NFSv4 (`nfs_version: 4`, `nfs_udp: false`)
- Private network:
	- server: `192.168.56.11`
	- worker: `192.168.56.12`
- Provisioners:
	- `scripts/Server.sh`
	- `scripts/Worker.sh`
	- `scripts/LabelWorker.sh` (manual, named `label-worker`)

# libvirt
## install 
```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients libvirt-dev dnsmasq-base
sudo usermod -aG libvirt $USER
newgrp libvirt
```

## key commands
```bash
virsh list --all
virsh -c qemu:///system list --all
virsh -c qemu:///system undefine <domain_name>
```

Useful when a stale domain blocks `vagrant up`:
```bash
virsh -c qemu:///system undefine Inception-of-Things-42_<vm_name>
```

# k3s
## install
K3s is installed by shell scripts during provisioning:
- `scripts/Server.sh` installs control-plane
- `scripts/Worker.sh` installs agent

The scripts call the official installer:
```bash
curl -sfL https://get.k3s.io | sh -
```

## principe of server and worker
- Server node:
	- runs Kubernetes control-plane
	- generates join token (`/var/lib/rancher/k3s/server/node-token`)
	- copies token to shared folder (`/vagrant/k3s_token`)
- Worker node:
	- waits for token availability
	- validates token hash against server CA
	- joins cluster through `K3S_URL=https://<server_ip>:6443`

Important:
- Kubernetes node names are lowercase by design (RFC 1123 normalization).

## key config
Server config template:
- `confs/Server.yaml.tpl`

Worker config template:
- `confs/Worker.yaml.tpl`

Generated runtime config on VMs:
- `/etc/rancher/k3s/config.yaml`

Useful validation commands:
```bash
vagrant ssh <user>S -- kubectl get nodes -o wide
vagrant ssh <user>S -- kubectl get pods -A
vagrant ssh <user>SW -- sudo systemctl status k3s-agent --no-pager
vagrant ssh <user>S -- sudo systemctl status k3s --no-pager
```
