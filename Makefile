
.PHONY: start-vms
start-vms:
	vagrant up

BOUNDERY_SSHCONF=build/boundery.sshconf
boundery-sshconf: $(BOUNDERY_SSHCONF)
$(BOUNDERY_SSHCONF): start-vms
	@mkdir -p build
	@vagrant ssh-config boundery.me | grep -v User > $@
	vagrant ssh boundery.me -c 'sudo cp -r .ssh /root/'

upload-central: start-vms $(BOUNDERY_SSHCONF)
	@test $(CENTRAL_SRC) || ( echo 'set CENTRAL_SRC' && false)
	vagrant ssh boundery.me -c '[ -f /usr/local/share/ca-certificates/pebble.minica.crt ]'
	vagrant upload $(CENTRAL_SRC)/setupserver /tmp/setupserver boundery.me
	vagrant ssh boundery.me -c 'echo fakepasswd | sudo /tmp/setupserver'
	SERVER=boundery.me SSH_CONF=`readlink -f $(BOUNDERY_SSHCONF)` make -C $(CENTRAL_SRC) deploy

#XXX Change client/image uploads to use make deploy just like upload-central.
upload-linux: start-vms $(BOUNDERY_SSHCONF)
	@test $(CLIENT_SRC) || ( echo 'set CLIENT_SRC' && false)
	vagrant ssh boundery.me -c '[ -f /usr/local/share/ca-certificates/pebble.minica.crt ]'
	make -C $(CLIENT_SRC) linux
	vagrant ssh boundery.me -c 'sudo mkdir -p /root/data/sslnginx/html/clients'
	scp -F $(BOUNDERY_SSHCONF) $(CLIENT_SRC)/linux/*.tar.gz \
	  root@boundery.me:/root/data/sslnginx/html/clients/

upload-windows: start-vms $(BOUNDERY_SSHCONF)
	@test $(CLIENT_SRC) || ( echo 'set CLIENT_SRC' && false)
	vagrant ssh boundery.me -c '[ -f /usr/local/share/ca-certificates/pebble.minica.crt ]'
	make -C $(CLIENT_SRC) windows
	vagrant ssh boundery.me -c 'sudo mkdir -p /root/data/sslnginx/html/clients'
	scp -F $(BOUNDERY_SSHCONF) $(CLIENT_SRC)/windows/*.msi \
	  root@boundery.me:/root/data/sslnginx/html/clients/

upload-macos: start-vms $(BOUNDERY_SSHCONF)
	@test $(CLIENT_SRC) || ( echo 'set CLIENT_SRC' && false)
	vagrant ssh boundery.me -c '[ -f /usr/local/share/ca-certificates/pebble.minica.crt ]'
	make -C $(CLIENT_SRC) macos
	vagrant ssh boundery.me -c 'sudo mkdir -p /root/data/sslnginx/html/clients'
	scp -F $(BOUNDERY_SSHCONF) $(CLIENT_SRC)/macOS/*.dmg \
	  root@boundery.me:/root/data/sslnginx/html/clients/

upload-pczip: start-vms
	@test $(OS_SRC) || ( echo 'set OS_SRC' && false)
	vagrant ssh boundery.me -c '[ -f /usr/local/share/ca-certificates/pebble.minica.crt ]'
	make -C $(OS_SRC) pc_zip
	vagrant ssh boundery.me -c 'sudo mkdir -p /root/data/sslnginx/html/images'
	scp -F $(BOUNDERY_SSHCONF) $(OS_SRC)/build/amd64/images/pc.zip \
	  root@boundery.me:/root/data/sslnginx/html/images/

upload-rpi3zip: start-vms
	@test $(OS_SRC) || ( echo 'set OS_SRC' && false)
	vagrant ssh boundery.me -c '[ -f /usr/local/share/ca-certificates/pebble.minica.crt ]'
	make -C $(OS_SRC) rpi3_zip
	vagrant ssh boundery.me -c 'sudo mkdir -p /root/data/sslnginx/html/images'
	scp -F $(BOUNDERY_SSHCONF) $(OS_SRC)/build/arm64/images/rpi3.zip \
	  root@boundery.me:/root/data/sslnginx/html/images/
