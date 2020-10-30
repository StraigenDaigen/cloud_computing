#!/usr/bin/env bash

apt update && apt upgrade
apt-get install  apache2 -y

echo "instalando lxd"
sudo snap install lxd
sudo gpasswd -a vagrant lxd
echo "lxd instalado"


cat <<EOF | lxd init --preseed

config:
  core.https_address: 192.168.100.8:8443
  core.trust_password: miniproyecto1
networks:
- config:
    bridge.mode: fan
    fan.underlay_subnet: 192.168.100.0/24
  description: ""
  name: lxdfan0
  type: ""
  project: default
storage_pools:
- config: {}
  description: ""
  name: local
  driver: dir
profiles:
- config: {}
  description: ""
  devices:
    eth0:
      name: eth0
      network: lxdfan0
      type: nic
    root:
      path: /
      pool: local
      type: disk
  name: default
cluster:
  server_name: web1UbuntuV2
  enabled: true
  member_config: []
  cluster_address: ""
  cluster_certificate: ""
  server_address: ""
  cluster_password: ""

EOF



echo "Creando Contenedor web1"
lxc launch ubuntu:18.04 web1 --target web1UbuntuV2
echo "Contenedor web1 creado"
sleep 10

lxc exec web1 -- apt update && apt upgrade
lxc exec web1 -- apt-get install apache2 -y 
lxc exec web1 -- systemctl restart apache2


echo "Configurar index.html"

touch /home/vagrant/index.html
cat <<TEST> /home/vagrant/index.html
<!DOCTYPE html>
<html>
<body>
<h1>WEB 1</h1>
<p>Bienvenido al Web 1 del Miniproyecto 1 de Computacion en la Nube</p>
</body>
</html>
TEST

lxc file push /home/vagrant/index.html web1/var/www/html/index.html

lxc exec web1 -- systemctl restart apache2

lxc config device add web1 http proxy listen=tcp:0.0.0.0:11080 connect=tcp:127.0.0.1:80

echo "Creando Contenedor web2backup"
lxc launch ubuntu:18.04 web2backup --target web1UbuntuV2
echo "Contenedor web2backup creado"
sleep 10

lxc exec web2backup -- apt update && apt upgrade
lxc exec web2backup -- apt-get install apache2 -y 
lxc exec web2backup -- systemctl restart apache2


echo "Configurar index.html"

touch /home/vagrant/index.html
cat <<TEST> /home/vagrant/index.html
<!DOCTYPE html>
<html>
<body>
<h1>Backup WEB 2</h1>
<p>Bienvenido al contenedor de backup de Web 2 del Miniproyecto 1 de Computacion en la Nube</p>
</body>
</html>
TEST

lxc file push /home/vagrant/index.html web2backup/var/www/html/index.html

lxc exec web2backup -- systemctl restart apache2

lxc config device add web2backup http proxy listen=tcp:0.0.0.0:20080 connect=tcp:127.0.0.1:80

sudo cp /var/snap/lxd/common/lxd/server.crt /vagrant/server.crt
#cd vagrant/
sed 's/^/   /g' /vagrant/server.crt > /vagrant/servidor.crt
echo "Certificado creado"




