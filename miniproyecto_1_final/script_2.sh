#!/usr/bin/env bash

#Actualizar sistema operativo
apt update && apt upgrade

#Instalar apache como servicio web
apt-get install  apache2 -y

echo "instalando lxd"
#Instalar lxd para poder crear contenedores linux
sudo snap install lxd
#Agregar vagrant al grupo lxd 
sudo gpasswd -a vagrant lxd
echo "lxd instalado"

#crear archivo de configuracion para clusters. 
#Inicialmente se configura dirección del nodo, se ingresa la ip y el puerto que usara
#Luego se crea la contraseña que tendrá el cluster.
#Luego se configura la red
#El primer parametro es el modo puente de la red que sera tipo "fan" ya que esto permite crear direcciones IP adicionales para la creacion de contenedores. 
# luego se define la subred bajo la cual operara el "fan" 
# se le asiga un nombre a la red, en este caso se llama lxdfan0
# luego se configura el almacenamiento, en donde se usa el controlador "dir" para compartir los datos con la maquina anfitriona. 
# Despues se configura el perfil del cluser, el cual tiene una interfaz llamada eth0 y se le adiciona el nombre de la red "lxdfan0" y el tipo de interfaz que es "nic"
# Luego se configura el root del cluster. 
# Finalmente se configura el nombre que va a tener el cluster, se habilita, luego la direccion del cluster se crea de manera automatica
# De la misma manera se genera el certificado de autenticacion del cluster
# Se configura la direccion del servidor que tendra el cluster y la contraseña del cluster. 



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


#Se crea el primer contenedor lxd el cual se llama Web1 y se alojará dentro de la VM web1UbuntuV2

echo "Creando Contenedor web1"
lxc launch ubuntu:18.04 web1 --target web1UbuntuV2
echo "Contenedor web1 creado"
sleep 10

#Se accede al contenedor web 1 y se actualiza el SO
lxc exec web1 -- apt update && apt upgrade
#Se instala apache en el contenedor web1
lxc exec web1 -- apt-get install apache2 -y 
#Se reinicia apache en el contenedor web1
lxc exec web1 -- systemctl restart apache2


echo "Configurar index.html"

#Se crea un archivo index.html para crear la pagina web 1
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

#Se envia el archivo desde la VM hasta el contenedor web1 en esa ruta. 

lxc file push /home/vagrant/index.html web1/var/www/html/index.html

# Se reinicia apache en el contenedor

lxc exec web1 -- systemctl restart apache2

# Se redireccionan los puertos del contenedor hacia la VM para poder visualizar su contenido en la maquina host. 

lxc config device add web1 http proxy listen=tcp:0.0.0.0:11080 connect=tcp:127.0.0.1:80


echo "Creando Contenedor web2backup"
#Se crea el primer contenedor de backup
lxc launch ubuntu:18.04 web2backup --target web1UbuntuV2
echo "Contenedor web2backup creado"
sleep 10

#Se actualiza el contenedor, se instala apache y se reincia apache.
lxc exec web2backup -- apt update && apt upgrade
lxc exec web2backup -- apt-get install apache2 -y 
lxc exec web2backup -- systemctl restart apache2


echo "Configurar index.html"
#Se crea nuevamente un index.html para agregar la pagina que mostrara el sistema en caso de que se active el backup
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

#Se envia el archivo creado al contenedor de backup
lxc file push /home/vagrant/index.html web2backup/var/www/html/index.html

#Se reincia apache
lxc exec web2backup -- systemctl restart apache2

#Se configura el redireccionamiento de puertos del contenedor backup hacia la VM con el puerto establecido
lxc config device add web2backup http proxy listen=tcp:0.0.0.0:20080 connect=tcp:127.0.0.1:80


#Finalmente se realiza una copia del archivo que contiene el certificado del cluster creado y se envia a la carpeta vagrant que se puede ver en la maquina host
sudo cp /var/snap/lxd/common/lxd/server.crt /vagrant/server.crt
#Se modifca la indentacion de todas las lineas hacia la derecha 4 espacios, usando sed. y el resultado se almacena en un nuevo archivo.
sed 's/^/   /g' /vagrant/server.crt > /vagrant/servidor.crt
echo "Certificado creado"




