### prepare.sh

#!/bin/bash

cd ~
mkdir -p ~/.docker
cp ~/ee-server.json ~/.docker/config.json

apt-get update
apt-get install -y git unzip
git clone https://github.com/dialogs/ee-server.git
cd ee-server

# switch to branch ubuntu if os is ubuntu
if [ $(grep -i ubuntu /etc/issue | awk '{print $1}') == "Ubuntu" ]
    then git checkout ubuntu
fi

cp vars.example.yml vars.yml

pline='project_name: "My EE"'

read -p "\
Enter Project Name\
[My EE]" \
-r pname

if [ -n "$pname" ]
    then pline="project_name: \"$pname\""

    # delete old project name
    sed -i /project_name/d vars.yml

    # write new project name
    sed -i /base_url/i"$pline" vars.yml

    else echo "no Project Name was given, living default value \"My EE\""
fi

urlline='base_url: "example.com"'

read -p "\
Enter external url or ip\
[example.com/1.2.3.4]" \
-r urlname

if [ -n "$urlname" ]
    then urlline="base_url: \"$urlname\""

    # delete old url/ip
    sed -i /base_url/d vars.yml

    # write new url/ip
    sed -i /project_name/a"$urlline" vars.yml
    else echo "no url/ip was given, living default value \"example.com\""
fi

### SSL

tlsline='use_tls: false'

leline='use_letsencrypt: false'

read -p "\
    Enable SSL ?\
    [yes/no(default)]" \
    -r tlsval

if [ "$tlsval" = "yes" ]
    then tlsline='use_tls: true'; echo "SSL set to [yes]"
    leline='use_letsencrypt: true'; echo "LetsEncrypt set to [yes]"

    # delete old tlsline
    sed -i /use_tls/d vars.yml
    # write new tlsline
    sed -i /use_letsencrypt/i"$tlsline" vars.yml

    # delete old leline
    sed -i /use_letsencrypt/d vars.yml
    # write new leline
    sed -i /use_tls/a"$leline" vars.yml

    read -p "\
    enter contact email\
    [admin@yourdomain.name]" \
    -r leemail

    if [ -n "$leemail" ]
    then
        leemailline="letsencrypt_email: $leemail"; echo "LetsEncrypt email set to [$leemail]"

        # delete old leemailline
        sed -i /letsencrypt_email/d vars.yml
        # write new leemilline
        sed -i /use_letsencrypt/a"$leemailline" vars.yml
     else echo "living default value email@example.com"
    fi

    else echo "living default value [no]"
fi

# setting up license key

lic=$(cat ~/license.txt)
sed -i -e '/server_license/s/""/'$lic'/g' vars.yml

echo "Preparations complete, executing run.sh"

bash run.sh
