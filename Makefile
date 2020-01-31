
.PHONY: start-vms
start-vms:
	vagrant up

install-central: start-vms
	@test $(CENTRAL_SRC)
	@mkdir -p build
	@vagrant ssh-config boundery.me | grep -v User > build/boundery.sshconf
	vagrant ssh boundery.me -c '[ -f /usr/local/share/ca-certificates/pebble.minica.crt ]'
	vagrant upload $(CENTRAL_SRC)/setupserver /tmp/setupserver boundery.me
	vagrant ssh boundery.me -c 'echo fakepasswd | sudo /tmp/setupserver'
	vagrant ssh boundery.me -c 'sudo cp -r .ssh /root/'
	SERVER=boundery.me SSH_CONF=`readlink -f build/boundery.sshconf` make -C $(CENTRAL_SRC) deploy
