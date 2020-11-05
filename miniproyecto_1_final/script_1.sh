#!/usr/bin/env bash

#Se actualiza el SO
apt update && apt upgrade

#Se instala lxd
sudo snap install lxd
#Se agrega vagrant al grupo lxd
sudo gpasswd -a vagrant lxd

#Se almacena el contenido del certificado en una variable
certification=$(</vagrant/servidor.crt)
echo "$certification"

#Se crea nuevamente un archivo yaml, el cual se le suministra la informacion del cluster; nombre del nodo actual, configuracion de almacenamiento
#la direccion del cluster al que se va a unir, el certificado, que en este caso es la variable definida previamente. se agrega la direccion del nodo actual y 
#la contraseña del cluster
cat <<TEST> /home/vagrant/clusterconf.yaml

config: {}
networks: []
storage_pools: []
profiles: []
cluster:
  server_name: haproxyUbuntuV2
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
  server_address: 192.168.100.10:8443
  cluster_password: miniproyecto1


TEST

#se verifica el contenido del archivo yaml
cat /home/vagrant/clusterconf.yaml
sleep 10


echo "agregando certificado al preseed"
#Se agrega el archivo al preseed de lxd
cat /home/vagrant/clusterconf.yaml | lxd init --preseed

echo "el nodo 3 ha sido ha sido agregado al Cluster 1 sin errores"

#Se crea el contenedor haproxy y se le indica al sistema que se creara en la VM haproxyUbuntuV2
lxc launch ubuntu:18.04 haproxy --target haproxyUbuntuV2
sleep 10

# Se actualiza el SO, se instala haproxy y se habilita dentro del contenedor haproxy
lxc exec haproxy -- apt update && apt upgrade
lxc exec haproxy -- apt install haproxy -y

lxc exec haproxy -- systemctl enable haproxy






echo "Configurando Archivo de Configuración Haproxy"

#Se crea el archivo que va a tener la configuracion del balanceador de carga.
touch /home/vagrant/haproxy.cfg

#se agrega el contenido de la configuracion al archivo haproxy.cfg

#Se definen los logs, es decir la respuesta del sistema, para saber en que estado está. notice valida si ha habido un cambio en algun server y lo envia en el log
#Se Definen los grupos y usuarios, temas de seguridad con los certificados SSL
#Luego se asignan las paginas que el sistema debe ejecutar en caso de errores.
#Luego se define el modelo del balanceador de carga, el cual es usa el algoritmo roundrobin
#Adicionalmente el sistema utiliza un tipo de equilibrio de carga "http".
# Los check de los server significan que se deben hacer comprobaciones de estado de esos servidores en back-end


#
cat <<TEST> /home/vagrant/haproxy.cfg
global
	log /dev/log	local0
	log /dev/log	local1 notice
	chroot /var/lib/haproxy
	stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
	stats timeout 30s
	user haproxy
	group haproxy
	daemon

	# Default SSL material locations
	ca-base /etc/ssl/certs
	crt-base /etc/ssl/private

	# Default ciphers to use on SSL-enabled listening sockets.
	# For more information, see ciphers(1SSL). This list is from:
	#  https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
	# An alternative list with additional directives can be obtained from
	#  https://mozilla.github.io/server-side-tls/ssl-config-generator/?server=haproxy
	ssl-default-bind-ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS
	ssl-default-bind-options no-sslv3

defaults
	log	global
	mode	http
	option	httplog
	option	dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
	errorfile 400 /etc/haproxy/errors/400.http
	errorfile 403 /etc/haproxy/errors/403.http
	errorfile 408 /etc/haproxy/errors/408.http
	errorfile 500 /etc/haproxy/errors/500.http
	errorfile 502 /etc/haproxy/errors/502.http
	errorfile 503 /etc/haproxy/errors/503.http
	errorfile 504 /etc/haproxy/errors/504.http


backend web-backend
   balance roundrobin
   stats enable
   stats auth admin:admin
   stats uri /haproxy?stats

   option allbackups
   server web1 web1.lxd:80 check
   server web2 web2.lxd:80 check
   server web1backup web1backup.lxd:80 check backup
   server web2backup web2backup.lxd:80 check backup



frontend http
  bind *:80
  default_backend web-backend

TEST

sleep 5
lxc file push haproxy.cfg haproxy/etc/haproxy/haproxy.cfg


lxc exec haproxy -- systemctl start haproxy

lxc exec haproxy -- systemctl restart haproxy

lxc config device add haproxy http proxy listen=tcp:0.0.0.0:13080 connect=tcp:127.0.0.1:80



echo "Configurar index.html Para manejar Errores de fallas en los Servidores"

touch /home/vagrant/503.html
cat <<TEST> /home/vagrant/503.html
HTTP/1.0 503 Service Unavailable
Cache-Control: no-cache
Connection: close
Content-Type: text/html

<html>
<body>
<h1>Nuestra pagina tiene una falla</h1>
<p>Ofrecemos nuestras disculpas, estamos trabajando para solucionar este error</p>
</body>
</html>
TEST

sleep 5

lxc file push /home/vagrant/503.html haproxy/etc/haproxy/errors/503.http

sleep 5

lxc exec haproxy -- systemctl restart haproxy


