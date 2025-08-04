#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

LOG_FILE="installer.log"

# -------------------[ Color Definitions ]-------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# -------------------[ Spinner Function ]--------------------
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ -d /proc/$pid ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "      \b\b\b\b\b\b"
}

# -------------------[ Run Command with Spinner ]------------
run_command() {
    local cmd="$1"
    local msg="$2"
    printf "${WHITE}%-50s${NC}" "$msg..."
    bash -c "$cmd" >> "$LOG_FILE" 2>&1 &
    spinner $!
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Done${NC}"
    else
        echo -e "${RED}Failed${NC}"
        exit 1
    fi
}

# -------------------[ Banner Function ]---------------------
print_banner() {
    echo -e "${BLUE}${BOLD}"
    echo "          _____  __  __          _____  _____ "
    echo "    /\   |  __ \|  \/  |   /\   / ____|/ ____|"
    echo "   /  \  | |__) | \  / |  /  \ | |    | (___  " 
    echo "  / /\ \ |  _  /| |\/| | / /\ \| |     \___ \ "
    echo " / ____ \| | \ \| |  | |/ ____ \ |____ ____) |"
    echo "/_/    \_\_|  \_\_|  |_/_/    \_\_____|_____/ "
    echo ""
    echo " --- GenieACS Installer for Armbian 24.04 ---"
    echo -e "${NC}"
}

# -------------------[ Prerequisite Checks ]---------------------
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
fi

if [ "$(lsb_release -cs)" != "noble" ]; then
    echo -e "${RED}This script only supports Armbian 24.04 (Noble)${NC}"
    exit 1
fi

ARCH=$(dpkg --print-architecture)
if [[ "$ARCH" != "arm64" ]]; then
    echo -e "${RED}Unsupported architecture: $ARCH${NC}"
    exit 1
fi

# -------------------[ Begin Installation ]---------------------
print_banner

echo -e "\n${MAGENTA}${BOLD}Starting GenieACS Installation Process${NC}\n"

# libssl
run_command "wget -q http://ports.ubuntu.com/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_arm64.deb && dpkg -i libssl1.1_1.1.1f-1ubuntu2_arm64.deb" "Installing libssl1.1 arm64"

# MongoDB
run_command "wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -" "Adding MongoDB key"
run_command "echo 'deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse' > /etc/apt/sources.list.d/mongodb-org-4.4.list" "Adding MongoDB repo"
run_command "apt-get update -y" "Updating apt sources"
run_command "apt-get install -y mongodb-org=4.4.8 mongodb-org-server=4.4.8 mongodb-org-shell=4.4.8 mongodb-org-mongos=4.4.8 mongodb-org-tools=4.4.8" "Installing MongoDB"

# NodeJS & NPM
run_command "apt-get install -y nodejs npm" "Installing NodeJS & NPM"

# GenieACS
run_command "npm install -g genieacs@1.2.13" "Installing GenieACS"

# User & folders
run_command "useradd --system --no-create-home --user-group genieacs" "Adding genieacs user"
run_command "mkdir -p /opt/genieacs/ext" "Creating /opt/genieacs/ext"
run_command "chown -R genieacs:genieacs /opt/genieacs" "Setting permissions"
run_command "mkdir -p /var/log/genieacs" "Creating log folder"

# ENV file
if [[ ! -f genieacs.env.template ]]; then
    echo -e "${RED}Missing genieacs.env.template file${NC}"
    exit 1
fi

cp genieacs.env.template /opt/genieacs/genieacs.env
echo "GENIEACS_UI_JWT_SECRET=$(node -e \"console.log(require('crypto').randomBytes(128).toString('hex'))\")" >> /opt/genieacs/genieacs.env
chown genieacs:genieacs /opt/genieacs/genieacs.env
chmod 600 /opt/genieacs/genieacs.env

# Systemd services
for svc in cwmp nbi fs ui; do
    svc_file="systemd/genieacs-$svc.service"
    if [[ ! -f "$svc_file" ]]; then
        echo -e "${RED}Missing $svc_file${NC}"
        exit 1
    fi
    cp "$svc_file" /etc/systemd/system/
done

# Logrotate config
if [[ ! -f logrotate/genieacs ]]; then
    echo -e "${RED}Missing logrotate/genieacs config${NC}"
    exit 1
fi
cp logrotate/genieacs /etc/logrotate.d/genieacs

# Enable & start services
run_command "systemctl enable mongod && systemctl start mongod" "Starting MongoDB"
for svc in cwmp nbi fs ui; do
    run_command "systemctl enable genieacs-$svc && systemctl start genieacs-$svc" "Starting GenieACS ${svc^^}"
done

# -------------------[ Final Service Check ]---------------------
echo -e "\n${MAGENTA}${BOLD}Service Status Check:${NC}"
for svc in mongod genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui; do
    if systemctl is-active --quiet "$svc"; then
        echo -e "${GREEN}✔ $svc is running${NC}"
    else
        echo -e "${RED}✘ $svc is not running${NC}"
    fi
done

echo -e "\n${GREEN}Installation complete. Access GenieACS UI on port 3000.${NC}"
