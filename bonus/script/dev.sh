#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P3_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

kubectl apply -f "${P3_DIR}/confs/dev/namespace.yaml"
kubectl apply -f "${P3_DIR}/confs/dev/application.yaml"

echo "Argo CD application state:"
kubectl get applications.argoproj.io -n argocd
echo "Dev resources:"
kubectl get all -n dev
kubectl get ingress -n dev
