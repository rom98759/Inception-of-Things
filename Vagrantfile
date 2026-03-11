Vagrant.configure("2") do |config|
  config.vm.box = "debian/bullseye64"

  config.vm.define "master" do |master|
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: "192.168.56.10"
    master.vm.network "forwarded_port", guest: 80, host: 8080
    master.vm.provision "shell", inline: <<-SHELL
      set -e
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq
      apt-get install -y -qq curl

      # Installer K3s server
      curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" sh -

      # Partager le token avec le worker via le dossier partagé /vagrant
      cp /var/lib/rancher/k3s/server/node-token /vagrant/node-token

      # Kubeconfig pour l'utilisateur vagrant
      mkdir -p /home/vagrant/.kube
      cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
      sed -i 's/127.0.0.1/192.168.56.10/' /home/vagrant/.kube/config
      chown -R vagrant:vagrant /home/vagrant/.kube

      # Attendre que l'API Kubernetes soit prête
      export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
      timeout 240 sh -c 'until kubectl get nodes >/dev/null 2>&1; do sleep 5; done'

      # Déployer les ressources Kubernetes
      kubectl apply -f /vagrant/nginx-deployment.yaml
      kubectl apply -f /vagrant/service.yaml
      kubectl apply -f /vagrant/ingress.yaml

      # Attente souple du pod nginx (ne casse pas le provisioning)
      if ! timeout 300 sh -c 'until kubectl get pod -l app=nginx -o jsonpath="{.items[0].status.phase}" 2>/dev/null | grep -Eq "Running|Succeeded"; do sleep 5; done'; then
        echo "[WARN] NGINX pas encore Running après 300s (cluster possiblement encore en initialisation)."
      fi

      echo "=== Cluster prêt ==="
      kubectl get nodes,pods,svc,ingress -A || true
    SHELL
  end

  config.vm.define "worker1" do |worker|
    worker.vm.hostname = "worker1"
    worker.vm.network "private_network", ip: "192.168.56.11"
    worker.vm.provision "shell", inline: <<-SHELL
      set -e
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq
      apt-get install -y -qq curl

      # Rejoindre le cluster K3s
      timeout 120 sh -c 'until [ -f /vagrant/node-token ]; do sleep 2; done'
      TOKEN=$(cat /vagrant/node-token)
      curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.10:6443 K3S_TOKEN="$TOKEN" sh -

      echo "Worker1 connecté au cluster."
    SHELL
  end
end
