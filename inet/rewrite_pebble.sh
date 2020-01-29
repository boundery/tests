#!/bin/sh

socat openssl-listen:443,reuseaddr,fork,cert=/etc/pebble/acme-v02.api.letsencrypt.org/cert.pem,key=/etc/pebble/acme-v02.api.letsencrypt.org/key.pem,verify=0 tcp:localhost:4441 &

netsed tcp 4441 127.0.0.1 4442 's/GET %2fdirectory HTTP/GET %2fdir HTTP/1o' &

socat -v tcp-listen:4442,reuseaddr,fork ssl:localhost:4443,verify=0 &

wait
