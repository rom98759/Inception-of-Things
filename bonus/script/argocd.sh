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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P3_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ARGOCD_MANIFEST_URL="${ARGOCD_MANIFEST_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"

log_info "Creation namespace argocd"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

log_info "Installation manifeste Argo CD"
kubectl apply -n argocd \
	--server-side \
	--force-conflicts \
	-f "${ARGOCD_MANIFEST_URL}"

log_info "Attente des deployments Argo CD"
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=240s
kubectl wait --for=condition=Available deployment/argocd-repo-server -n argocd --timeout=240s
kubectl wait --for=condition=Available deployment/argocd-applicationset-controller -n argocd --timeout=240s

log_info "Configuration argocd-server pour /argocd"
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true","server.rootpath":"/argocd","server.basehref":"/argocd"}}'
kubectl rollout restart deployment/argocd-server -n argocd
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=240s

log_info "Application ingress Argo CD"
kubectl apply -f "${P3_DIR}/confs/argocd/ingress.yaml"

admin_password="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
log_info "Argo CD pret"
log_text "admin password: ${admin_password}"
