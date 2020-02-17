# -*- mode: ruby -*-
# vi: set ft=ruby :

build_dir = File.join(File.dirname(File.expand_path(__FILE__)), "build")

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
      #docker run --rm -it -v `pwd`:/output modedemploi/minica \
      #  -ca-cert pebble.minica.pem -ca-key pebble.minica.key.pem \
      #  -domains acme-v02.api.letsencrypt.org,acme-staging-v02.api.letsencrypt.org,localhost \
      #  -ip-addresses 30.0.0.1,30.0.1.1,127.0.0.1
      #sudo chown -R ...
      if ! [ -x /usr/local/sbin/pebble ]; then
        sudo wget https://github.com/letsencrypt/pebble/releases/download/v2.3.0/pebble_linux-amd64 -O /usr/local/sbin/pebble
        sudo chmod a+x /usr/local/sbin/pebble
      fi
      mkdir -p /etc/pebble/
      sudo cp -r /vagrant/inet/pebble/* /etc/pebble/
      sudo cp /vagrant/inet/rewrite_pebble.sh /usr/local/sbin/
      sudo chmod a+x /usr/local/sbin/rewrite_pebble.sh

      sudo cp /vagrant/inet/rc.local /etc/
      sudo chmod a+x /etc/rc.local
      sudo /etc/rc.local
    SHELL
  end

  ################# BOUNDERY SERVER #################
  config.vm.define "boundery.me" do |boundery|
    boundery.vm.hostname = "boundery"
    boundery.vm.network "private_network", auto_config: false,
                        virtualbox__intnet: "boundery_inet"
    boundery.vm.provision "shell", inline: <<-SHELL
      sudo cp /vagrant/boundery/nodnsupdate /etc/dhcp/dhclient-enter-hooks.d/
      sudo chmod a+x /etc/dhcp/dhclient-enter-hooks.d/nodnsupdate

      sudo cp /vagrant/boundery/boundery.conf /etc/network/interfaces.d/
      sudo ifup -a

      sudo cp /vagrant/inet/pebble/pebble.minica.pem /usr/local/share/ca-certificates/pebble.minica.crt
      sudo update-ca-certificates

      sudo mkdir -p /root/data/centralui
      sudo cp /vagrant/boundery/email.json /vagrant/boundery/recaptcha.json /root/data/centralui/

      sudo cp /vagrant/boundery/rc.local /etc/
      sudo chmod a+x /etc/rc.local
      sudo /etc/rc.local
    SHELL
  end

  ################# HOME ROUTER #################
  config.vm.define "router" do |router|
    router.vm.hostname = "router"
    router.vm.network "private_network", auto_config: false,
                      virtualbox__intnet: "client_router"
    router.vm.network "private_network", auto_config: false,
                      virtualbox__intnet: "router_inet"
    router.vm.provision "shell", inline: <<-SHELL
      sudo apt-get update
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y dnsmasq iptables-persistent

      sudo cp /vagrant/router/router.conf /etc/network/interfaces.d/
      sudo ifup -a

      sudo cp /vagrant/router/rules.v4 /etc/iptables/
      sudo /etc/init.d/netfilter-persistent restart

      sudo cp /vagrant/router/dhcp.conf /vagrant/router/dns.conf /etc/dnsmasq.d/
      sudo /etc/init.d/dnsmasq restart
    SHELL
  end

  ################# CLIENT #################
  config.vm.define "client" do |client|
    config.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"

      vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 1, '--device', 0,
                    '--type', 'hdd', '--mtype', 'shareable', '--hotpluggable', 'on',
                    '--medium', File.join(build_dir, "server.vmdk")]
    end

    client.vm.hostname = "client"
    client.vm.network "private_network",
                      virtualbox__intnet: "client_router", type: "dhcp"
    client.vm.provision "shell", inline: <<-SHELL
      #XXX Install selenium/chromedriver/any other deps.
      #XXX Because we short circuit the dyndns NS forward to the pi, need to explicitly
      #    check that username.boundery.me gets the right NS destination (30.0.0.150).
      #    dig ns nolan.boundery.me. @boundery.me.

      sudo cp /vagrant/client/rc.local /etc/
      sudo chmod a+x /etc/rc.local
      sudo /etc/rc.local
    SHELL

    #XXX Provisioner to install client from boundery.me
    #XXX Provisioner to copy in (or rely on /vagrant?) and run tests
  end

  ################# HOME SERVER #################
  config.vm.define "server", autostart: false do |server|
    config.vm.box = "sridhav/empty"
    config.vm.provider "virtualbox" do |vb|
      #vb.gui = true
      vb.linked_clone = false
      vb.memory = "1024"

      vb.customize ["modifyvm", :id, "--firmware", "efi"]

      vb.customize ['storageattach', :id, '--storagectl', 'SATA', '--port', 1, '--device', 0,
                    '--type', 'hdd', '--mtype', 'shareable', '--hotpluggable', 'on',
                    '--medium', File.join(build_dir, "server.vmdk")]

      serial_log = File.join(build_dir, "server_cons.log")
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

    #XXX Need to figure out how to get pebble's root cert into the os...
    #XXX Attach USB stick for RW storage.
  end
end
