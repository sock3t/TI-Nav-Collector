# TI-Nav-Connector
Connector script to pull player data from a The Isle server and send it to the TI-Nav API

# Install:
* Enable WSL & install Debian
** https://docs.microsoft.com/en-us/windows/wsl/
** depending on your OS click on "Quickstart" and choose:
*** Windows 10: "Install WSL & update to WSL 2"
*** Windows Server: "Install on Windows Server"
* Start debian
** Windows 10: go to "Install required packages"
** Windows Server:
*** Upgrade the Debian from 9 to 10
**** sed -i -e 's/stretch/buster/' /etc/apt/sources.list
**** echo "apt update && apt upgrade -y && apt full-upgrade -y && apt autoremove -y && apt clean -y && apt auto-clean -y" | sudo -i 
* Install required packages
** sudo apt install -y inotify-tools gawk sed jo jq curl git parallel
** Optional packages: sudo apt install -y vim psmisc man
* Clone TI-Nav-Collector repository from Github
** git clone https://github.com/sock3t/TI-Nav-Collector.git

# Run:
* Change into TI-Nav-Collector folder
** cd ./TI-Nav-Collector
* Set the path to your TI server
** the "C" drive of your Windows system is mounted in Debian by default under "/mnt/c"
** adjust the config parameter in "TI-Nav-Collector.conf" accordingly
* Run TI-Nav-Collector
** ./TI-Nav-Collector.sh
