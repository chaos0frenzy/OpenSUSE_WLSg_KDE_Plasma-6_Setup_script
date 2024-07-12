# Deployment
# 
# sudo nano first_boot.sh
#
# sudo chmod +x firstboot_setup.sh
#
# sudo cp first_boot.sh /etc/profile.d/
#
# sudo ./firstboot_setup.sh
#
#!/bin/bash

# Prompt for username
echo "Please enter the new username:"
read username

# Prompt for password
echo "Please enter the password:"
read -s password

# Create the new user
useradd -m -s /bin/bash $username

# Set the password for the new user
echo "$username:$password" | chpasswd

# Clean up this script
rm -f /etc/profile.d/first_boot.sh

# Set the default user for WSL
echo "[user]" >> /etc/wsl.conf
echo "default=$username" >> /etc/wsl.conf

echo "Setup complete. Please restart WSL."
