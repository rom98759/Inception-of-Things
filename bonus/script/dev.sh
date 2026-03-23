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

trap 'printf "\033[31mERROR\033[0m Echec a la ligne %s\n" "$LINENO" >&3' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P3_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

log_info "Application namespace dev"
kubectl apply -f "${P3_DIR}/confs/dev/namespace.yaml"

log_info "Application Argo CD app dev"
kubectl apply -f "${P3_DIR}/confs/dev/application.yaml"

log_info "Verification etat application et ressources dev"
kubectl get applications.argoproj.io -n argocd
kubectl get all -n dev
kubectl get ingress -n dev

log_info "Deploiement dev termine"
