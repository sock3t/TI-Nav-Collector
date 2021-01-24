# TI-Nav-Collector

**Note:**
_This tool is public available but a registration is required. If you are interested in providing map / navigation functionality to your The Isle server then please follow the Install and Running instructions. During the initial run of the tool it will guide you to introduce yourself (or more precisely your TI server) in [Discussion's Join ALPHA Testing Category](https://github.com/sock3t/TI-Nav-Collector/discussions?discussions_q=category%3A%22Join+ALPHA+Testing%22)_.

# What is this about?
The TI-Nav-Collector script collects player data on a The Isle server and sends it to [TI-Nav](https://ti-nav.net).
This will allow any player who plays on that TI server to track her/his own postion on the map.
[TI-Nav](https://ti-nav.net) also allows players to share their position with other players who are playing on the same TI server.

This script is based on bash and a set of GNU tools. So a linux environment will be required to run it on a windows OS based system.
Cygwin might work, but I have not tested it.
Windows Subsystem for Linux (WSL) is rather new so I provide guidance how to install it below.


# Install:
* Enable WSL & install Debian
  * [WSL Documentation](https://docs.microsoft.com/en-us/windows/wsl/)
  * depending on your OS click on "Quickstart" and choose:
    * **Windows 10**: "Install WSL 1"
    * **Windows Server**: "Install on Windows Server"
* Start debian
  * **Windows 10**: go to "Install required packages"
  * **Windows Server**:
    * Upgrade the Debian from 9 to 10
      * `sudo sed -i -e 's/stretch/buster/' /etc/apt/sources.list`
      * `sudo apt update && sudo apt upgrade -y && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt clean -y && sudo apt auto-clean -y`
      * the installer will pop up a message once asking whether you want to have service restarted automatically - please answer yes
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
  * this command can help to find the path: `find /mnt/c/ -name "The Isle Dedicated Server" 2> /dev/null` 
* Run TI-Nav-Collector
  * `./TI-Nav-Collector.sh`
  * Initial server registration will take place and some information about your TI server will be shown
    * copy this information and share it in [Discussion's Join ALPHA Testing Category](https://github.com/sock3t/TI-Nav-Collector/discussions?discussions_q=category%3A%22Join+ALPHA+Testing%22)
  * The Collector will do an initial sync everytime it is started
  * Once the Collector is running it will only execute if there are players online on the server
  * The Isle servers update player coordinates and other parameters roughly every ~10 seconds, so this is how often the Collector will loop through that data and send it to TI-Nav
