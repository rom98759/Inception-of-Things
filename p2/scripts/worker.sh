#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq && apt-get install -y -qq curl

timeout 120 sh -c 'until [ -f /vagrant/node-token ]; do sleep 2; done'
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.10:6443 K3S_TOKEN="$(cat /vagrant/node-token)" sh -

echo "Worker1 connecté au cluster."
