#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${K3D_CLUSTER_NAME:-iot-cluster}"
AGENTS="${K3D_AGENTS:-1}"

if ! command -v k3d >/dev/null 2>&1; then
	echo "k3d not found. Run script/necessary_packages.sh first."
	exit 1
fi

if k3d cluster list | awk 'NR>1 {print $1}' | grep -qx "${CLUSTER_NAME}"; then
	echo "Cluster ${CLUSTER_NAME} already exists."
else
	k3d cluster create "${CLUSTER_NAME}" \
		--agents "${AGENTS}" \
		--port "8080:80@loadbalancer"
fi

kubectl cluster-info
kubectl wait --for=condition=Ready node --all --timeout=180s
kubectl get nodes -o wide
