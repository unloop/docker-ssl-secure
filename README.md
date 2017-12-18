Securing Docker with TLS certificates
=======================================

#### ===> Creating directories for both the server and client certificate sets
```sh
$ sudo mkdir -p /etc/docker/ssl
$ mkdir -p ~/.docker/ssl
```

#### ===> Create and sign a CA key and certificate and copy the CA certificate into /etc/docker/ssl
```sh
$ openssl genrsa -out ~/.docker/ssl/ca-key.pem 2048
.+++
..........................................................................................................+++
e is 65537 (0x10001)

$ openssl req -x509 -new -nodes -key ~/.docker/ssl/ca-key.pem \
  -days 10000 -out ~/.docker/ssl/ca.pem -subj '/CN=docker-CA'

$ sudo cp ~/.docker/ssl/ca.pem /etc/docker/ssl
```

#### ===> Configuration file for the Docker client ~/.docker/ssl/openssl.cnf
```sh
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
```

#### ===> Configuration file for the Docker client /etc/docker/ssl/openssl.cnf
```sh
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = docker.local
IP.2 = 127.0.0.1
```

#### ===> Create and sign a certificate for the client
```sh
$ openssl genrsa -out ~/.docker/ssl/key.pem 2048
....................................+++
.............+++
e is 65537 (0x10001)

$ openssl req -new -key ~/.docker/ssl/key.pem -out ~/.docker/ssl/cert.csr \
  -subj '/CN=docker-client' -config ~/.docker/ssl/openssl.cnf

$ openssl x509 -req -in ~/.docker/ssl/cert.csr -CA ~/.docker/ssl/ca.pem \
  -CAkey ~/.docker/ssl/ca-key.pem -CAcreateserial \
  -out ~/.docker/ssl/cert.pem -days 365 -extensions v3_req \
  -extfile ~/.docker/ssl/openssl.cnf
Signature ok
subject=/CN=docker-client
Getting CA Private Key
```

#### ===> Create and sign a certificate for the server
```sh
$ sudo openssl genrsa -out /etc/docker/ssl/key.pem 2048
................................................................................+++
....................................+++
e is 65537 (0x10001)

$ sudo openssl req -new -key /etc/docker/ssl/key.pem \
  -out /etc/docker/ssl/cert.csr \
  -subj '/CN=docker-server' -config /etc/docker/ssl/openssl.cnf

$ sudo openssl x509 -req -in /etc/docker/ssl/cert.csr -CA ~/.docker/ssl/ca.pem \
  -CAkey ~/.docker/ssl/ca-key.pem -CAcreateserial \
  -out /etc/docker/ssl/cert.pem -days 365 -extensions v3_req \
  -extfile /etc/docker/ssl/openssl.cnf
Signature ok
subject=/CN=docker-client
Getting CA Private Key
```

#### ===> Enabling Docker Remote API on Ubuntu using systemd

1. Edit the file /lib/systemd/system/docker.service
```sh
$ sudo vi /lib/systemd/system/docker.service
```
2. Modify the line that starts with ExecStart to look like this:
```sh
ExecStart=/usr/bin/dockerd -H fd:// -H unix:///var/run/docker.sock -H tcp://0.0.0.0:2376 --tlsverify --tlscacert=/etc/docker/ssl/ca.pem --tlscert=/etc/docker/ssl/cert.pem --tlskey=/etc/docker/ssl/key.pem
```
3. Save the modified file
4. Make sure the Docker service notices the modified configuration
```sh
$ systemctl daemon-reload
```
5. Reload systemd and the Docker service
```sh
$ sudo systemctl daemon-reload
$ sudo systemctl restart docker
```
6. Set some environment variables to enable TLS for the client and use the client key we created
```sh
$ export DOCKER_HOST=tcp://docker.local:2376
$ export DOCKER_TLS_VERIFY=1
$ export DOCKER_CERT_PATH=~/.docker/ssl
$ docker info
```

#### ===> Using the TLS certificates with Docker Swarm

To secure Docker Swarm using these TLS certificates you will need to create TLS certificate/key pairs for each server using the same CA.
Add some arguments to the docker run command that you start Swarm Manager with the following:
```sh
$ docker run -d --name swarm-manager \
  -v /etc/docker/ssl:/etc/docker/ssl \
  --net=host swarm:latest manage \
  --tlsverify \
  --tlscacert=/etc/docker/ssl/ca.pem \
  --tlscert=/etc/docker/ssl/cert.pem \
  --tlskey=/etc/docker/ssl/key.pem \
  etcd://127.0.0.1:2379
```
Which you can then access using the docker client
```sh
$ export DOCKER_HOST=tcp://docker.local:2376
$ export DOCKER_TLS_VERIFY=1
$ export DOCKER_CERT_PATH=~/.docker/ssl
$ docker info
```
