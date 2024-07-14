# This script is a tool to take a fresh install of OpenSUSE tumbleweed wsl and set it up for docker deployment with one command
#
# !!! DO NOT CREATE A USER AT USER CREATION ON FRESH INSTALL OF OPENSUSE !!!
# once you do your first reboot create a .tar of the of your install with the command wsl --export openSUSE-Tumbleweed C:any-file-path/ANY-FILE-NAME.tar then when you import the .tar with the command wsl --import any-name-you-want C:\WSL\(or any other location you would like this to be saved) C:/your-file-location.tar
# this script will also autoconfigure that import with a user name and password for evan faster deployment 
# Deployment Instructions:
# 1. Create the script file:
#  sudo joe wsl_initial_setup.sh && sudo chmod +x wsl_initial_setup.sh && sudo ./wsl_initial_setup.sh
#
# 6. Restart WSL when prompted.
#   exit
#   wsl --shutdown
#   wsl
#!/bin/bash
# This script sets up a fresh install of OpenSUSE tumbleweed for docker deployment

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root. Please use sudo.${NC}"
    exit 1
fi

# Function to enable systemd
enable_systemd() {
    echo -e "${BLUE}Enabling systemd...${NC}"
    wsl_conf="/etc/wsl.conf"
    if [ ! -f "$wsl_conf" ] || ! grep -q '^\[boot\]' "$wsl_conf"; then
        echo -e "[boot]\nsystemd=true" > "$wsl_conf"
        echo -e "${GREEN}Enabled systemd in $wsl_conf${NC}"
    else
        sed -i '/^\[boot\]/,/^\[.*\]/ s/^systemd=.*/systemd=true/' "$wsl_conf"
        if ! grep -q '^\[boot\]' "$wsl_conf" || ! grep -q 'systemd=true' "$wsl_conf"; then
            sed -i '/^\[boot\]/a systemd=true' "$wsl_conf"
        fi
        echo -e "${GREEN}Updated systemd setting in $wsl_conf${NC}"
    fi
}

# Function to create the system setup script
create_system_setup_script() {
    setup_script="/etc/profile.d/system_setup.sh"
    cat > "$setup_script" << 'EOF'
#!/bin/bash

set -e

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Elevating privileges..."
    exec sudo -E bash "$0" "$@"
    exit $?
fi

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function for zypper commands with error handling
zypper_run() {
    if ! zypper --gpg-auto-import-keys --non-interactive "$@"; then
        echo -e "${RED}Zypper command failed: zypper $*${NC}"
        exit 1
    fi
}

echo -e "${BLUE}Starting system setup...${NC}"

# Update system
echo -e "${YELLOW}Updating system...${NC}"
zypper_run ref
zypper_run dup -y

# Install packages
echo -e "${YELLOW}Installing packages...${NC}"
zypper_run in -y docker docker-compose NetworkManager neofetch opi git

# Configure Docker
echo -e "${YELLOW}Configuring Docker...${NC}"
systemctl enable docker
systemctl start docker

# Verify Docker installation
if ! docker --version; then
    echo -e "${RED}Docker installation failed. Please check the logs and try again.${NC}"
    exit 1
fi

# Ensure Docker starts on boot
echo -e "${YELLOW}Ensuring Docker starts on boot...${NC}"
wsl_conf="/etc/wsl.conf"
if ! grep -q "service docker start" "$wsl_conf"; then
    echo -e "\n[boot]\ncommand=\"service docker start\"" >> "$wsl_conf"
    echo -e "${GREEN}Added Docker start command to $wsl_conf${NC}"
else
    echo -e "${GREEN}Docker start command already in $wsl_conf${NC}"
fi

# Set up Docker logging
echo -e "${BLUE}Setting up Docker logging...${NC}"
mkdir -p /etc/docker
cat > "/etc/docker/daemon.json" << EOD
{
  "log-driver": "syslog",
  "log-opts": {
    "syslog-facility": "daemon",
    "tag": "docker/{{.Name}}"
  }
}
EOD
echo -e "${GREEN}Docker logging configured to use syslog${NC}"

# Set up log directory for file-based logging
LOG_DIR="/var/log/docker_apps"
mkdir -p "$LOG_DIR"
echo -e "${GREEN}Created log directory at $LOG_DIR${NC}"

# Create a script for log capture
cat > "/usr/local/bin/docker_log_capture.sh" << EOD
#!/bin/bash
for container in \$(docker ps --format "{{.Names}}"); do
    docker logs \$container > "$LOG_DIR/\${container}_\$(date +%Y%m%d_%H%M%S).log" 2>&1
done
EOD
chmod +x "/usr/local/bin/docker_log_capture.sh"

# Create a script for log cleanup
cat > "/usr/local/bin/docker_log_cleanup.sh" << EOD
#!/bin/bash
find $LOG_DIR -type f -name "*.log" -mtime +7 -delete
EOD
chmod +x "/usr/local/bin/docker_log_cleanup.sh"

# Create systemd service for log capture
cat > "/etc/systemd/system/docker-log-capture.service" << EOD
[Unit]
Description=Docker Log Capture Service
After=docker.service

[Service]
ExecStart=/usr/local/bin/docker_log_capture.sh
EOD

# Create systemd service for log cleanup
cat > "/etc/systemd/system/docker-log-cleanup.service" << EOD
[Unit]
Description=Docker Log Cleanup Service

[Service]
ExecStart=/usr/local/bin/docker_log_cleanup.sh
EOD

# Create systemd timer for hourly log capture
cat > "/etc/systemd/system/docker-log-capture.timer" << EOD
[Unit]
Description=Run Docker Log Capture hourly

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOD

# Create systemd timer for daily log cleanup
cat > "/etc/systemd/system/docker-log-cleanup.timer" << EOD
[Unit]
Description=Run Docker Log Cleanup daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOD

# Enable and start the timers
systemctl enable docker-log-capture.timer
systemctl start docker-log-capture.timer
systemctl enable docker-log-cleanup.timer
systemctl start docker-log-cleanup.timer

echo -e "${GREEN}Set up systemd timers for log capture and cleanup${NC}"

# Set up a Docker event listener to automatically set up syslog for new containers
cat > "/usr/local/bin/docker_syslog_setup.sh" << 'EOD'
#!/bin/bash

ensure_syslog_for_new_container() {
    local container_name=$1
    local container_id=$(docker inspect --format="{{.Id}}" "$container_name")
    
    if ! docker inspect --format='{{.HostConfig.LogConfig.Type}}' "$container_id" | grep -q "syslog"; then
        echo "Updating logging driver for $container_name to syslog"
        docker update --log-driver syslog \
            --log-opt syslog-facility=daemon \
            --log-opt tag="docker/$container_name" \
            "$container_id"
        
        docker restart "$container_id"
    fi
}

docker events --filter "type=container" --filter "event=start" --format "{{.Actor.Attributes.name}}" | while read container; do
    echo "New container detected: $container. Ensuring syslog logging."
    ensure_syslog_for_new_container "$container"
done
EOD

chmod +x "/usr/local/bin/docker_syslog_setup.sh"

# Set up systemd service for Docker syslog setup
cat > "/etc/systemd/system/docker-syslog-setup.service" << EOD
[Unit]
Description=Docker Syslog Setup
After=docker.service

[Service]
ExecStart=/usr/local/bin/docker_syslog_setup.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOD

systemctl enable docker-syslog-setup.service
systemctl start docker-syslog-setup.service

echo -e "${GREEN}Docker syslog setup service created and started.${NC}"

echo -e "${GREEN}System setup complete.${NC}"
echo -e "${YELLOW}You can now customize your installation, install additional packages, or make any other changes.${NC}"
echo -e "${YELLOW}When you're done, you can create a .tar file of your installation.${NC}"
echo -e "${BLUE}To export, run in PowerShell: ${YELLOW}wsl --export openSUSE-Tumbleweed C:\path\to\your-export.tar${NC}"
echo -e "${BLUE}To import, run in PowerShell: ${YELLOW}wsl --import <DistroName> <InstallLocation> C:\path\to\your-export.tar${NC}"
echo -e "${GREEN}On next boot after import, you'll be prompted to create a new user.${NC}"

# Create the first_boot script for the next boot
cat > /etc/profile.d/first_boot.sh << 'EOL'
#!/bin/bash

set -e

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Elevating privileges..."
    exec sudo -E bash "$0" "$@"
    exit $?
fi

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to validate username
validate_username() {
    local username=$1
    if [[ ! $username =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo -e "${RED}Invalid username. Use only lowercase letters, numbers, underscore, and hyphen. Must start with a letter or underscore.${NC}"
        return 1
    fi
    return 0
}

# Function to create user
create_user() {
    local username=$1
    local password=$2

    if id "$username" &>/dev/null; then
        echo -e "${YELLOW}User $username already exists. Skipping user creation.${NC}"
        return 0
    fi

    if useradd -m -s /bin/bash "$username"; then
        if echo "$username:$password" | chpasswd; then
            echo -e "${GREEN}User $username created successfully.${NC}"
            return 0
        else
            echo -e "${RED}Failed to set password for $username.${NC}"
            userdel -r "$username"
            return 1
        fi
    else
        echo -e "${RED}Failed to create user $username.${NC}"
        return 1
    fi
}

# Function to update WSL config
update_wsl_config() {
    local username=$1
    local wsl_conf="/etc/wsl.conf"

    if [ -f "$wsl_conf" ]; then
        sed -i '/^\[user\]/d' "$wsl_conf"
        sed -i '/^default=/d' "$wsl_conf"
    fi

    echo -e "\n[user]\ndefault=$username" >> "$wsl_conf"
    echo -e "${GREEN}Updated $wsl_conf with default user $username.${NC}"
}

echo -e "${BLUE}Setting up new user...${NC}"

while true; do
    echo -e "${YELLOW}Please enter the new username:${NC}"
    read username
    if validate_username "$username"; then
        break
    fi
done

while true; do
    echo -e "${YELLOW}Please enter the password:${NC}"
    read -s password
    echo
    echo -e "${YELLOW}Please confirm the password:${NC}"
    read -s password_confirm
    echo
    if [ "$password" = "$password_confirm" ]; then
        break
    else
        echo -e "${RED}Passwords do not match. Please try again.${NC}"
    fi
done

if create_user "$username" "$password"; then
    update_wsl_config "$username"
    echo -e "${GREEN}User setup complete.${NC}"
    echo -e "${YELLOW}To apply changes, please restart your WSL instance.${NC}"
    echo -e "${BLUE}You can do this by:${NC}"
    echo -e "1. Exiting this WSL terminal."
    echo -e "2. Opening PowerShell and running: ${YELLOW}wsl --shutdown${NC}"
    echo -e "3. Reopening your WSL terminal."
    echo -e "${GREEN}After restart, you will be logged in as: $username${NC}"
    
    # Remove this script
    rm -f "$0"
else
    echo -e "${RED}User setup failed. Please try running the script again.${NC}"
    exit 1
fi
EOL

chmod +x /etc/profile.d/first_boot.sh

EOF

    chmod +x "$setup_script"
    echo -e "${GREEN}Created system setup script at $setup_script${NC}"
}

# Main execution
enable_systemd
create_system_setup_script

echo -e "${GREEN}Initial setup complete.${NC}"
echo -e "${YELLOW}Please restart your WSL instance to continue the setup process.${NC}"
echo -e "${BLUE}You can do this by:${NC}"
echo -e "1. Exiting this WSL terminal."
echo -e "2. Opening PowerShell and running: ${YELLOW}wsl --shutdown${NC}"
echo -e "3. Reopening your WSL terminal."
echo -e "${GREEN}The system setup will continue automatically on next boot.${NC}"
