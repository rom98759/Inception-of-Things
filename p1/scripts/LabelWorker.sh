#!/bin/bash

# $1 = worker node name (lowercase, as Kubernetes normalizes it)
WORKER_NAME=$(echo "$1" | tr '[:upper:]' '[:lower:]')

echo "[LOG] - Waiting for worker node '${WORKER_NAME}' to join..."
TIMEOUT=120
until kubectl get node "${WORKER_NAME}" &>/dev/null; do
    sleep 3
    TIMEOUT=$((TIMEOUT - 3))
    [ "$TIMEOUT" -le 0 ] && echo "Timeout waiting for worker." && exit 1
done

kubectl wait --for=condition=Ready node/"${WORKER_NAME}" --timeout=120s
kubectl label node "${WORKER_NAME}" node-role.kubernetes.io/worker=worker --overwrite
echo "[LOG] - Worker node '${WORKER_NAME}' labeled successfully."
