#!/usr/bin/env bash

set -euo pipefail

LOG_STEP=0
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh | tr '[:lower:]' '[:upper:]')"
exec 3>&1
exec >/dev/null 2>&1

log_info() {
	LOG_STEP=$((LOG_STEP + 1))
	printf '\033[36mINFO\033[0m\033[37m[%04d]\033[0m \033[36m[%s]\033[0m %s\n' "${LOG_STEP}" "${SCRIPT_NAME}" "$1" >&3
}

log_text() {
	printf '%s\n' "$1" >&3
}

trap 'printf "\033[31mERROR\033[0m Echec a la ligne %s\n" "$LINENO" >&3' ERR

if [[ "${EUID}" -eq 0 ]]; then
	log_text "Run this script as a regular user (sudo is used internally)."
	exit 1
fi

if [[ ! -f /etc/os-release ]]; then
	log_text "Cannot detect OS release information."
	exit 1
fi

. /etc/os-release

if [[ "${ID}" != "debian" ]]; then
	log_text "Warning: this script is designed for Debian. Detected: ${ID}."
fi

if [[ "${VERSION_CODENAME:-}" != "trixie" && "${VERSION_CODENAME:-}" != "bookworm" && "${VERSION_CODENAME:-}" != "bullseye" ]]; then
	log_text "Warning: Docker official support targets Debian trixie/bookworm/bullseye."
fi

log_info "[1/6] Installation paquets de base"
sudo apt update
sudo apt install -y ca-certificates curl gnupg git

log_info "[2/6] Suppression paquets Docker en conflit"
CONFLICTING="$(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc 2>/dev/null | cut -f1 || true)"
if [[ -n "${CONFLICTING}" ]]; then
	sudo apt remove -y ${CONFLICTING}
fi

log_info "[3/6] Configuration depot Docker"
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

log_info "[4/6] Installation Docker Engine"
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker

if ! groups "${USER}" | grep -q '\bdocker\b'; then
	sudo usermod -aG docker "${USER}"
	log_text "User added to docker group. Re-login is required for group changes."
fi

log_info "[5/6] Installation kubectl"
if ! command -v kubectl >/dev/null 2>&1; then
	ARCH="$(dpkg --print-architecture)"
	case "${ARCH}" in
		amd64) KUBECTL_ARCH="amd64" ;;
		arm64) KUBECTL_ARCH="arm64" ;;
		armhf) KUBECTL_ARCH="arm" ;;
		ppc64el) KUBECTL_ARCH="ppc64le" ;;
		*)
			log_text "Unsupported architecture for kubectl auto-install: ${ARCH}"
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

log_info "[6/6] Installation k3d"
if ! command -v k3d >/dev/null 2>&1; then
	curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

docker_version="$(docker --version 2>/dev/null || true)"
kubectl_version="$(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null || true)"
k3d_version="$(k3d version 2>/dev/null || true)"

log_info "Dependencies are ready"
log_text "${docker_version}"
log_text "${kubectl_version}"
log_text "${k3d_version}"
