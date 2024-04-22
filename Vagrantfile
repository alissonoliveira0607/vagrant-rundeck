# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2204"
  config.vm.network "public_network",bridge: "Ethernet"
  config.vm.hostname = "rundeck"

  config.vm.provider :virtualbox do |vb|
    vb.name = "rundeck"
    vb.gui =  false
    vb.memory = 4096
    vb.cpus = 2
  end
  config.vm.provision "shell", path: "./provision/provision.sh"

end
