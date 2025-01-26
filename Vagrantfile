Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2004"
  config.vm.hostname = "rundeck"
  
  config.vm.provider "hyperv" do |hv|
    hv.vmname = "rundeck"
    hv.memory = 4096
    hv.cpus = 1
    hv.maxmemory = nil         # Definindo a memória máxima (deixe como nil, se não precisar limitar)
  end

  #config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.network "public_network", bridge: "sw-external"
  
  config.vm.provision "shell", path: "provision/provision.sh"
end