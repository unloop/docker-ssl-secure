#!/bin/bash

DOCKER_SSL_PATH=/etc/docker/ssl
CLIENT_SSL_PATH=~/.docker/ssl

echo ""
echo "Securing Docker with TLS certificates"
echo ""
echo "===> Creating directories for both the server and client certificate sets"

sudo mkdir -p ${DOCKER_SSL_PATH}
mkdir -p ${CLIENT_SSL_PATH}


echo "===> Create and sign a CA key and certificate and copy the CA certificate into ${DOCKER_SSL_PATH}\n"

openssl genrsa -out ${CLIENT_SSL_PATH}/ca-key.pem 2048

openssl req -x509 -new -nodes -key ${CLIENT_SSL_PATH}/ca-key.pem \
  -days 10000 -out ${CLIENT_SSL_PATH}/ca.pem -subj '/CN=docker-CA'

sudo cp ${CLIENT_SSL_PATH}/ca.pem ${DOCKER_SSL_PATH}


echo "===> Configuration file for the Docker client ${CLIENT_SSL_PATH}/openssl.cnf"

bash -c "cat <<EOT > ${CLIENT_SSL_PATH}/openssl.cnf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
EOT"


echo "===> Configuration file for the Docker client ${DOCKER_SSL_PATH}/openssl.cnf"

sudo bash -c "cat <<EOT > ${DOCKER_SSL_PATH}/openssl.cnf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = $HOSTNAME
IP.1  = 127.0.0.1
EOT"


echo "\n"
echo "===> Create and sign a certificate for the client"

openssl genrsa -out ${CLIENT_SSL_PATH}/key.pem 2048

openssl req -new -key ${CLIENT_SSL_PATH}/key.pem -out ${CLIENT_SSL_PATH}/cert.csr \
    -subj '/CN=docker-client' -config ${CLIENT_SSL_PATH}/openssl.cnf

openssl x509 -req -in ${CLIENT_SSL_PATH}/cert.csr -CA ${CLIENT_SSL_PATH}/ca.pem \
  -CAkey ${CLIENT_SSL_PATH}/ca-key.pem -CAcreateserial \
  -out ${CLIENT_SSL_PATH}/cert.pem -days 365 -extensions v3_req \
  -extfile ${CLIENT_SSL_PATH}/openssl.cnf


echo "\n"
echo "===> Create and sign a certificate for the server"

sudo openssl genrsa -out ${DOCKER_SSL_PATH}/key.pem 2048

sudo openssl req -new -key ${DOCKER_SSL_PATH}/key.pem \
  -out ${DOCKER_SSL_PATH}/cert.csr \
  -subj '/CN=docker-server' -config ${DOCKER_SSL_PATH}/openssl.cnf

sudo openssl x509 -req -in ${DOCKER_SSL_PATH}/cert.csr -CA ${CLIENT_SSL_PATH}/ca.pem \
  -CAkey ${CLIENT_SSL_PATH}/ca-key.pem -CAcreateserial \
  -out ${DOCKER_SSL_PATH}/cert.pem -days 365 -extensions v3_req \
  -extfile ${DOCKER_SSL_PATH}/openssl.cnf
echo "\n"


echo "===> Enabling Docker Remote API on Ubuntu using systemd"
echo ""
echo "1. Edit the file /lib/systemd/system/docker.service"
echo "   $ sudo vi /lib/systemd/system/docker.service"
echo "2. Modify the line that starts with ExecStart to look like this:"
echo "   ExecStart=/usr/bin/dockerd -H fd:// -H unix:///var/run/docker.sock -H tcp://0.0.0.0:2376 --tlsverify --tlscacert=${DOCKER_SSL_PATH}/ca.pem --tlscert=${DOCKER_SSL_PATH}/cert.pem --tlskey=${DOCKER_SSL_PATH}/key.pem"
echo "3. Save the modified file"
echo "4. Make sure the Docker service notices the modified configuration"
echo "   $ systemctl daemon-reload"
echo "5. Reload systemd and the Docker service"
echo "   $ sudo systemctl daemon-reload"
echo "   $ sudo systemctl restart docker"
echo "6. Set some environment variables to enable TLS for the client and use the client key we created"
echo "   $ export DOCKER_HOST=tcp://${HOSTNAME}:2376"
echo "   $ export DOCKER_TLS_VERIFY=1"
echo "   $ export DOCKER_CERT_PATH=${CLIENT_SSL_PATH}"
echo "   $ docker info"
echo "\n"
echo "===> Using the TLS certificates with Docker Swarm"
echo ""
echo "To secure Docker Swarm using these TLS certificates you will need to create TLS certificate/key pairs for each server using the same CA."
echo "Add some arguments to the docker run command that you start Swarm Manager with the following:"
echo "$ docker run -d --name swarm-manager \\"
echo "  -v ${DOCKER_SSL_PATH}:/etc/docker/ssl \\"
echo "  --net=host swarm:latest manage \\"
echo "  --tlsverify \\"
echo "  --tlscacert=${DOCKER_SSL_PATH}/ca.pem \\"
echo "  --tlscert=${DOCKER_SSL_PATH}/cert.pem \\"
echo "  --tlskey=${DOCKER_SSL_PATH}/key.pem \\"
echo "  etcd://127.0.0.1:2379"
echo ""
echo "Which you can then access using the docker client"
echo "   $ export DOCKER_HOST=tcp://${HOSTNAME}:2376"
echo "   $ export DOCKER_TLS_VERIFY=1"
echo "   $ export DOCKER_CERT_PATH=${CLIENT_SSL_PATH}"
echo "   $ docker info"
echo "\n"