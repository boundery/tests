IMG_SIZE=300

build/server.img:
	@mkdir -p build
	dd if=/dev/zero of=$@ bs=$$((1024*1024)) count=$(IMG_SIZE)
	printf 'n\np\n1\n\n\nt\nc\nw\n' | fdisk $@
	mformat -i$@@@1M -s32 -h64 -t$(IMG_SIZE) -v"BNDRY TEST"
	@echo "precious" > build/preserve.txt
	mcopy -i$@@@1M build/preserve.txt ::
build/server.vmdk: build/server.img
	[ -f $@ ] || VBoxManage internalcommands createrawvmdk -filename $@ -rawdisk `readlink -f $<`
	@VBoxManage internalcommands sethduuid $@ 00000000-99aa-0000-8899-aabbccddeeff

build/server_data.vdi:
	@mkdir -p build/empty
	qemu-img convert -f vvfat -O vdi fat:32:build/empty $@
	@VBoxManage internalcommands sethduuid $@ 11111111-99aa-0000-8899-aabbccddeeff

#XXX Get deps right to reprovision VMs w/ files change?  Probably need explicit "provision" targets...

INET=build/stamp/inet
inet: $(INET)
$(INET):
	@mkdir -p build/stamp
	vagrant up inet
	@test -f $@ || ( echo "provisioning $(notdir $@) failed" && false )

BOUNDERY=build/stamp/boundery.me
boundery: $(BOUNDERY)
$(BOUNDERY): $(INET)
	@mkdir -p build/stamp
	vagrant up boundery.me
	@test -f $@ || ( echo "provisioning $(notdir $@) failed" && false )

ROUTER=build/stamp/router
router: $(ROUTER)
$(ROUTER):
	@mkdir -p build/stamp
	vagrant up router
	@test -f $@ || ( echo "provisioning $(notdir $@) failed" && false )

CLIENT=build/stamp/client
client: $(CLIENT)
$(CLIENT): $(ROUTER) $(INET) build/server.vmdk
	@mkdir -p build/stamp
	vagrant up client
	@test -f $@ || ( echo "provisioning $(notdir $@) failed" && false )

BOUNDERY_SSHCONF=build/boundery.sshconf
boundery-sshconf: $(BOUNDERY_SSHCONF)
$(BOUNDERY_SSHCONF): $(BOUNDERY)
	@mkdir -p build
	@vagrant ssh-config boundery.me | grep -v User > $@
	vagrant ssh boundery.me -c 'sudo cp -r .ssh /root/'

UPLOAD_CENTRAL=build/stamp/upload-central
upload-central: $(UPLOAD_CENTRAL)
$(UPLOAD_CENTRAL): $(BOUNDERY) $(BOUNDERY_SSHCONF)
	@test $(CENTRAL_SRC) || ( echo 'set CENTRAL_SRC' && false )
	vagrant ssh boundery.me -c '[ -f /usr/local/share/ca-certificates/pebble.minica.crt ]'
	vagrant upload $(CENTRAL_SRC)/setupserver /tmp/setupserver boundery.me
	vagrant ssh boundery.me -c 'echo fakepasswd | sudo /tmp/setupserver'
	SERVER=boundery.me SSH_CONF=`readlink -f $(BOUNDERY_SSHCONF)` make -C $(CENTRAL_SRC) deploy
	@echo Waiting for boundery.me containers to start...
	@vagrant ssh boundery.me -c 'while ! pidof -q nginx; do sleep 1; done'
	@vagrant ssh boundery.me -c 'while ! ss -tln | grep -q :443; do sleep 1; done'
	@touch $@

#XXX Change client/image uploads to use make deploy just like upload-central.
UPLOAD_LINUX=build/stamp/upload-linux
upload-linux: $(UPLOAD_LINUX)
$(UPLOAD_LINUX): $(BOUNDERY) $(BOUNDERY_SSHCONF)
	@test $(CLIENT_SRC) || ( echo 'set CLIENT_SRC' && false )
	vagrant ssh boundery.me -c '[ -f /usr/local/share/ca-certificates/pebble.minica.crt ]'
	make -C $(CLIENT_SRC) linux
	vagrant ssh boundery.me -c 'sudo mkdir -p /root/data/sslnginx/html/clients'
	scp -F $(BOUNDERY_SSHCONF) $(CLIENT_SRC)/linux/*.tar.gz \
	  root@boundery.me:/root/data/sslnginx/html/clients/
	@touch $@

UPLOAD_WINDOWS=build/stamp/upload-windows
upload-windows: $(UPLOAD_WINDOWS)
$(UPLOAD_WINDOWS): $(BOUNDERY) $(BOUNDERY_SSHCONF)
	@test $(CLIENT_SRC) || ( echo 'set CLIENT_SRC' && false )
	vagrant ssh boundery.me -c '[ -f /usr/local/share/ca-certificates/pebble.minica.crt ]'
	make -C $(CLIENT_SRC) windows
	vagrant ssh boundery.me -c 'sudo mkdir -p /root/data/sslnginx/html/clients'
	scp -F $(BOUNDERY_SSHCONF) $(CLIENT_SRC)/windows/*.msi \
	  root@boundery.me:/root/data/sslnginx/html/clients/
	@touch $@

UPLOAD_MACOS=build/stamp/upload-macos
upload-macos: $(UPLOAD_MACOS)
$(UPLOAD_MACOS): $(BOUNDERY) $(BOUNDERY_SSHCONF)
	@test $(CLIENT_SRC) || ( echo 'set CLIENT_SRC' && false )
	vagrant ssh boundery.me -c '[ -f /usr/local/share/ca-certificates/pebble.minica.crt ]'
	make -C $(CLIENT_SRC) macos
	vagrant ssh boundery.me -c 'sudo mkdir -p /root/data/sslnginx/html/clients'
	scp -F $(BOUNDERY_SSHCONF) $(CLIENT_SRC)/macOS/*.dmg \
	  root@boundery.me:/root/data/sslnginx/html/clients/
	@touch $@

UPLOAD_PCZIP=build/stamp/upload-pczip
upload-pczip: $(UPLOAD_PCZIP)
$(UPLOAD_PCZIP): $(BOUNDERY) $(BOUNDERY_SSHCONF)
	@test $(OS_SRC) || ( echo 'set OS_SRC' && false )
	vagrant ssh boundery.me -c '[ -f /usr/local/share/ca-certificates/pebble.minica.crt ]'
	make -C $(OS_SRC) pc_zip
	vagrant ssh boundery.me -c 'sudo mkdir -p /root/data/sslnginx/html/images'
	scp -F $(BOUNDERY_SSHCONF) $(OS_SRC)/build/amd64/images/pc.zip \
	  root@boundery.me:/root/data/sslnginx/html/images/
	@touch $@

UPLOAD_RPI3ZIP=build/stamp/upload-rpi3zip
upload-rpi3zip: $(UPLOAD_RPI3ZIP)
$(UPLOAD_RPI3ZIP): $(BOUNDERY) $(BOUNDERY_SSHCONF)
	@test $(OS_SRC) || ( echo 'set OS_SRC' && false )
	vagrant ssh boundery.me -c '[ -f /usr/local/share/ca-certificates/pebble.minica.crt ]'
	make -C $(OS_SRC) rpi3_zip
	vagrant ssh boundery.me -c 'sudo mkdir -p /root/data/sslnginx/html/images'
	scp -F $(BOUNDERY_SSHCONF) $(OS_SRC)/build/arm64/images/rpi3.zip \
	  root@boundery.me:/root/data/sslnginx/html/images/
	@touch $@

test-linux-pczip: $(CLIENT) $(BOUNDERY) build/server_data.vdi $(UPLOAD_CENTRAL) $(UPLOAD_PCZIP) $(UPLOAD_LINUX)
	vagrant halt -f server
	vagrant provision --provision-with install client
	@mdel -ibuild/server.img@@1M ::/pairingkey 2>/dev/null || true
	@dd conv=notrunc if=/dev/zero of=build/server.img seek=$$((0x100025)) count=1 bs=1 #FAT16 only!
	vagrant ssh client -c '/vagrant/run_test.sh pc' &
	@echo Waiting for client to finish writing image...
	@while ! mdir -b -ibuild/server.img@@1M ::/pairingkey 2>/dev/null; do sleep 1; done
	@while ! hd -v -s 0x100025 -n 1 build/server.img | grep -q '^00100025  00'; do sleep 1; done
#	vagrant up server
	wait #for vagrant run run_test.sh
#	XXX verify that preserve.txt contains "precious\n"

server-serial:
	@script/vboxmgr controlvm server_VBOXID changeuartmode1 server build/serial_cons.sock
	@echo "Ctrl-o to exit"
	@socat UNIX-CONNECT:build/serial_cons.sock STDIO,raw,echo=0,escape=0x0f
#	XXX Perhaps wire serial console back to file? Even better if socat also updates file...

client-vnc:
	@script/vboxmgr client_VBOXID
	gvncviewer localhost:0
