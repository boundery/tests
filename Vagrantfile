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

  config.trigger.after :destroy, :halt, :suspend do |trigger|
    trigger.ruby do |env, machine|
      `rm -f build/stamp/#{machine.name}`
    end
  end
  config.trigger.after :destroy do |trigger|
    trigger.ruby do |env, machine|
      `rm -f build/stamp/#{machine.name}.prov`
    end
  end

  ################# SIMULATED INTERNET #################
  config.vm.define "inet" do |inet|
    inet.vm.hostname = "inet"
    inet.vm.network "private_network", ip: "30.0.0.1",
                    virtualbox__intnet: "router_inet"
    inet.vm.network "private_network", ip: "30.0.1.1",
                    virtualbox__intnet: "boundery_inet"
    inet.vm.provision "shell", inline: <<-SHELL
      set -e

      sudo apt-get update
      sudo apt-get install -y --no-install-recommends python3-dnslib dnsutils socat netsed
      sudo apt purge -y 'exim4-*'

      sudo cp /vagrant/boundery/nodnsupdate /etc/dhcp/dhclient-enter-hooks.d/
      sudo chmod a+x /etc/dhcp/dhclient-enter-hooks.d/nodnsupdate

      sudo cp /vagrant/inet/intercept.py /vagrant/inet/fake_smtpd.py /usr/local/sbin/

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

      touch /vagrant/build/stamp/inet.prov
    SHELL
  end

  ################# BOUNDERY SERVER #################
  config.vm.define "boundery.me" do |boundery|
    boundery.vm.hostname = "boundery"
    boundery.vm.network "private_network", auto_config: false,
                        virtualbox__intnet: "boundery_inet"

    config.trigger.after :destroy do |trigger|
      trigger.run = {inline: "bash -c 'rm -f build/stamp/upload-*'"}
    end

    boundery.vm.provision "shell", inline: <<-SHELL
      set -e

      sudo cp /vagrant/boundery/nodnsupdate /etc/dhcp/dhclient-enter-hooks.d/
      sudo chmod a+x /etc/dhcp/dhclient-enter-hooks.d/nodnsupdate

      sudo cp /vagrant/boundery/boundery.conf /etc/network/interfaces.d/
      sudo ifup -a

      sudo cp /vagrant/inet/pebble/pebble.minica.pem /usr/local/share/ca-certificates/pebble.minica.crt
      sudo update-ca-certificates

      sudo mkdir -p /root/data/centralui
      sudo cp /vagrant/boundery/email.json /root/data/centralui/

      sudo cp /vagrant/boundery/rc.local /etc/
      sudo chmod a+x /etc/rc.local
      sudo /etc/rc.local

      touch /vagrant/build/stamp/boundery.me.prov
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
      set -e

      sudo apt-get update
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y dnsmasq iptables-persistent

      sudo cp /vagrant/router/router.conf /etc/network/interfaces.d/
      sudo ifup -a

      sudo cp /vagrant/router/rules.v4 /etc/iptables/
      sudo /etc/init.d/netfilter-persistent restart

      sudo cp /vagrant/router/dhcp.conf /vagrant/router/dns.conf /etc/dnsmasq.d/
      sudo /etc/init.d/dnsmasq restart

      touch /vagrant/build/stamp/router.prov
    SHELL
  end

  ################# CLIENT #################
  config.vm.define "client" do |client|
    client.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"

      vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 1, '--device', 0,
                    '--type', 'hdd', '--mtype', 'shareable', '--hotpluggable', 'on',
                    '--medium', File.join(build_dir, "server.vmdk")]
    end

    client.vm.hostname = "client"
    client.vm.network "private_network",
                      virtualbox__intnet: "client_router", type: "dhcp"
    client.vm.network "forwarded_port", host: 5910, guest: 5900
    client.vm.network "forwarded_port", host: 22222, guest: 22222
    client.vm.provision "shell", inline: <<-SHELL
      set -e

      sudo apt-key add /vagrant/client/zt-gpg-key
      sudo cp /vagrant/client/zt.list /etc/apt/sources.list.d/zt.list
      sudo apt-get update
      #XXX We install python3-cffi-backend here due to a briefcase bug. bug 44?
      sudo apt-get install -y --no-install-recommends network-manager xvfb x11vnc \
           python3-selenium chromium-driver chromium-sandbox libnss3-tools \
           python3-cffi-backend python3-paramiko zerotier-one

      sudo cp /vagrant/fake_vagrant_sshd.py /usr/local/sbin/

      while ! ip addr show dev eth1 | grep -q 'inet 192[.]168[.]1[.]'; do
        sleep 1
      done

      if ! host acme-v02.api.letsencrypt.org | grep -q 'address 30[.]0[.]'; then
        echo "acme points to the real addr, host DNS leaking in?" >&2
        exit 91
      fi

      sudo cp /vagrant/client/rc.local /etc/
      sudo chmod a+x /etc/rc.local
      sudo /etc/rc.local #XXX Need to wait for local network before here.

      touch /vagrant/build/stamp/client.prov
    SHELL

    client.vm.provision "install", type: "shell", run: "never", privileged: false, inline: <<-SHELL
      set -e

      if ! host acme-v02.api.letsencrypt.org | grep -q 'address 30[.]0[.]'; then
        echo "acme points to the real addr, host DNS leaking in?" >&2
        exit 91
      fi

      if mount | grep -q ^/dev/sdb1; then
        echo "/dev/sdb1 already mounted!" >&2
        exit 92
      fi

      rm -rf boundery-linux-client*
      wget https://boundery.me/static/clients/boundery-linux-client.tar.gz
      tar zxvf boundery-linux-client.tar.gz
      pushd boundery-linux-client
      ./Boundery_Client-*-x86_64.AppImage --appimage-extract
      popd

      #Make root cert available to client's embedded ca list.
      cp /etc/ssl/certs/ca-certificates.crt boundery-linux-client/squashfs-root/usr/app_packages/certifi/cacert.pem

      #Make root cert available to chromium/chromedriver's embedded ca list.
      rm -rf .pki
      mkdir -p .pki/nssdb
      certutil -N --empty-password -d sql:/home/vagrant/.pki/nssdb
      certutil -A -n "fakeroot" -t "TCu,Cu,Tu" -i /usr/local/share/ca-certificates/fakeroot.crt \
          -d sql:/home/vagrant/.pki/nssdb || true
    SHELL
  end

  ################# HOME SERVER #################
  config.vm.define "server", autostart: false do |server|
    server.vm.box = "sridhav/empty"
    server.vm.provider "virtualbox" do |vb|
      #vb.gui = true
      vb.linked_clone = false
      #We set memory to 1025 to signal the OS to install the pebble certificate.
      vb.memory = "1025"

      vb.customize ["modifyvm", :id, "--firmware", "efi"]

      #--port 0 clobbers the empty /dev/sda image in the base box.
      vb.customize ['storageattach', :id, '--storagectl', 'SATA', '--port', 0, '--device', 0,
                    '--type', 'hdd', '--mtype', 'shareable', '--hotpluggable', 'on',
                    '--medium', File.join(build_dir, "server.vmdk")]
      vb.customize ['storageattach', :id, '--storagectl', 'SATA', '--port', 1, '--device', 0,
                    '--type', 'hdd', '--hotpluggable', 'on',
                    '--medium', File.join(build_dir, "server_data.vdi")]

      serial_log = File.join(build_dir, "serial_cons.log")
      vb.customize ["modifyvm", :id, "--uart1", "0x3F8", "4", "--uartmode1", "file", serial_log]
    end

    server.vm.hostname = "server"
    #adapter=>1 makes it replace the default VBox SlirpNAT interface.
    server.vm.network "private_network", :mac => "443839FFF001", :adapter => 1,
                      virtualbox__intnet: "client_router", auto_config: false

    #Redirect this to our python dummy sshd
    server.ssh.port=22222
    server.ssh.host = "127.0.0.1"
    server.vm.synced_folder ".", "/vagrant", disabled: true
  end
end
