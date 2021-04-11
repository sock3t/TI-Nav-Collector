#!/bin/bash
# endless loop to push player properties to TI-Nav:

# Supported The Isle Server versions
_supported_versions="0.5.19.27 0.5.19.28 0.6.22.12 0.6.30.37 0.6.48.29" 

# get folder of The Isle server from config file:
_config="./TI-Nav-Collector.conf"
. ${_config}

# the ServerSecretID file
_secretFile="./ServerSecretID.txt"

# the "Saved" folder
_server_saved_folder="${_the_isle_server_folder}/TheIsle/Saved"

# folder of the PlayerData 
_server_playerdata_folder="${_server_saved_folder}/PlayerData"
# create the folder in case it does not exist yet - new servers don't have that folder until the first user joins
mkdir -p "${_server_playerdata_folder}"

# folder of the server log
_server_config_folder="${_server_saved_folder}/Config/WindowsServer"
# server log
_server_game_ini="${_server_config_folder}/Game.ini"

# folder of the server log
_server_log_folder="${_server_saved_folder}/Logs"
# server log
_server_log_file="${_server_log_folder}/TheIsle.log"

crawlServerLog () {
	#########
	# Some of the following checks might fail / return empty on servers which have a high uptime (the TI server, not the OS).
	# This is because the server.log files will be rotated and the lines I am gepping for only appear once during server start.
	# So I might end up asking TI server admins to put these into the .conf file.
	#
	# ! The server log file has some nasty DOS style characters so we need to strip these off before further processing value gathered from there !
	#
	
	# check whether TI server runs a supported version - TI devs need to put this somewhere else, log files will rotate!
	_ServerVersion=$(egrep "ProjectVersion" "${_server_log_file}" | tail -n 1 | cut -d']' -f 3 | cut -d' ' -f 5 | tr -dc "[[:print:]]")
	for _version in ${_supported_versions}
	do
		if [[ "${_ServerVersion%.}" = "${_version}" ]]
		then
			_OK=1
		fi
	done
	if [[ ${_OK} -ne 1 ]]
	then
		echo "Unsupported version of TI server: ${_ServerVersion%.}"
		echo "exiting."
		exit 1
	fi
	
	# get TI server STEAM IP - this changes every time the TI server is restarted. This is the hook to resend all player's json files every once in a while. 
	#
	# we use hash of server name for ServerID from now on
	#_server_ip=$(egrep "SteamP2P" "${_server_log_file}" | tail -n 1 | cut -d']' -f 3 | cut -d' ' -f 7 | tr -dc "[[:print:]]")
	#_ServerID=${_server_ip/:/_}
	
	# Get current running map:
	# This is useless atm, becasue there is only Isla_Spiro.
	# But there might be other maps again in the near future.
	# Like with the SteamP2P the TI devs should expose the currently running map somwhere else because log files are heavy to crawl and will rotate sooner or later.
	# An API or rcon would make much sense here.
	#
	# let's hardcode this for now - less server log crawling
	#_currentmap=$(egrep "LoadMap" "${_server_log_file}" | tail -n 1 | cut -d'(' -f 2 | tr -d ")" | tr -dc "[[:print:]]")
	#_ServerMap=${_currentmap##*/}
	_ServerMap="Isla_Spiro"
	#
	#########
}

findRecentLogBackup () {
	_RecentLogBackup="$(find "${_server_log_folder}" -maxdepth 1 -quit -type f -iname 'TheIsle-backup-*' -mmin 0.5)"
}
crawlGameIni () {
	# get TI server name
	_ServerName=$(awk -F "=" '/ServerName/ {print $2}' "${_server_game_ini}" | tr -dc "[[:print:]]")
	# ServerID should be safely unique to never have a colision: 16 (hex) to the power of 6 allows more than 16 million combinations - as of 2021 I don't assume that there will be more than 1000 TI servers in the "near future". So 6 chars should be plenty of head room.
	_ServerID="$(echo -n ${_ServerName} | b2sum | cut -b 1-6)"
	
	# get Server Admins' SteamdIDs
	_ServerAdmins="$(awk -F "=" '/AdminsSteamIDs/ {print $2}' "${_server_game_ini}" | tr -d '\r')"
}

serverRegistration () {
	# The server needs a SECRET so only this server can manipulate the server table in the DB on TI-Nav in future.
	# This secret will be created by the TI-Nav system during intial registration of the TI server.
	# The secret is only known by TI-Nav and the TI server owner and should never be shared with anyone else
	# If the secret is lost no more updates can be made for this TI server on TI-Nav
	# In such a case either the TI server needs to be renamed or TI-Nav needs to wipe all data about this server to allow a new registration

	jo -- -s ServerID="${_ServerID}" -s ServerName="${_ServerName}" -s ServerMap="${_ServerMap}" > server.json
	
	_curl="curl -o curl.api_response -s -S --stderr curl.err -w \'%{http_code}\' -H \'Content-Type: application/json\'"
	_URL="https://ti-nav.net/apis/server-registration-api.php"
	
	# send the Server json to TI-Nav
	_status_code=$(eval echo ${_curl} -d @./server.json \\\"${_URL}\\\" | bash)
	case "${_status_code}" in
		200)
			cp curl.api_response "${_secretFile}"
			rm curl.api_response
			checkAPIAccess
			;;
		400)
			echo "We did not send proper json formatted data:"
			cat curl.api_response
			cat curl.err
			echo
			exit 1
			;;
		409)
			echo "Registration failed:"
			cat curl.api_response
			cat curl.err
			echo
			exit 1
			;;
		415)
			echo "We did not use the proper conten type:"
			cat curl.api_response
			cat curl.err
			echo
			exit 1
			;;
		*)
			echo "unknown status code"
			exit 1
	esac
		
}

checkAPIAccess () {
	if [[ -s "${_secretFile}" ]]
	then
		_secret=$(cat ${_secretFile})
		if [[ -n "${_secret}" ]] 
		then
			_curl="curl -s -o /dev/null -w \'%{http_code}\' -I -H \'X-TINav-ServerID: ${_ServerID}\'"
			_URL="https://ti-nav.net/apis/server-registration-api.php"
			case "$(eval echo ${_curl} \\\"${_URL}\\\" | bash)" in
				"202")
					_ServerSecretID=$(cat ${_secretFile})
					return 0
					;;
				"403")
					_OnlinePlayers="$(find "${_server_playerdata_folder}" -type f -regextype posix-extended -regex '.*/[0-9]{17}.json' -mmin 0.17 -printf '%p;%T@\n' | egrep -c '^')"
					_TotalPlayers="$(find "${_server_playerdata_folder}" -type f -regextype posix-extended -regex '.*/[0-9]{17}.json' -printf '%p;%T@\n' | egrep -c '^')"
					echo "This TI server has been registered @ TI-Nav.net but it is not enabled atm!"
					echo
					echo "If you see this message for the first time then please firmly introduce yourselve here:"
					echo "https://github.com/sock3t/TI-Nav-Collector/discussions?discussions_q=category%3A%22Join+ALPHA+Testing%22"
		                        echo
		                        echo "Please incl. this information with your introduction:"
		                        echo -e "ServerID:\t${_ServerID}"
		                        echo -e "ServerName:\t${_ServerName}"
		                        echo -e "Online players:\t${_OnlinePlayers}"
		                        echo -e "Total players:\t${_TotalPlayers}"
		                        echo "Additionally please describe the average amount of player usually playing on your server."
		                        echo
		                        echo "This information will greatly help with alpha testing and resource planing!"
		                        echo "Thanks a lot for your interest and participation during alpha testing!"
					return 1
					;;
				"405")
					echo "Bad method. The TI-Nav-Collector script might have been modified or there is a man in the middle tampering going on."
					exit 1
					;;
				"404")
					echo "Unknown ServerID."
					echo "This TI server is not registered @ TI-Nav.net."
					echo "Yet there is a ${_secretFile} with a ServerSecretID inside."
					echo "In case this TI server has been renamed recently: Make a backup copy of the ${_secretFile} (you might want to return to the old server name) and re-run TI-Nav-Collector"
					echo "In case the TI-Nav-Collector worked before and the TI Server was not renamed please reach out to the TI-Nav dev."
					echo "Exiting."
					exit 1
					;;
				"500")
					echo "Server side issue. Please inform the TI dev. Exiting"
					exit 1
					;;
				*)
					echo "Unknown registration HEAD issue. Exiting."
					exit 1
			esac
		else
			echo "ServerSecretID missing from ${_secretFile}."
			echo "If you have a backup of this file then restore it - if you lost your ServerSecretID then reach out to the TI-Nav dev."
			echo "If you never registered this TI server to TI-Nav.net then try to delete ${_secretFile} and re-run TI-Nav-Collector"
			exit 1
		fi
	else
		echo "Start registration"
		serverRegistration
	fi
}


# crawl the server logs once at first start
crawlServerLog
crawlGameIni
until checkAPIAccess
do
	echo
	echo "Retrying whether server is enabled every 5 minutes:"
	sleep 300
	clear
done
echo "Initial update syncs all known players to TI-Nav..."
./TINC-send.sh "${_ServerID}" "${_ServerSecretID}" "${_ServerAdmins}" "${_server_playerdata_folder}" "true"

while true
do
	inotifywait -qq "${_server_playerdata_folder}"
	# slow down for a fraction of a sec to allow the FS layer to finish the write operation
	sleep .2
	
	# crawl the server logs only if the log rotates
	findRecentLogBackup
	if [[ -n "${_RecentLogBackup}"  ]]
	then
		echo -n "Log rotation detected... "
		date
		echo "Next update will sync all known players to TI-Nav"
		crawlServerLog
		crawlGameIni
		CheckAPIAccess
		./TINC-send.sh "${_ServerID}" "${_ServerSecretID}" "${_ServerAdmins}" "${_server_playerdata_folder}" "true"
	else
		crawlGameIni
		./TINC-send.sh "${_ServerID}" "${_ServerSecretID}" "${_ServerAdmins}" "${_server_playerdata_folder}" "false"
	fi
	echo "waiting for next run ..."
	echo
done
