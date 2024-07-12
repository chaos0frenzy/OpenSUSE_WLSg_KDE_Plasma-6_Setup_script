#this script is designed to give a first boot like experiance the next time you boot useful if you plan to make an image and redeploy so you can get your setup with root then run this script and have a new user after you import .tar to wsl
#
#!/bin/bash

# Step 1: Create the First Boot Script
cat << 'EOF' | sudo tee /etc/profile.d/firstboot.sh
#!/bin/bash

# Check if the firstboot has already run
if [ -f /etc/firstboot_done ]; then
  return
fi

echo "Welcome to your new installation of openSUSE Tumbleweed!"

# Prompt for username
read -p "Please enter your username: " username

# Create the user
useradd -m -s /bin/bash "$username"

# Set the password for the new user
passwd "$username"

# Set the password for root
echo "Please set the root password:"
passwd

# Mark that the firstboot script has run
touch /etc/firstboot_done

# Remove the script so it does not run again
rm -f /etc/profile.d/firstboot.sh

echo "Setup complete. Enjoy your system!"
EOF

# Make the script executable
sudo chmod +x /etc/profile.d/firstboot.sh

# Step 2: Create a Systemd Service
cat << 'EOF' | sudo tee /etc/systemd/system/firstboot.service
[Unit]
Description=First Boot Setup
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/firstboot.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

# Create a link to ensure the script is executed
sudo ln -s /etc/profile.d/firstboot.sh /usr/local/bin/firstboot.sh

# Enable the service
sudo systemctl enable firstboot.service

# Reboot the system
echo "Setup is complete. The system will now reboot."
sudo reboot
