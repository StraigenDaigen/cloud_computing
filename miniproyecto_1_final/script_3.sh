#!/usr/bin/env bash


#Actualiza SO 
apt update && apt upgrade
#Instala apache
apt-get install  apache2 -y

echo "instalando lxd"
#Instala lxd 
sudo snap install lxd
#Agrega vagrant a al grupo lxd
sudo gpasswd -a vagrant lxd
echo "lxd instalado"

#Agrega el contennido del archivo servidor.crt a una variable que contendra la certficacion generada por el cluster. 
certification=$(</vagrant/servidor.crt)
echo "$certification"



#Se crea un archivo yaml y se agrega el contenido, en este caso nos uniremos a un cluster que ya ha sido creado previamente. 
#Le damos un nombre al nodo, lo habilitamos, se le asignan los parametros de almacenamiento, despues de esto, se debe agregar el certificado que se genero en la creacion
#del cluster, el cual se encuentra en la variable creada (asegurarse de cumplir con la indentacion), luego se agrega la direccion del cluster, que se añadio previamente
#en el archivo de aprovisionamiento anterior y la contraseña.
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

#Verificamos el contenido del archivo creado
cat /home/vagrant/clusterconf.yaml

sleep 10

echo "agregando certificado al preseed"

#Se agrega el archivo en el preseed de lxd 

cat /home/vagrant/clusterconf.yaml | lxd init --preseed

echo "el nodo 2 ha sido ha sido agregado al Cluster 1 sin errores"



echo "Creando Contenedor web2"
#Se crea el contenedor web2
lxc launch ubuntu:18.04 web2 --target web2UbuntuV2
echo "Contenedor web2 creado"
sleep 10

#Actualizamos el sistema, instalamos apache y lo reiniciamos en el contenedor web2
lxc exec web2 -- apt update && apt upgrade
lxc exec web2 -- apt-get install apache2 -y 
lxc exec web2 -- systemctl restart apache2


echo "Configurando index.html"

#Crear una pagina para mostrar el web2 
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

#enviar archivo al contenedor web2
lxc file push /home/vagrant/index.html web2/var/www/html/index.html

#Se reinicia apache
lxc exec web2 -- systemctl restart apache2

#Se redireccionan los puertos para poder visualizar contenido desde maquina host
lxc config device add web2 http proxy listen=tcp:0.0.0.0:12080 connect=tcp:127.0.0.1:80





echo "Creando Contenedor web1backup"
#Se crea el segundo contenedor backup y se almacena en la VM web2UbuntuV2
lxc launch ubuntu:18.04 web1backup --target web2UbuntuV2
echo "Contenedor web1backup creado"
sleep 10

#Se actualiza el contenedor, se instala apache y se reinicia apache
lxc exec web1backup -- apt update && apt upgrade
lxc exec web1backup -- apt-get install apache2 -y 
lxc exec web1backup -- systemctl restart apache2


echo "Configurar index.html"
#se crea un archivo html en el cual se pone el mensaje del contenedor backup
touch /home/vagrant/index.html
cat <<TEST> /home/vagrant/index.html
<html>
<body>
<h1>Backup WEB 1</h1>
<p>Bienvenido al contenedor de backup de Web 1 del Miniproyecto 1 de Computacion en la Nube</p>
</body>
</html>
TEST
#Se envia archivo al contenedor web1backup
lxc file push /home/vagrant/index.html web1backup/var/www/html/index.html

#Se reinicia el apache del contenedor
lxc exec web1backup -- systemctl restart apache2

#Se reenvian los puertos del contenedor para poderlos visualizar desde la maquina host
lxc config device add web1backup http proxy listen=tcp:0.0.0.0:21080 connect=tcp:127.0.0.1:80


