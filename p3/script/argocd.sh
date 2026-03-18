#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P3_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ARGOCD_MANIFEST_URL="${ARGOCD_MANIFEST_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"

# Idempotent namespace creation keeps make target re-runnable.
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd \
	--server-side \
	--force-conflicts \
	-f "${ARGOCD_MANIFEST_URL}"

kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=240s
kubectl wait --for=condition=Available deployment/argocd-repo-server -n argocd --timeout=240s
kubectl wait --for=condition=Available deployment/argocd-applicationset-controller -n argocd --timeout=240s

# Run argocd-server behind ingress without internal TLS to avoid redirect loops.
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'
kubectl rollout restart deployment/argocd-server -n argocd
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=240s

kubectl apply -f "${P3_DIR}/confs/argocd/ingress.yaml"

echo "Argo CD initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo
