#### This script fully configures your OpenSUSE Tumbleweed WSL for WSLg useing KDE Plasma 6. For rapid deployment of graphical environment of opensuse tumbleweed wsl systems.
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
#### This script was written by chaos0frenzy.
#### original source [https://github.com/chaos0frenzy/OpenSUSE_WLSg_KDE_Plasma-6_Setup_script/edit/main/OpenSUSE_WLSg_KDE_Plasma-6_Setup_script.](https://github.com/chaos0frenzy/OpenSUSE_WLSg_KDE_Plasma-6_Setup_script/blob/main/README.md?plain=1)
#### Information to produce this script was sourced from https://en.opensuse.org/openSUSE:WSL man pages and general knowledge.

# Breakdown:
## Introduction and Instructions: 
Provided at the top of the script.
## Ensure Root Privileges: 
Checks if the script is run with root privileges.
## Optimization Steps:
Enable parallel downloading.
Increase cache size.
Refresh repositories non-interactively.
## Add Repositories: 
Adding required repositories with auto-import of GPG keys.
## Distribution Upgrade: 
Perform a distribution upgrade.
Refresh and Upgrade Packages: Refresh and upgrade existing packages.
## Enable systemd: 
Edit /etc/wsl.conf to enable systemd.
## Install Required and Optional Packages: 
Install necessary packages and optional packages.
## Create Scripts and Services: 
Create and configure necessary scripts and services for Weston and KDE Plasma.
## Enable Services: 
Enable and start the required services.
## Optional Services: 
Create, enable, and start optional services for NumLock, htop, Discover, and Neofetch.
Completion Message: Informs the user that the setup is complete and prompts for a restart of the WSL instance.
## Known issues:
The desktop opens in WSLg.exe. This has no true configuration; you can edit it from the files wslg.rdp and wslg_desktop.rdp in the WSL folder. The default seems to work best from my testing. You can move the openSUSE desktop around with the Win + arrow keys.
