#!/bin/bash

USER="rundeck"
SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDbC7fGQkGTjXERSAwLq7co5QXvahoXdG93m/Zx/+W1v+eme1ZohTCyi41MkcAJDr2KHSibwo6PE7WWjgYFAsZg/PNE6igI0D5VzC63T48tsK6ffxGFYy3rl0B/VyvHdfqe/vcw44zn6HRjF2q01DXV2NeSBZuJL+diclAcB+2jhrjha9iHWxxkJuxwFl76bAfhVdtNE6yC0It+aUtJLPT1ppcviGKpIyN1w6pGvWxk1pV+Pf6CdqU1FK05FeSPK+f34bSgIOin/DCNN6oBFgX2V5H/+Gf290bmlT9YGVSNZ0Y/HCK3Cetl3A+1j4YtbyANA3ju5mWeKeG8svzfphVRuOlKtwL+pVSrcnJuLIJqf4Nsq3PBAaPt9xzHk5vkmVfaMftQU0OXrgYhP2455SuuhpJe4LG3uyncRAXCK1AX7OoDI5jY6C4pZM00Vv+FOu5BYZLn28vr73B/rHBMzjnOCiouLbrYiCSL9VGtLcPTx4haoTWbm7fZSakyUhITI6M= alissonoliveira@ALISSON"
PACKAGES="openjdk-11-jre-headless curl jq net-tools mysql-server"

#correção temporária
#sudo cp /etc/apt/trusted.gpg trusted.gpg.d/

# Desativa a swap temporariamente
#sudo swapoff -a

# Remove a entrada da swap do arquivo /etc/fstab
#sudo sed -i '/\/swap.img/d' /etc/fstab

# Comentando a configuração da swap no fstab
sudo sed -i 's/^\([^#]*\bswap\b\)/#\1/g' /etc/fstab

echo "Desabilitando a swap"
sudo swapoff -a



echo "Atualizando pacotes..."
sudo apt update -y
sudo apt install -y $PACKAGES

if ! grep -q -i "$SSH_KEY" /home/vagrant/.ssh/authorized_keys; then
    echo "Escrevendo a chave ssh no arquivo authorized_keys"
    echo "$SSH_KEY" >> /home/vagrant/.ssh/authorized_keys
else
    echo "Chave ssh já existente no arquivo authorized_keys"
fi

getent passwd | grep -i "$USER"

if [ $? -ne 0 ]; then
    echo "Usuário: $USER não encontrado criando usuário..."
    sleep 5
    sudo useradd -m -d /home/rundeck -s /bin/bash "$USER"

else
    echo "Usuário: $USER encontrado"
fi

sudo ls /etc/sudoers.d/$USER

if [ $? -ne 0 ]; then
    echo "Criando arquivo sudoers para o usuário $USER"
    sudo echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/rundeck
else
    echo "Arquivo sudoers já existente para o usuário $USER"
fi

ls /home/$USER/.ssh/authorized_keys

if [ $? -ne 0 ]; then
    echo "Copiando o diretório .ssh do usuário vagrant para o usuário: $USER"
    sudo cp -r /home/vagrant/.ssh /home/$USER/
    sudo chown -R $USER:$USER /home/$USER/.ssh
else
    echo "Diretório .ssh já existente para o usuário $USER"
fi



echo "Importando a key do repo do rundeck..."
sudo curl -s -L https://packages.rundeck.com/pagerduty/rundeck/gpgkey | sudo apt-key add -

echo "adicionando o source do rundeck..."
sudo bash -c 'echo "deb https://packages.rundeck.com/pagerduty/rundeck/any/ any main" >> /etc/apt/sources.list.d/rundeck.list'
sudo bash -c 'echo "deb-src https://packages.rundeck.com/pagerduty/rundeck/any/ any main" >> /etc/apt/sources.list.d/rundeck.list'


echo "Atualizando pacotes e instalando o rundeck..."
sudo apt update -y
sudo apt install -y rundeck

sudo cat <<EOF > /etc/rundeck/rundeck-config.properties
#loglevel.default is the default log level for jobs: ERROR,WARN,INFO,VERBOSE,DEBUG
loglevel.default=INFO
rdeck.base=/var/lib/rundeck

#rss.enabled if set to true enables RSS feeds that are public (non-authenticated)
rss.enabled=false
# change hostname here
grails.serverURL=http://localhost:4440
#dataSource.dbCreate = none
#dataSource.url = jdbc:h2:file:/var/lib/rundeck/data/rundeckdb;DB_CLOSE_ON_EXIT=FALSE;NON_KEYWORDS=MONTH,HOUR,MINUTE,YEAR,SECONDS
#grails.plugin.databasemigration.updateOnStart=true

# Encryption for key storage
rundeck.storage.provider.1.type=db
rundeck.storage.provider.1.path=keys

rundeck.storage.converter.1.type=jasypt-encryption
rundeck.storage.converter.1.path=keys
rundeck.storage.converter.1.config.encryptorType=custom
rundeck.storage.converter.1.config.password=3b0402e8af2cc75b
rundeck.storage.converter.1.config.algorithm=PBEWITHSHA256AND128BITAES-CBC-BC
rundeck.storage.converter.1.config.provider=BC

# Encryption for project config storage
rundeck.projectsStorageType=db

rundeck.config.storage.converter.1.type=jasypt-encryption
rundeck.config.storage.converter.1.path=projects
rundeck.config.storage.converter.1.config.password=3b0402e8af2cc75b
rundeck.config.storage.converter.1.config.encryptorType=custom
rundeck.config.storage.converter.1.config.algorithm=PBEWITHSHA256AND128BITAES-CBC-BC
rundeck.config.storage.converter.1.config.provider=BC

rundeck.feature.repository.enabled=true

# CONFIGS DATABASE
dataSource.driverClassName = org.mariadb.jdbc.Driver
dataSource.url = jdbc:mysql://localhost/rundeck?autoReconnect=true&useSSL=false
dataSource.username = rundeck
dataSource.password = devops
EOF

echo "Configurando o database do Rundeck"
sudo mysql -e "create database rundeck;"
sudo mysql -e "create user 'rundeck'@'%' identified by 'devops';"
sudo mysql -e "grant ALL on rundeck.* to 'rundeck'@'%';"

export IP=$(hostname -I | awk '{print $2}')

echo "Atualizando as configurações do Rundeck"
#sudo sed -i "s/localhost/$(echo $IP)/" /etc/rundeck/rundeck-config.properties
sudo sed -i "s|grails.serverURL=http://localhost:4440|grails.serverURL=http://$(echo $IP):4440|" /etc/rundeck/rundeck-config.properties

echo "Habilitando o mysql"
sudo systemctl enable mysql

echo "Reiniciando o serviço do mysql"
sudo systemctl restart mysql

sudo echo -n 'RDECK_JVM_SETTINGS="$RDECK_JVM_SETTINGS -Xmx4096m -Xms1024m"' >> /etc/default/rundeckd

echo "Habilitando o serviço do rundeck..."
sudo systemctl enable rundeckd --now

sudo systemctl daemon-reload
sudo service rundeckd restart