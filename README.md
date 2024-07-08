##### This script fully configures your OpenSUSE Tumbleweed WSL for WSLg useing KDE Plasma 6 
#
# Before you start:
# 
## 1. Install nano, WSL GUI, and WSL systemd patterns:
#### sudo zypper in nano
#### sudo zypper in -t pattern wsl_gui
#### sudo zypper in -t pattern wsl_systemd
## 2. Edit /etc/wsl.conf to enable systemd:
#### sudo nano /etc/wsl.conf
#### [boot]
#### systemd=true

# 3. Restart your WSL instance after editing the configuration.

## 4. configure the script to your needs
#### on line 
## 5. Then sudo nano ./setup_script.sh
#### paste this script  
#### chmod +x setup_script.sh
#### sudo ./setup_script.sh
## 6. Reboot
####This script was written by chaos0frenzy.
#### original source https://github.com/chaos0frenzy/OpenSUSE_WLSg_KDE_Plasma-6_Setup_script/edit/main/OpenSUSE_WLSg_KDE_Plasma-6_Setup_script.
#### Information to produce this script was sourced from https://en.opensuse.org/openSUSE:WSL man pages and general knowledge.
