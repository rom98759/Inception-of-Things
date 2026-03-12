Vagrant.configure("2") do |config|
  config.vm.box = "debian/bullseye64"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 1024
    vb.cpus   = 1
    vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
  end

  config.vm.define "master" do |master|
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: "192.168.56.10"
    master.vm.network "forwarded_port", guest: 80, host: 8080
    master.vm.provision "shell", path: "scripts/master.sh"
  end

  config.vm.define "worker1" do |worker|
    worker.vm.hostname = "worker1"
    worker.vm.network "private_network", ip: "192.168.56.11"
    worker.vm.provision "shell", path: "scripts/worker.sh"
  end
end
