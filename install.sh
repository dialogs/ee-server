#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root!" 1>&2
   exit 1
fi
# Debian tested, TODO:CentOS. >>
iface_check=`ip link show | awk ' /2: / {print $2}'`
iface=${iface_check::-1}	
echo -e "\nThis script now will help you to configure machine and start Dialog Enterprise Server \c "
echo -e "\nPlease answer some questions: \c "
echo -e "\n "
read -p "Do you use DHCP on this virtual machine? (press Enter to YES (Y/N): " choice
case "$choice" in
  y|Y|'' ) echo -e " "
	echo -e "\nNetwork set to DHCP"
        is_dhcp='true';;
  n|N ) is_dhcp='false'
	echo -e " "
        echo -e "\nNetwork set to static, please enter the IP address (like 123.123.123.123): \c "
        read st_ip
        if [[ $st_ip =~ ^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?)$ ]]; then
          echo -e "\nIP of virtual machine: $st_ip"
        else echo -e "\n$st_ip is not valid IP address!"; exit 1
        fi
	echo -e " "
        echo -e "\nPlease enter the netmask (like 255.255.255.0): \c "
        read st_msk
	if [[ $st_msk =~ ^(((255\.){3}(255|254|252|248|240|224|192|128|0+))|((255\.){2}(255|254|252|248|240|224|192|128|0+)\.0)|((255\.)(255|254|252|248|240|224|192|128|0+)(\.0+){2})|((255|254|252|248|240|224|192|128|0+)(\.0+){3}))$ ]]; then
          echo -e "\nNetmask of virtual network: $st_msk"
        else echo -e "\n$st_msk is not valid network mask!"; exit 1
        fi
	echo -e " "
        echo -e "\nPlease enter the gateway ip (like 123.123.123.123): \c "
        read st_gw
        if [[ $st_gw =~ ^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?)$ ]]; then
          echo -e "\nGateway of virtual network: $st_gw"
        else echo -e "\n$st_gw is not valid IP address!"; exit 1
        fi
	echo -e " "
        echo -e "\nPlease enter the first DNS ip (like 123.123.123.123): \c "
        read st_dns1
        if [[ $st_dns1 =~ ^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?)$ ]]; then
          echo -e "\nDNS1 of virtual network: $st_dns1"
        else echo -e "\n$st_dns1 is not valid IP address!"; exit 1
        fi
	echo -e " "
        echo -e "\nPlease enter the second DNS ip (like 123.123.123.123): \c "
        read st_dns2
        if [[ $st_dns2 =~ ^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?)$ ]]; then
          echo -e "\nDNS2 of virtual network: $st_dns2"
        else echo -e "\n$st_dns2 is not valid IP address!"; exit 1
        fi;;
  * ) echo -e " "
      echo -e "\nPlease answer Y/y or N/n";;
esac


if [[ $is_dhcp = 'true' ]]; then
echo "# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto $iface
allow-hotplug $iface
iface $iface inet dhcp

" > /etc/network/interfaces
else
echo "# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto $iface
allow-hotplug $iface
iface $iface inet static
address $st_ip
netmask $st_msk
gateway $st_gw
" > /etc/network/interfaces
echo "nameserver $st_dns1
nameserver $st_dns2
nameserver 8.8.8.8
" > /etc/resolv.conf
echo -e " "
echo -e "\nRestarting network, please wait... \c "
echo -e " "
ip addr flush dev $iface
systemctl restart networking.service
sleep 3
st_set=`ip addr list $iface | grep "  inet " | head -n 1 | cut -d " " -f 6 | cut -d / -f 1`
if [[ "$st_ip" = "$st_set" ]]; then
	echo -e "\nNetwork interface is successfully configure to IP $st_set \c ";
        echo -e " "
        else echo -e "\nBad network configuration, exit \c ";
	echo -e " "
	exit 1
fi
#  >> Debian tested, TODO:CentOS.
fi
ip=`ip addr list $iface | grep "  inet " | head -n 1 | cut -d " " -f 6 | cut -d / -f 1`
echo -e "\nPlease enter your server external ip or domain name (press Enter if it correct) ($ip): \c "
read  ip_srv
if [ "$ip_srv" = "" ]; then ip_srv=$ip
fi
if [[ $ip_srv =~ ^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?)$ ]]; then
  echo -e "\nIP of server: $ip_srv"
  tlsline='use_tls: false'
  leline='use_letsencrypt: false'
 else
   if [[ $ip_srv =~ ^(([a-zA-Z](-?[a-zA-Z0-9])*)\.)*[a-zA-Z](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}$ ]]; then
     echo -e "\nDomain of server: $ip_srv"
       if ping -c1 'letsencrypt.org' 1>/dev/null 2>/dev/null
         then
           tlsline='use_tls: true'
           leline='use_letsencrypt: true'
           echo -e "\nPlease enter your email for LetsEncrypt notifications: \c "
           read email
             if [[ $email =~ ^(/.+@.+\..+/i)$ ]]; then
             echo -e "\n$email is not valid address ¯\_(ツ)_/¯"; exit
             fi
         else
           echo -e "\nNo connection to LetsEncrypt, SSL is disabled"
           tlsline='use_tls: false'
           leline='use_letsencrypt: false'
       fi
   else echo -e "\n$ip_srv is not valid IP or domain ¯\_(ツ)_/¯"; exit
   fi
fi
key=`cat license.txt`
echo -e "\nServer license (if you just press enter the license key will be read from the file license.txt) : \c "
read lic_srv
if [ "$lic_srv" = "" ]; then lic_srv="$key"
fi
echo -e "# Main
project_name: \"Dialog EE Test\"
base_url: \"$ip_srv\"
server_license: \"$lic_srv\"

# SMTP
smtp_host: \"\"
smtp_port: \"\"
smtp_from: \"\"
smtp_user: \"\"
smtp_password: \"\"
smtp_tls: # true/false

# AD
ad_host: \"\"
ad_port: \"\"
ad_domain: \"\"
ad_user: \"\"
ad_password: \"\"
ad_sync: \"10s\"

# S3
aws_endpoint: \"\"
aws_bucket: \"\"
aws_access: \"\"
aws_secret: \"\"
aws_path: \"false\"
aws_region: \"\"

dlg_custom_conf: |
#  modules.admin.new-password-message.subject = \"Your password at \$\$project\$\$\"
#  modules.admin.new-password-message.template = \"Your new password is \$\$password\$\$, login: \$\$shortname\$\$\"

### port binds ###
# localhost bindings
# localhost:[9090, 9080, 9070] reserverd for dlg-server
web_app_port:   8080
invites_port:   8081
dashboard_port: 8082

# wide binds
ws_port: 8443
tcp_port: 7443

### SSL  ###
# STRONG RECOMENTED use it
$tlsline

$leline
letsencrypt_email: $email

" > vars.yml

 set -e

function program_is_installed {
  # set to 1 initially
  local return_=1
  # set to 0 if not found
  type $1 >/dev/null 2>&1 || { local return_=0; }
  # return value
  echo "$return_"
}

function echo_fail {
  # echo first argument in red
  printf "✘ ${1}"
}

# display a message in green with a tick by it
# example
# echo echo_fail "Yes"
function echo_pass {
  # echo first argument in green
  printf "✔ ${1}"
}

# echo pass or fail
# example
# echo echo_if 1 "Passed"
# echo echo_if 0 "Failed"
function echo_if {
  if [ $1 == 1 ]; then
    echo_pass $2
  else
    echo_fail $2
  fi
}


echo -e "\nCheck installed software"
echo "ansible         $(echo_if $(program_is_installed ansible))"
echo "docker          $(echo_if $(program_is_installed docker))"
echo "docker-compose  $(echo_if $(program_is_installed docker-compose))"
echo "nginx           $(echo_if $(program_is_installed nginx))"
echo "haproxy         $(echo_if $(program_is_installed haproxy))"

if [ $(program_is_installed ansible) == 0 ]; then
  echo -e "\nInstall ansible"
  /bin/bash deps/ansible-install.sh
fi

if [ $(program_is_installed docker) == 0 ]; then
  echo -e "\nInstall docker"
  ansible-playbook -i deps/ansible/vars.ini deps/ansible/bootstrap.yml --tags "docker"
fi

if [ $(program_is_installed docker-compose) == 0 ]; then
  echo -e "\nInstall docker-compose"
  ansible-playbook -i deps/ansible/vars.ini deps/ansible/bootstrap.yml --tags "docker-compose"
fi

if [ $(program_is_installed nginx) == 0 ]; then
  echo -e "\nInstall NGINX"
  ansible-playbook -i deps/ansible/vars.ini deps/ansible/bootstrap.yml --extra-vars="@vars.yml" --tags "nginx"
fi

if [ $(program_is_installed haproxy) == 0 ]; then
  echo -e "\nInstall and configure haproxy"
  ansible-playbook -i deps/ansible/vars.ini deps/ansible/bootstrap.yml --extra-vars="@vars.yml" --tags "haproxy"
fi

if [[ $tlsline =~ 'use_tls: true' ]]; then
  s='s'
  t='tls'
  echo -e "\nInstall LetsEncrypt"
  ansible-playbook -i deps/ansible/vars.ini deps/ansible/bootstrap.yml --extra-vars="@vars.yml" --tags "letsencrypt"
else 
  s=''
  t='tcp'
fi

echo -e "\nConfigure frontends"
ansible-playbook -i deps/ansible/vars.ini deps/ansible/bootstrap.yml --extra-vars="@vars.yml" --tags "ha_reconf"
ansible-playbook -i deps/ansible/vars.ini deps/ansible/bootstrap.yml --extra-vars="@vars.yml" --tags "nginx_reconf"

echo -e "\nCreate docker-compose.yml"
ansible-playbook -i deps/ansible/vars.ini deps/ansible/bootstrap.yml --extra-vars="@vars.yml" --tags "dlg-compose"

echo -e "\nCreate Dialog configurations"
ansible-playbook -i deps/ansible/vars.ini deps/ansible/bootstrap.yml --extra-vars="@vars.yml" --extra-vars "dlg_restart=false" --tags "dlg-config"

echo -e "\nRun services"
service docker start
docker-compose up -d

echo -e "\nWait start Dialog Server..."
server_ready=1
while [ $server_ready = 1 ]; do
  sleep 3
  server_ready=`curl -sI http://localhost:9090/v1/status  | grep -q -E "HTTP/1.1 200" && [[ $? == 0 ]] && echo 0 || echo 1`
done
echo -e "\nServer is ready."

echo -e "\nCreate admin user..."
./create-admin.sh admin

echo -e "\n ********** All done! ********** "
pass="`cat admin.txt | cut -c 27- | sed 's/\`$//'`"
echo -e "
  invites:
    image: quay.io/dlgim/ee-invite:latest
    environment:
      - ENDPOINT=http://dialog-server:9090
      - ENDPOINT_AUTH=admin:${pass::-2}
      - WEBLINK=http$s://$ip_srv
    ports:
      - 127.0.0.1:8081:8080
    links:
      - dialog-server
" >> /home/dialog/ee-server/docker-compose.yml
docker-compose up -d 2> /dev/null
echo -e "\n
-------------------------------------------------------------------
    Server endpoints for clients:

                Web and Desktop clients:
                  ws$s://$ip_srv:8443

                Mobile clients:
                  $t://$ip_srv:7443

    All clients are available on site:

                https://dlg.im/en/download/enterprise

    Web services:

                Web-client:
                  http$s://$ip_srv/

                Admin dashboard:
                  http$s://$ip_srv/dash/
                  login: admin
                  password: $pass
-------------------------------------------------------------------
	       
" > info-$ip_srv.txt
echo -e "$(<info-$ip_srv.txt )"
echo -e "\n This information was saved in file echo -e $DIRSTACK/info-$ip_srv.txt"
exit 1


