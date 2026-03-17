#!/bin/bash

#globals
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y curl iptables

# Remove stale shared token from previous runs before server re-creates it.
rm -f /vagrant/k3s_token

# k3s config
echo "[LOG] - Configure k3s (/etc/rancher/k3s/config.yaml)"
mkdir -p /etc/rancher/k3s
sed "s/__NODE_IP__/$1/g" /vagrant/confs/Server.yaml.tpl > /etc/rancher/k3s/config.yaml

# k3s install (server mode is inferred from installer when K3S_URL is unset)
echo "[LOG] - Install k3s"
INTERFACE=$(ip -o -4 addr show | awk -v ip="$1" '$0 ~ ip {print $2}')
export INSTALL_K3S_EXEC="--flannel-iface=${INTERFACE}"
curl -sfL https://get.k3s.io | sh -
if [ $? -ne 0 ]; then
    echo "Failed to install k3s. Exiting."
    exit 1
fi

# share token
echo "[LOG] - Share token"
TIMEOUT=30
while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
    sleep 1
    TIMEOUT=$((TIMEOUT - 1))
    if [ "$TIMEOUT" -eq 0 ]; then
        echo "Token file not generated."
        exit 1
    fi
done
cp /var/lib/rancher/k3s/server/node-token /vagrant/k3s_token

echo "[LOG] - K3s installation completed successfully."

echo 'export PATH="/sbin:$PATH"' >> $HOME/.bashrc
echo "alias k='kubectl'" | sudo tee /etc/profile.d/00-aliases.sh > /dev/null

kubectl apply -f /vagrant/confs/app1/deployment.yaml
kubectl apply -f /vagrant/confs/app1/service.yaml
kubectl apply -f /vagrant/confs/app2/deployment.yaml
kubectl apply -f /vagrant/confs/app2/service.yaml
kubectl apply -f /vagrant/confs/app3/deployment.yaml
kubectl apply -f /vagrant/confs/app3/service.yaml
kubectl apply -f /vagrant/confs/ingress.yaml

echo "=== Cluster prêt ==="
kubectl get nodes,pods,svc,ingress -A || true