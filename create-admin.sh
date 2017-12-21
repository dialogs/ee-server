#!/bin/bash
admin_user="$1"

if [[ -z $1 ]]; then
  echo "Put nickname"
  exit 1
fi

id=`docker-compose exec postgresql su - postgres -c "echo \"select id,name from users where name='$admin_user'\" | psql -d dialog" | grep $admin_user | awk '{print $1}'` 2> /dev/null
echo $id
if [[ -z "$id" ]]; then
  docker-compose exec dialog-server /opt/docker/bin/cli create-user -u $admin_user -n $admin_user
  id=`docker-compose exec postgresql su - postgres -c "echo \"select id,name from users where name='$admin_user'\" | psql -d dialog" | grep $admin_user | awk '{print $1}'`
  docker-compose exec dialog-server /opt/docker/bin/cli admin-grant -u $id | grep "Admin granted. Password: " | tee admin.txt
else
  while true; do
    read -t 10 -p "User $1 was created. Do generate admin password? (y/n): " yn
    case $yn in
      [Yy]* ) docker-compose exec dialog-server /opt/docker/bin/cli admin-grant -u $id | grep "Admin granted. Password: " | tee admin.txt; break;;
      [Nn]* ) exit;;
    esac
    exit
  done
fi
