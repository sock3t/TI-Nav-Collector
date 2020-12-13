# TI-Nav-Collector

**Note:**
_This tool is not yet public available. If you are interested in providing map / navigation functionality to your The Isle server then please introduce yourself in [Discussion's Join ALPHA Testing Category](https://github.com/sock3t/TI-Nav-Collector/discussions?discussions_q=category%3A%22Join+ALPHA+Testing%22)_

Collector script that pulls player data from a The Isle server and sends it to [TI-Nav](https://ti-nav.de)
This will allow any player on that TI server to track her/his own postion on a map.
[TI-Nav](https://ti-nav.de) also allows players to share their position with other players.

This script is based on bash and a set of GNU tools. So a linux environment will be required to run it on a windows OS based system.
Cygwin might work, but I have not tested it.
Windows Subsystem for Linux (WSL) is rather new so I provide guidance how to install it below.


# Install:
* Enable WSL & install Debian
  * [WSL Documentation](https://docs.microsoft.com/en-us/windows/wsl/)
  * depending on your OS click on "Quickstart" and choose:
    * **Windows 10**: "Install WSL & update to WSL 2"
    * **Windows Server**: "Install on Windows Server"
* Start debian
  * **Windows 10**: go to "Install required packages"
  * **Windows Server**:
    * Upgrade the Debian from 9 to 10
      * `sed -i -e 's/stretch/buster/' /etc/apt/sources.list`
      * `echo "apt update && apt upgrade -y && apt full-upgrade -y && apt autoremove -y && apt clean -y && apt auto-clean -y" | sudo -i`
* Install required packages
  * `sudo apt install -y inotify-tools gawk sed jo jq curl git parallel`
  * Optional packages: `sudo apt install -y vim psmisc man`
* Clone TI-Nav-Collector repository from Github
  * `git clone https://github.com/sock3t/TI-Nav-Collector.git`

# Run:
* Change into TI-Nav-Collector folder
  * `cd ./TI-Nav-Collector`
* Set the path to your TI server
  * the "C" drive of your Windows system is mounted in Debian by default under `/mnt/c`
  * adjust the config parameter in `TI-Nav-Collector.conf` accordingly
* Run TI-Nav-Collector
  * `./TI-Nav-Collector.sh`
  * will only execute if there are players online on the server
  * executes every ~10 seconds
