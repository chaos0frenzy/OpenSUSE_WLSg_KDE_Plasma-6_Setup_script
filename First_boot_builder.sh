# This script is designed to give a first boot like experiance the next time you boot useful if you plan to make an image and redeploy so you can get your setup with root then run this script and have a new user after you import .tar to wsl

# How to Use the Script
# Save the script to a file, e.g., firstboot_setup.sh:

# Copy code
# sudo nano firstboot_setup.sh
# Make the script executable:

# Copy code
# sudo chmod +x firstboot_setup.sh

# Run the script:
# Copy code
# sudo ./firstboot_setup.sh

# Reboot the system:
# sudo reboot
# When you log in after the reboot, the first boot script should run, prompting you for a username and password, and perform the necessary setup. This makes the system easily redeployable

#!/bin/bash

# Create the first boot script
cat << 'EOF' | sudo tee /etc/profile.d/firstboot.sh > /dev/null
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

# Make the first boot script executable
sudo chmod +x /etc/profile.d/firstboot.sh

# Create the systemd service file
cat << 'EOF' | sudo tee /etc/systemd/system/firstboot.service > /dev/null
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

# Create a symlink to ensure the script is executed
sudo ln -s /etc/profile.d/firstboot.sh /usr/local/bin/firstboot.sh

# Enable the systemd service
sudo systemctl enable firstboot.service

echo "Setup complete. Please reboot the system."
