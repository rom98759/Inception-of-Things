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

CLUSTER_NAME="${K3D_CLUSTER_NAME:-iot-cluster}"
AGENTS="${K3D_AGENTS:-1}"

if ! command -v k3d >/dev/null 2>&1; then
	log_text "k3d not found. Run script/necessary_packages.sh first."
	exit 1
fi

if k3d cluster list | awk 'NR>1 {print $1}' | grep -qx "${CLUSTER_NAME}"; then
	log_info "Cluster ${CLUSTER_NAME} deja present"
else
	log_info "Creation cluster ${CLUSTER_NAME}"
	k3d cluster create "${CLUSTER_NAME}" \
		--agents "${AGENTS}" \
		--port "8080:80@loadbalancer"
fi

log_info "Verification etat cluster"
kubectl cluster-info
kubectl wait --for=condition=Ready node --all --timeout=180s
kubectl get nodes -o wide

log_info "Cluster Kubernetes pret"
