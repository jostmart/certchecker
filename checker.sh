#!/bin/bash

# Example on how to retrieve certs from the commandline
# Usage:
#   checkcert.sh cert.pem privkey.pem ca-chain.pem
# Certificates need to be in /data/certs/

cert=$1
privkey=$2
cafile=$3

# Evaluate input from above

files="$cert $privkey $cafile"
src=/data/certs

# Verify that all files we are supposed to deploy exist
for file in $files; do
  if [ ! -f ${src}/${file} ]; then
    echo "Missing file: $file"
    exit 1
  fi
done


# Start openssl server in order to verify certificates before we install them
# Without nohup, openssl crashes after the first client request
echo "Starting openssl server on port 7555"
(nohup openssl s_server -quiet -accept 7555 -cert ${src}/${cert} -CAfile ${src}/${cafile} -key ${src}/${privkey}) &
sleep 1

# Be very sure that the openssl server is running on port 7555
netstat -lntp | grep 7555 | grep -i listen | grep -i openssl
res=$?

if [ $res != 0 ]; then
  echo "OpenSSL server could not start. Check certificates"
  exit 1
else
  # Connect to server
  echo "As a client, connect to the server to verify the certificate"
  openssl s_client -showcerts -connect localhost:7555 -CAfile ${src}/${cafile} | grep "return code: 0 (ok)"
  res=$?

  echo "Return code (should be 0): $res"

  # Close down openssl server
  # Yes i am aware of pidof. But I need to make certain I kill the right process
  # since "pidof openssl" could return other openssl pid:s
  s_server_pid=`(ps aux | grep "openssl s_server" | awk '{print $2}')`
  kill -15 $s_server_pid

  # This will check the return code from grep. Not openssl.
  if [ $res != 0 ]; then
    echo "Certificate verification failed"
    exit 1
  else
    echo "Certificate seem to be OK"
  fi

fi

exit 0
