#!/usr/bin/env python
import socket
import sys
import threading
import paramiko

class Server(paramiko.ServerInterface):
    def check_channel_request(self, kind, chanid):
        if kind == 'session':
            return paramiko.OPEN_SUCCEEDED
    def check_auth_publickey(self, username, key):
        return paramiko.AUTH_SUCCESSFUL
    def get_allowed_auths(self, username):
        return 'publickey'

    def check_channel_exec_request(self, channel, command):
        threading.Thread(target=self.handle_cmd, args=[command, channel],
                         daemon=True).start()
        return True

    def check_channel_pty_request(self, channel, term, width, height,
                                  pixelwidth, pixelheight, modes):
        assert(False)

    def handle_cmd(self, cmd, chan):
        ret = self.handle_cmd_streams(cmd.decode(), chan.makefile('r'),
                                      chan.makefile('w'), chan.makefile_stderr('w'))
        chan.send_exit_status(ret)
        chan.close()

    def handle_cmd_streams(self, cmd, stdin, stdout, stderr):
        last_exit = 0
        print("cmd:", cmd)
        if cmd == '' or 'bash -l' in cmd:
            for line in stdin:
                line=line[:-1]
                print('line:', line)

                if line.startswith('(>&2 '):
                    out = stderr
                    line = line[5:-1]
                else:
                    out = stdout

                if line.startswith('printf \''):
                    out.write(line[8:-1])
                elif line == 'exit':
                    break

                out.flush()
        elif cmd.startswith('scp -t '):
            #Assume they're only sending 1 file, and respond to all msgs.
            stdout.write('\0' * 7)
            print('XXX \'%s\'' % stdin.read())
        return last_exit

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(('', 22222))
sock.listen(5)

print("Listening")
while True:
    client, addr = sock.accept()
    print("Connection")
    t = paramiko.Transport(client)
    t.set_gss_host(socket.getfqdn(""))
    t.load_server_moduli()
    t.add_server_key( paramiko.RSAKey.generate(bits=1024))
    print("Starting ssh session")
    t.start_server(server=Server())
