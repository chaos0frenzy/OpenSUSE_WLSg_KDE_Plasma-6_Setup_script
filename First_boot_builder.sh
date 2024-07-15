#!/bin/bash
# This script is a tool to take a fresh install of OpenSUSE tumbleweed and set it up for docker deployment with one command
#
# !!! DO NOT CREATE A USER AT USER CREATION ON FRESH INSTALL OF OPENSUSE !!!
# once you do your first reboot create a .tar of the of your install with the command wsl --export openSUSE-Tumbleweed C:any-file-path/ANY-FILE-NAME.tar then when you import the .tar with the command wsl --import any-name-you-want C:\WSL\(or any other location you would like this to be saved) C:/your-file-location.tar
# this script will also autoconfigure that import with a user name and password for evan faster deployment 
#Deployment Instructions:
# 1. Create the script file:
#  sudo joe wsl_initial_setup.sh && sudo chmod +x wsl_initial_setup.sh && sudo ./wsl_initial_setup.sh
#
# 6. Restart WSL when prompted.

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
        cat > "$wsl_conf" << EOF
[boot]
systemd=true

[automount]
enabled = true
root = /mnt/
options = "metadata,umask=22,fmask=11"
mountFsTab = true

[automount.mounts]
"/mnt/c/WSL Files" = "/home/$USER/windows_files"
EOF
        echo -e "${GREEN}Enabled systemd in $wsl_conf${NC}"
    else
        sed -i '/^\[boot\]/,/^\[.*\]/ s/^systemd=.*/systemd=true/' "$wsl_conf"
        if ! grep -q '^\[boot\]' "$wsl_conf" || ! grep -q 'systemd=true' "$wsl_conf"; then
            sed -i '/^\[boot\]/a systemd=true' "$wsl_conf"
        fi
        echo -e "${GREEN}Updated systemd setting in $wsl_conf${NC}"
    fi
}

# Create the system setup script
create_system_setup_script() {
    cat > /etc/profile.d/system_setup.sh << 'EOF'
#!/bin/bash

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

# Ensure Docker starts on boot
echo -e "${YELLOW}Ensuring Docker starts on boot...${NC}"
if ! grep -q "service docker start" /etc/wsl.conf; then
    echo -e "\n[boot]\ncommand=\"service docker start\"" >> /etc/wsl.conf
    echo -e "${GREEN}Added Docker start command to /etc/wsl.conf${NC}"
else
    echo -e "${GREEN}Docker start command already in /etc/wsl.conf${NC}"
fi

# Create first_boot.sh script
cat > /etc/profile.d/first_boot.sh << 'EOL'
#!/bin/bash

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
    echo -e "${YELLOW}Please restart WSL one final time to log in as your new user.${NC}"
    echo -e "${BLUE}To do this:${NC}"
    echo -e "1. Exit this WSL terminal."
    echo -e "2. Open PowerShell and run: ${YELLOW}wsl --shutdown${NC}"
    echo -e "3. Reopen your WSL terminal."
    echo -e "${GREEN}After restart, you will be logged in as: $username${NC}"
    
    # Remove this script and system_setup.sh
    rm -f /etc/profile.d/system_setup.sh
    rm -f /etc/profile.d/first_boot.sh
else
    echo -e "${RED}User setup failed. Please try running the script again.${NC}"
    exit 1
fi
EOL

chmod +x /etc/profile.d/first_boot.sh

echo -e "${GREEN}System setup complete.${NC}"
echo -e "${YELLOW}Please restart WSL to run the first boot script and set up your user.${NC}"
echo -e "${BLUE}To do this:${NC}"
echo -e "1. Exit this WSL terminal."
echo -e "2. Open PowerShell and run: ${YELLOW}wsl --shutdown${NC}"
echo -e "3. Reopen your WSL terminal."

# Remove this script
rm -f "$0"
EOF

    chmod +x /etc/profile.d/system_setup.sh
    echo -e "${GREEN}Created system setup script at /etc/profile.d/system_setup.sh${NC}"
}

# Main execution
enable_systemd
create_system_setup_script

echo -e "${GREEN}Initial setup complete.${NC}"
echo -e "${YELLOW}Please restart your WSL instance now to continue the setup process.${NC}"
echo -e "${BLUE}To do this:${NC}"
echo -e "1. Exit this WSL terminal."
echo -e "2. Open PowerShell and run: ${YELLOW}wsl --shutdown${NC}"
echo -e "3. Reopen your WSL terminal."
echo -e "${GREEN}The system setup will continue automatically on next boot.${NC}"

# Remove this script
rm -f "$0"
