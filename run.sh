#!/bin/bash
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
  ansible-playbook -i deps/ansible/vars.ini deps/ansible/bootstrap.yml --extra-vars="@vars.yml" --tags "letsencrypt"
fi

if [ $(program_is_installed haproxy) == 0 ]; then
  echo -e "\nInstall and configure haproxy"
  ansible-playbook -i deps/ansible/vars.ini deps/ansible/bootstrap.yml --extra-vars="@vars.yml" --tags "haproxy"
fi

echo -e "\nConfigure frontends"
ansible-playbook -i deps/ansible/vars.ini deps/ansible/bootstrap.yml --extra-vars="@vars.yml" --tags "ha_reconf"
ansible-playbook -i deps/ansible/vars.ini deps/ansible/bootstrap.yml --extra-vars="@vars.yml" --tags "nginx_reconf"

echo -e "\nCreate docker-compose.yml"
ansible-playbook -i deps/ansible/vars.ini deps/ansible/bootstrap.yml --extra-vars="@vars.yml" --tags "dlg-compose"

server_runing=`nc -z localhost 9090 ; echo $?`

echo -e "\nCreate Dialog configurations"
if [[ $server_runing == 1 ]]; then
  ansible-playbook -i deps/ansible/vars.ini deps/ansible/bootstrap.yml --extra-vars="@vars.yml" --extra-vars "dlg_restart=false" --tags "dlg-config"
else
  ansible-playbook -i deps/ansible/vars.ini deps/ansible/bootstrap.yml --extra-vars="@vars.yml" --extra-vars --tags "dlg-config"
fi

if [[ $server_runing == 1 ]]; then
  echo -e "\nRun services"
  docker-compose up -d

  echo -e "\nWait start Dialog Server..."
  server_ready=1
  while [ $server_ready = 1 ]; do
    sleep 3
    server_ready=`curl -sI http://localhost:9090/v1/status  | grep -q -E "HTTP/1.1 200" && [[ $? == 0 ]] && echo 0 || echo 1`
  done
  echo -e "\nServer is ready."

  echo -e "\nCreate admin user..."
  /bin/bash create-admin.sh admin
fi
