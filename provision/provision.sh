#!/bin/bash

# Tratamento de erros global
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variáveis
KEYS=("ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDbC7fGQkGTjXERSAwLq7co5QXvahoXdG93m/Zx/+W1v+eme1ZohTCyi41MkcAJDr2KHSibwo6PE7WWjgYFAsZg/PNE6igI0D5VzC63T48tsK6ffxGFYy3rl0B/VyvHdfqe/vcw44zn6HRjF2q01DXV2NeSBZuJL+diclAcB+2jhrjha9iHWxxkJuxwFl76bAfhVdtNE6yC0It+aUtJLPT1ppcviGKpIyN1w6pGvWxk1pV+Pf6CdqU1FK05FeSPK+f34bSgIOin/DCNN6oBFgX2V5H/+Gf290bmlT9YGVSNZ0Y/HCK3Cetl3A+1j4YtbyANA3ju5mWeKeG8svzfphVRuOlKtwL+pVSrcnJuLIJqf4Nsq3PBAaPt9xzHk5vkmVfaMftQU0OXrgYhP2455SuuhpJe4LG3uyncRAXCK1AX7OoDI5jY6C4pZM00Vv+FOu5BYZLn28vr73B/rHBMzjnOCiouLbrYiCSL9VGtLcPTx4haoTWbm7fZSakyUhITI6M= alissonoliveira@ALISSON" "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQD3FP9QVQjtyisZgoI3mVqjVrj2foF4qx+m8Z6/elOLW4sCfd1yZQf2aoYMXh6cZrTaCf4rzjKi30W+G7OETDOvPJq12K5/Sim8uQEGhrkxLpZtINEn2HGpHEmv30Fl0GhHm00ATLz0xu5JJcC0T7kRrTDLVUitM9oEcfGLL5ttZlvyqxg7n7nlS1/igXMAjleOWOiIddAa8KzMYpxjnLhA6Ytdl2fuHVhi3IkUVlY/1l773Coka7+kAevqyjrLm79bveIEAKQCguNzuhQQJkFFn30J7h4EazojY0CyHksMPK3h3y3bWPNWm9oi+DHaL1Bg6Oo6qwf/UTlYGIG3H1cjdxSFbOoFkHsc/mHFOEtoo2zvW0smJ18gWZYxbT2/7rVXenrZbPBxjFM7OlJHaErmFbRXTWKsqliQ+nzuSOS3UzANFN8YAsRxKHg0KRxIhV0EVfIciaMU60BgOZAPzplaFxCtvWnlUlhM5dIXk7MuYNgGI6L1w8tS6clvODuuQJiV06xhPMBbfAGtFumSt1/Cw3I9k6To1jl/VGCCFCkOJLxngGXQG4JtX/y3AEMRH0uDvQJcl9xteyvHv5Uieca9rPJ6FH3bQpW8m20k7vSN39+SDYLKZ6otAAkaRqRWwpMX/3lIvvMYp79MDbThtrr+JsxKJyvD1w36KQ8d7q9oew== root@ubuntu2204.localdomain")
USERS=("devops" "ansible" "rundeck")
HOST="rundeck"
PACKAGES="openjdk-11-jre-headless curl jq wget mysql-server-8.0"

# Funções de log
log_info() { echo -e "${GREEN}[✔] INFO: $1${NC}"; }
log_warn() { echo -e "${YELLOW}[⚠] WARNING: $1${NC}"; }
log_error() { echo -e "${RED}[✖] ERROR: $1${NC}"; }

main() {
    # Verificação de root
    if [ "$EUID" -ne 0 ]; then 
        log_error "Este script precisa ser executado como root"
        exit 1
    fi

    check_connectivity
    backup_configs
    update_fstab
    install_packages
    setup_users
    configure_sudoers
    configure_ssh
    clone_ssh
    configure_hostname
    install_rundeck
    config_rundeck
    install_config_zabbix-agent
}

check_connectivity() {
    log_info "🌐 Verificando conectividade de rede..."
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_error "Sem conexão com a internet"
        exit 1
    fi
}

backup_configs() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    log_info "📦 Criando backup das configurações..."
    for file in /etc/sudoers.d/* /etc/hostname; do
        [ -f "$file" ] && cp "$file" "${file}.bak_${timestamp}"
    done
}

update_fstab() {
    if grep -q -i "swap" /etc/fstab; then
        log_info "Desabilitando a swap no fstab"
        sed -i 's/^\([^#]*\bswap\b\)/#\1/g' /etc/fstab
        swapoff -a
    else
        log_info "Swap já está desabilitada no fstab"
    fi
}

install_packages() {
    log_info "📦 Instalando pacotes dependências do Rundeck..."
    apt-get update -y
    apt-get install -y ${PACKAGES}
}

setup_users() {
    for user in "${USERS[@]}"; do
        if ! id -u "$user" >/dev/null 2>&1; then
            log_info "👤 Criando usuário $user..."
            useradd -m -d /home/$user -s /bin/bash "$user" || { log_error "Falha ao criar usuário $user"; exit 1; }
        else
            log_warn "👤 Usuário $user já existe"
        fi
    done
}

configure_sudoers() {
    for user in "${USERS[@]}"; do
        if [ ! -f "/etc/sudoers.d/$user" ]; then
            log_info "🔑 Configurando sudo para $user..."
            echo "$user ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$user"
            chmod 440 "/etc/sudoers.d/$user"
            
            if ! visudo -c -f "/etc/sudoers.d/$user"; then
                log_error "Arquivo sudoers inválido para $user"
                rm -f "/etc/sudoers.d/$user"
                exit 1
            fi
        else
            log_warn "📝 Configuração sudo para $user já existe"
        fi
    done
}

configure_ssh() {
    log_info "🔑 Configurando chaves SSH..."
    for key in "${KEYS[@]}"; do
        if ! grep -q "$key" /home/vagrant/.ssh/authorized_keys 2>/dev/null; then
            echo "$key" >> /home/vagrant/.ssh/authorized_keys
        fi
    done
}

clone_ssh() {
    for user in "${USERS[@]}"; do
        local ssh_dir="/home/$user/.ssh"
        log_info "🔄 Configurando SSH para $user..."
        
        if [ ! -d "$ssh_dir" ]; then
            install -d -m 700 -o "$user" -g "$user" "$ssh_dir"
            cp /home/vagrant/.ssh/authorized_keys "$ssh_dir/"
            chown "$user":"$user" "$ssh_dir/authorized_keys"
            chmod 600 "$ssh_dir/authorized_keys"
        else
            log_warn "📝 Diretório SSH para $user já existe"
        fi
    done
}

configure_hostname() {
    log_info "🖥️ Configurando hostname..."
    hostnamectl set-hostname "$HOST" || { log_error "Falha ao configurar hostname"; exit 1; }
}

install_rundeck() {
    log_info "🚀 Instalando Rundeck..."
    if [ ! -f /etc/apt/trusted.gpg.d/rundeck-key.asc ]; then
        curl -fsSL https://packages.rundeck.com/pagerduty/rundeck/gpgkey | tee /etc/apt/trusted.gpg.d/rundeck-key.asc
        chmod 644 /etc/apt/trusted.gpg.d/rundeck-key.asc
    fi

    if [ ! -f /etc/apt/sources.list.d/rundeck.list ]; then
        echo "deb https://packages.rundeck.com/pagerduty/rundeck/any/ any main" | tee /etc/apt/sources.list.d/rundeck.list
        echo "deb-src https://packages.rundeck.com/pagerduty/rundeck/any/ any main" | tee -a /etc/apt/sources.list.d/rundeck.list
    fi

    apt-get update -y
    apt-get install -y rundeck
    systemctl daemon-reload
    sudo systemctl enable rundeckd
    systemctl start rundeckd
    sudo systemctl enable mysql
    systemctl start mysql
}

config_rundeck() {
    cat <<EOF >> /etc/rundeck/rundeck-config.properties
dataSource.url = jdbc:mysql://127.0.0.1/rundeck?autoReconnect=true&useSSL=false&allowPublicKeyRetrieval=true
dataSource.username = rundeck
dataSource.password = devops
dataSource.driverClassName = org.mariadb.jdbc.Driver
EOF

    mysql -e "CREATE DATABASE IF NOT EXISTS rundeck;"
    mysql -e "CREATE USER IF NOT EXISTS 'rundeck'@'%' IDENTIFIED BY 'devops';"
    mysql -e "GRANT ALL ON rundeck.* TO 'rundeck'@'%';"
    mysql -e "FLUSH PRIVILEGES;"

    sed -i "s|grails.serverURL=http://.*:4440|grails.serverURL=http://$(ip addr show | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | tail -n 1):4440|" /etc/rundeck/rundeck-config.properties

    sudo sed -i "s|framework.server.name=.*|framework.server.name=$(hostname)|" /etc/rundeck/framework.properties
    sudo sed -i "s|framework.server.hostname=.*|framework.server.hostname=$(hostname)|" /etc/rundeck/framework.properties
    sudo sed -i "s|framework.server.url=.*|framework.server.url=http://$(ip addr show | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | tail -n 1):4440|" /etc/rundeck/framework.properties
    
    systemctl enable mysql
    systemctl restart mysql

    echo 'RDECK_JVM_SETTINGS="$RDECK_JVM_SETTINGS -Xmx2048m -Xms1024m"' | sudo tee /etc/default/rundeckd

    systemctl enable rundeckd
    systemctl daemon-reload
    systemctl restart rundeckd
}

install_config_zabbix-agent(){
    # Endereço do Servidor Zabbix
    # Server=IP_SERVIDOR_ZABBIX

    # # Hostname da maquina que está instalado o zabbix-agent (deve ser idêntico ao configurado no Frontend)
    # Hostname=NOME_DO_HOST

    # # Porta de escuta
    # ListenPort=10050

    # # Configurações adicionais
    # StartAgents=3
    log_info "🚀 Instalando Zabbix Agent..."

    #!/bin/bash

    # Instalando o Zabbix Agent
    sudo apt install -y zabbix-agent

    # Verificando e alterando a configuração do Server
    if grep -q "^Server=" /etc/zabbix/zabbix_agentd.conf; then
        sudo sed -i 's/^Server=.*/Server=192.168.15.19/' /etc/zabbix/zabbix_agentd.conf
    else
        echo "Server=192.168.15.19" | sudo tee -a /etc/zabbix/zabbix_agentd.conf
    fi

    # Verificando e alterando a configuração do ServerActive
    if grep -q "^ServerActive=" /etc/zabbix/zabbix_agentd.conf; then
        sudo sed -i 's/^ServerActive=.*/ServerActive=192.168.15.19/' /etc/zabbix/zabbix_agentd.conf
    else
        echo "ServerActive=192.168.15.19" | sudo tee -a /etc/zabbix/zabbix_agentd.conf
    fi

    # Verificando e alterando a configuração do Hostname
    if grep -q "^Hostname=" /etc/zabbix/zabbix_agentd.conf; then
        sudo sed -i "s/^Hostname=.*/Hostname=$(hostname)/" /etc/zabbix/zabbix_agentd.conf
    else
        echo "Hostname=$(hostname)" | sudo tee -a /etc/zabbix/zabbix_agentd.conf
    fi

    # Verificando e alterando a configuração do ListenPort
    if grep -q "^ListenPort=" /etc/zabbix/zabbix_agentd.conf; then
        sudo sed -i "s/^ListenPort=.*/ListenPort=10050/" /etc/zabbix/zabbix_agentd.conf
    else
        echo "ListenPort=10050" | sudo tee -a /etc/zabbix/zabbix_agentd.conf
    fi

    # Verificando e alterando a configuração do StartAgents
    if grep -q "^StartAgents=" /etc/zabbix/zabbix_agentd.conf; then
        sudo sed -i "s/^StartAgents=.*/StartAgents=3/" /etc/zabbix/zabbix_agentd.conf
    else
        echo "StartAgents=3" | sudo tee -a /etc/zabbix/zabbix_agentd.conf
    fi

    # Verificando e alterando a configuração do PidFile
    if grep -q "^PidFile=" /etc/zabbix/zabbix_agentd.conf; then
        sudo sed -i "s/^PidFile=.*/PidFile=\/run\/zabbix\/zabbix_agentd.pid/" /etc/zabbix/zabbix_agentd.conf
    else
        echo "PidFile=/run/zabbix/zabbix_agentd.pid" | sudo tee -a /etc/zabbix/zabbix_agentd.conf
    fi

    # Verificando e alterando a configuração do LogFile
    if grep -q "^LogFile=" /etc/zabbix/zabbix_agentd.conf; then
        sudo sed -i "s/^LogFile=.*/LogFile=\/var\/log\/zabbix-agent\/zabbix_agentd.log/" /etc/zabbix/zabbix_agentd.conf
    else
        echo "LogFile=/var/log/zabbix-agent/zabbix_agentd.log" | sudo tee -a /etc/zabbix/zabbix_agentd.conf
    fi

    # Verificando e alterando a configuração do LogFileSize
    if grep -q "^LogFileSize=" /etc/zabbix/zabbix_agentd.conf; then
        sudo sed -i "s/^LogFileSize=.*/LogFileSize=0/" /etc/zabbix/zabbix_agentd.conf
    else
        echo "LogFileSize=0" | sudo tee -a /etc/zabbix/zabbix_agentd.conf
    fi

    # Verificando e alterando a configuração do Include
    if grep -q "^Include=" /etc/zabbix/zabbix_agentd.conf; then
        sudo sed -i "s/^Include=.*/Include=\/etc\/zabbix\/zabbix_agentd.conf.d\/\*.conf/" /etc/zabbix/zabbix_agentd.conf
    else
        echo "Include=/etc/zabbix/zabbix_agentd.conf.d/*.conf" | sudo tee -a /etc/zabbix/zabbix_agentd.conf
    fi

    # Habilitando e reiniciando o serviço
    sudo systemctl enable zabbix-agent
    sudo systemctl restart zabbix-agent


}

# Executa o script
main