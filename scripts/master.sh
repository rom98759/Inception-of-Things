#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq && apt-get install -y -qq curl

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" sh -

cp /var/lib/rancher/k3s/server/node-token /vagrant/node-token

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
timeout 240 sh -c 'until kubectl get nodes >/dev/null 2>&1; do sleep 5; done'

kubectl apply -f /vagrant/nginx-deployment.yaml
kubectl apply -f /vagrant/service.yaml
kubectl apply -f /vagrant/ingress.yaml

echo "=== Cluster prêt ==="
kubectl get nodes,pods,svc,ingress -A || true
