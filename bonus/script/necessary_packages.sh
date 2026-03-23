#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
	echo "Run this script as a regular user (sudo is used internally)."
	exit 1
fi

if [[ ! -f /etc/os-release ]]; then
	echo "Cannot detect OS release information."
	exit 1
fi

. /etc/os-release

if [[ "${ID}" != "debian" ]]; then
	echo "Warning: this script is designed for Debian. Detected: ${ID}."
fi

if [[ "${VERSION_CODENAME:-}" != "trixie" && "${VERSION_CODENAME:-}" != "bookworm" && "${VERSION_CODENAME:-}" != "bullseye" ]]; then
	echo "Warning: Docker official support targets Debian trixie/bookworm/bullseye."
fi

echo "[1/6] Install base packages"
sudo apt update
sudo apt install -y ca-certificates curl gnupg git

echo "[2/6] Remove conflicting Docker packages if present"
CONFLICTING="$(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc 2>/dev/null | cut -f1 || true)"
if [[ -n "${CONFLICTING}" ]]; then
	sudo apt remove -y ${CONFLICTING}
fi

echo "[3/6] Configure Docker apt repository"
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

CODENAME="${DOCKER_DEBIAN_CODENAME:-${VERSION_CODENAME:-bookworm}}"
sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

echo "[4/6] Install Docker Engine"
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker

if ! groups "${USER}" | grep -q '\bdocker\b'; then
	sudo usermod -aG docker "${USER}"
	echo "User added to docker group. Re-login is required for group changes."
fi

echo "[5/6] Install kubectl"
if ! command -v kubectl >/dev/null 2>&1; then
	ARCH="$(dpkg --print-architecture)"
	case "${ARCH}" in
		amd64) KUBECTL_ARCH="amd64" ;;
		arm64) KUBECTL_ARCH="arm64" ;;
		armhf) KUBECTL_ARCH="arm" ;;
		ppc64el) KUBECTL_ARCH="ppc64le" ;;
		*)
			echo "Unsupported architecture for kubectl auto-install: ${ARCH}"
			exit 1
			;;
	esac

	KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
	curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl"
	curl -fsSLo /tmp/kubectl.sha256 "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl.sha256"
	echo "$(cat /tmp/kubectl.sha256)  /tmp/kubectl" | sha256sum --check
	chmod +x /tmp/kubectl
	sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
	rm -f /tmp/kubectl /tmp/kubectl.sha256
fi

echo "[6/6] Install k3d"
if ! command -v k3d >/dev/null 2>&1; then
	curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

docker --version
kubectl version --client
k3d version
echo "Dependencies are ready."
