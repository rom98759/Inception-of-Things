Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  config.vm.define "master" do |master|
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: "192.168.56.10"
    master.vm.network "forwarded_port", guest: 80, host: 8080
    master.vm.provision "shell", inline: <<-SHELL
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

      # Déployer les ressources Kubernetes
      export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
      kubectl apply -f /vagrant/nginx-deployment.yaml
      kubectl apply -f /vagrant/service.yaml
      kubectl apply -f /vagrant/ingress.yaml
      kubectl rollout status deployment/nginx --timeout=120s

      echo "=== Cluster prêt ==="
      kubectl get nodes,pods,svc,ingress -A
    SHELL
  end

  config.vm.define "worker1" do |worker|
    worker.vm.hostname = "worker1"
    worker.vm.network "private_network", ip: "192.168.56.11"
    worker.vm.provision "shell", inline: <<-SHELL
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq
      apt-get install -y -qq curl

      # Rejoindre le cluster K3s
      TOKEN=$(cat /vagrant/node-token)
      curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.10:6443 K3S_TOKEN="$TOKEN" sh -

      echo "Worker1 connecté au cluster."
    SHELL
  end
end
