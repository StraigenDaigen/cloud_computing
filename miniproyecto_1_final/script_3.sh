#!/usr/bin/env bash

apt update && apt upgrade
apt-get install  apache2 -y

echo "instalando lxd"
sudo snap install lxd
sudo gpasswd -a vagrant lxd
echo "lxd instalado"

certification=$(</vagrant/servidor.crt)
echo "$certification"




cat <<TEST> /home/vagrant/clusterconf.yaml

config: {}
networks: []
storage_pools: []
profiles: []
cluster:
  server_name: web2UbuntuV2
  enabled: true
  member_config:
  - entity: storage-pool
    name: local
    key: source
    value: ""
    description: '"source" property for storage pool "local"'
  cluster_address: 192.168.100.8:8443
  cluster_certificate:  |
$certification
  server_address: 192.168.100.9:8443
  cluster_password: miniproyecto1


TEST

cat /home/vagrant/clusterconf.yaml

sleep 10

echo "agregando certificado al preseed"

cat /home/vagrant/clusterconf.yaml | lxd init --preseed

echo "el nodo 2 ha sido ha sido agregado al Cluster 1 sin errores"



echo "Creando Contenedor web2"
lxc launch ubuntu:18.04 web2 --target web2UbuntuV2
echo "Contenedor web2 creado"
sleep 10

lxc exec web2 -- apt update && apt upgrade
lxc exec web2 -- apt-get install apache2 -y 
lxc exec web2 -- systemctl restart apache2


echo "Configurando index.html"

touch /home/vagrant/index.html
cat <<TEST> /home/vagrant/index.html
<!DOCTYPE html>
<html>
<body>
<h1>WEB 2</h1>
<p>Bienvenido al Web 2 del Miniproyecto 1 de Computacion en la Nube</p>
</body>
</html>
TEST

lxc file push /home/vagrant/index.html web2/var/www/html/index.html

lxc exec web2 -- systemctl restart apache2

lxc config device add web2 http proxy listen=tcp:0.0.0.0:12080 connect=tcp:127.0.0.1:80





echo "Creando Contenedor web1backup"
lxc launch ubuntu:18.04 web1backup --target web2UbuntuV2
echo "Contenedor web1backup creado"
sleep 10

lxc exec web1backup -- apt update && apt upgrade
lxc exec web1backup -- apt-get install apache2 -y 
lxc exec web1backup -- systemctl restart apache2


echo "Configurar index.html"

touch /home/vagrant/index.html
cat <<TEST> /home/vagrant/index.html
<html>
<body>
<h1>Backup WEB 1</h1>
<p>Bienvenido al contenedor de backup de Web 1 del Miniproyecto 1 de Computacion en la Nube</p>
</body>
</html>
TEST

lxc file push /home/vagrant/index.html web1backup/var/www/html/index.html

lxc exec web1backup -- systemctl restart apache2

lxc config device add web1backup http proxy listen=tcp:0.0.0.0:21080 connect=tcp:127.0.0.1:80


