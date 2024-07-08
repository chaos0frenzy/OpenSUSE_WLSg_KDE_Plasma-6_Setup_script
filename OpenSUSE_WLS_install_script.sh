#!/bin/bash
# Before you start:
# 
# 1. Install nano, WSL GUI, and WSL systemd patterns:
#    sudo zypper in nano
#    sudo zypper in -t pattern wsl_gui
#    sudo zypper in -t pattern wsl_systemd
# 
# 2. Edit /etc/wsl.conf to enable systemd:
#    sudo nano /etc/wsl.conf
#    [boot]
#    systemd=true
#
# 3. Restart your WSL instance after editing the configuration.
#
# 4. Then sudo nano ./setup_script.sh
# paste this script 
# 
# chmod +x setup_script.sh
#
# sudo ./setup_script.sh
#
# Ensure the script is run with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root or using sudo."
    exit 1
fi

# Add repositories with priority
sudo zypper ar --if-not-exists -cfp 90 'https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/Essentials/' packman-essentials
sudo zypper ar --if-not-exists -cfp 90 'https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/' packman
sudo zypper ar --if-not-exists -fp 75 https://download.opensuse.org/repositories/KDE:/Unstable:/Qt/openSUSE_Tumbleweed/ KDE:Unstable:Qt
sudo zypper ar --if-not-exists -fp 75 https://download.opensuse.org/repositories/KDE:/Unstable:/Frameworks/openSUSE_Factory/ KDE:Unstable:Frameworks
sudo zypper ar --if-not-exists -fp 75 https://download.opensuse.org/repositories/KDE:/Unstable:/Applications/KDE_Unstable_Frameworks_openSUSE_Factory/ KDE:Unstable:Applications
sudo zypper ar --if-not-exists -fp 75 https://download.opensuse.org/repositories/KDE:/Unstable:/Extra/KDE_Unstable_Frameworks_openSUSE_Factory/ KDE:Unstable:Extra

# Perform distribution upgrade
sudo zypper -v dup --allow-vendor-change

# Install necessary packages
sudo zypper install flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Refresh and upgrade packages
sudo zypper refresh
sudo zypper up
sudo zypper dup

# Install additional packages
sudo zypper install plasma6-session plasma6-workspace plasma6-desktop dolphin konsole weston xrandr discover neofetch opi nano pulseaudio NetworkManager sddm htop

# Edit /etc/wsl.conf
echo -e "[boot]\nsystemd=true" | sudo tee /etc/wsl.conf

# Create start-weston.sh script
sudo bash -c 'cat > /usr/local/bin/start-weston.sh <<EOF
#!/bin/bash
export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
export WAYLAND_DISPLAY=wayland-0
export DISPLAY=:0
/usr/bin/weston --backend=x11-backend.so --tty=1
EOF'

# Create weston.service
sudo bash -c 'cat > /etc/systemd/system/weston.service <<EOF
[Unit]
Description=Weston Wayland Compositor
After=network.target

[Service]
User=chaos
Environment="XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir"
Environment="WAYLAND_DISPLAY=wayland-0"
Environment="DISPLAY=:0"
ExecStart=/usr/local/bin/start-weston.sh
Restart=always

[Install]
WantedBy=default.target
EOF'

# Make scripts executable
sudo chmod +x /usr/local/bin/start-weston.sh
sudo chmod +x /etc/systemd/system/weston.service

# Stop and start WSL (this part is done in PowerShell)
powershell.exe -Command "wsl -t openSUSE-Tumbleweed"
powershell.exe -Command "wsl"

# Enable and start necessary services
sudo systemctl enable pulseaudio
sudo systemctl start pulseaudio
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager
sudo systemctl enable sddm
sudo systemctl start sddm

# Create start-plasma.service
sudo bash -c 'cat > /etc/systemd/system/start-plasma.service <<EOF
[Unit]
Description=Start Plasma 6 in WSL
After=weston.service

[Service]
User=chaos
Environment="XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir"
Environment="WAYLAND_DISPLAY=wayland-0"
Environment="DISPLAY=:0"
ExecStart=/usr/local/bin/start-plasma.sh
Restart=always

[Install]
WantedBy=default.target
EOF'

# Create start-plasma.sh script
sudo bash -c 'cat > /usr/local/bin/start-plasma.sh <<EOF
#!/bin/bash
export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
export WAYLAND_DISPLAY=wayland-0
export DISPLAY=:0
dbus-launch startplasma-wayland
EOF'

# Make the script executable
sudo chmod +x /usr/local/bin/start-plasma.sh

# Reload systemd daemon and enable services
sudo systemctl daemon-reload
sudo systemctl enable weston.service

# Create numlock.service
sudo bash -c 'cat > /etc/systemd/system/numlock.service <<EOF
[Unit]
Description=Enable NumLock on startup

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c "echo \'activate\' > /sys/class/leds/input3::numlock/brightness"

[Install]
WantedBy=multi-user.target
EOF'

# Create htop.service
sudo bash -c 'cat > /etc/systemd/system/htop.service <<EOF
[Unit]
Description=htop - Interactive process viewer
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/htop
Restart=always

[Install]
WantedBy=default.target
EOF'

# Reload systemd daemon and enable services
sudo systemctl daemon-reload
sudo systemctl enable numlock.service
sudo systemctl enable htop.service