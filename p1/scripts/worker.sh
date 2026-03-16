#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq && apt-get install -y -qq curl

# Attendre le token depose par le serveur dans /vagrant
timeout 180 sh -c 'until [ -f /vagrant/node-token ]; do sleep 2; done'
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.110:6443 K3S_TOKEN="$(cat /vagrant/node-token)" sh -

echo "Worker1 connecté au cluster."

echo "alias k=kubectl" >> ~/.bashrc
