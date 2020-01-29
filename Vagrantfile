# -*- mode: ruby -*-
# vi: set ft=ruby :

vagrant_dir = File.join(File.dirname(File.expand_path(__FILE__)), ".vagrant")

Vagrant.configure("2") do |config|
  config.vm.box = "debian/contrib-buster64"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "512"
    vb.cpus = 1
    vb.linked_clone = true
  end

  ################# SIMULATED INTERNET #################
  config.vm.define "inet" do |inet|
    inet.vm.hostname = "inet"
    inet.vm.network "private_network", ip: "30.0.0.1",
                    virtualbox__intnet: "router_inet"
    inet.vm.network "private_network", ip: "30.0.1.1",
                    virtualbox__intnet: "boundery_inet"
    inet.vm.provision "shell", inline: <<-SHELL
      sudo apt-get update
      sudo apt-get install -y --no-install-recommends python3-dnslib dnsutils socat netsed

      sudo cp /vagrant/boundery/nodnsupdate /etc/dhcp/dhclient-enter-hooks.d/
      sudo chmod a+x /etc/dhcp/dhclient-enter-hooks.d/nodnsupdate

      sudo cp /vagrant/inet/intercept.py /usr/local/sbin/

      #https://github.com/hal/testsuite.next/blob/master/how-run-pebble.md
      sudo wget https://github.com/letsencrypt/pebble/releases/download/v2.3.0/pebble_linux-amd64 -O /usr/local/sbin/pebble
      sudo chmod a+x /usr/local/sbin/pebble

      sudo cp /vagrant/inet/rc.local /etc/
      sudo chmod a+x /etc/rc.local
      sudo /etc/rc.local
    SHELL
  end

  ################# BOUNDERY SERVER #################
  config.vm.define "boundery.me" do |boundery|
    boundery.vm.hostname = "boundery"
    boundery.vm.network "private_network", ip: "30.0.1.9",
                        virtualbox__intnet: "boundery_inet"
    boundery.vm.provision "shell", inline: <<-SHELL
      sudo cp /vagrant/boundery/nodnsupdate /etc/dhcp/dhclient-enter-hooks.d/
      sudo chmod a+x /etc/dhcp/dhclient-enter-hooks.d/nodnsupdate

      sudo cp /vagrant/boundery/rc.local /etc/
      sudo chmod a+x /etc/rc.local
      sudo /etc/rc.local

      #XXX Install docker and any other deps.  Basically run setup_server
    SHELL

    #XXX Provisioner to install containers, os images, client installers, etc.
  end

  ################# HOME ROUTER #################
  config.vm.define "router" do |router|
    router.vm.hostname = "router"
    router.vm.network "private_network", ip: "192.168.1.1",
                      virtualbox__intnet: "client_router"
    router.vm.network "private_network", ip: "30.0.0.150",
                      virtualbox__intnet: "router_inet"
    router.vm.provision "shell", inline: <<-SHELL
      sudo apt-get update
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y dnsmasq iptables-persistent

      sudo cp /vagrant/router/rules.v4 /etc/iptables/
      sudo /etc/init.d/netfilter-persistent restart

      sudo cp /vagrant/router/dhcp.conf /vagrant/router/dns.conf /etc/dnsmasq.d/
      sudo /etc/init.d/dnsmasq restart

      sudo cp /vagrant/router/rc.local /etc/
      sudo chmod a+x /etc/rc.local
      sudo /etc/rc.local
    SHELL
  end

  ################# CLIENT #################
  config.vm.define "client" do |client|
    client.vm.hostname = "client"
    client.vm.network "private_network",
                      virtualbox__intnet: "client_router", type: "dhcp"
    #XXX Figure out how to attach USB stick to write OS image to.  See: client/Vagrantfile
    #    .vmdk can wrap a raw image, so no need to copy to .vdi:
    #    VBoxManage internalcommands createrawvmdk -filename test.vmdk -rawdisk raw.img
    client.vm.provision "shell", inline: <<-SHELL
      #XXX Install selenium/chromedriver/any other deps.
      #XXX Because we short circuit the dyndns NS forward to the pi, need to explicitly
      #    check that username.boundery.me gets the right NS destination (30.0.0.150).
    SHELL

    #XXX Provisioner to copy in tests, install client and run tests
  end

  ################# HOME SERVER #################
  config.vm.define "server", autostart: false do |server|
    config.vm.box = "sridhav/empty"
    config.vm.provider "virtualbox" do |vb|
      #vb.gui = true
      vb.linked_clone = false
      vb.memory = "1024"

      vb.customize ["modifyvm", :id, "--firmware", "efi"]
      #vb.customize ['storageattach', :id, '--storagectl', 'SATA', '--port', 1, '--device', 0,
      #              '--type', 'hdd', '--medium', 'boot.vmdk']

      serial_log = File.join(vagrant_dir, "server_cons.log")
      vb.customize ["modifyvm", :id, "--uart1", "0x3F8", "4", "--uartmode1", "file", serial_log]
    end

    server.vm.hostname = "server"
    #server.vm.network "private_network", :mac => "443839FFF001", :adapter => 1,
    #                  virtualbox__intnet: "client_router", auto_config: false
    server.vm.network "private_network", :mac => "443839FFF001",
                      virtualbox__intnet: "client_router", type: "dhcp"

    #XXX Need to disable/redirect 'vagrant ssh' for "Waiting for machine to boot"
    #server.ssh.port=60000
    #server.ssh.host = "192.168.1.9"
    server.vm.synced_folder ".", "/vagrant", disabled: true

    #XXX Attach (and boot off of) USB stick that client wrote the image to.
    #XXX Attach USB stick for RW storage.
  end
end
