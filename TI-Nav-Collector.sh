#!/bin/bash
# simple endless loop to update coordinates of player to vulnona:

# Supported The Isle Server versions
_supported_versions="0.5.19.27 0.5.19.28 0.6.22.12 0.6.30.37"

# get folder of The Isle server from config file:
. ./TI-Nav-Collector.conf

# the "Saved" folder
_server_saved_folder="${_the_isle_server_folder}/TheIsle/Saved"

# folder of the PlayerData 
_server_playerdata_folder="${_server_saved_folder}/PlayerData"

# folder of the server log
_server_config_folder="${_server_saved_folder}/Config/WindowsServer"
# server log
_server_game_ini="${_server_config_folder}/Game.ini"

# folder of the server log
_server_log_folder="${_server_saved_folder}/Logs"
# server log
_server_log_file="${_server_log_folder}/TheIsle.log"

# folder of the PlayerData 
_playerdata="${_the_isle_server_folder}/TheIsle/Saved/PlayerData/"

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
	_server_ip=$(egrep "SteamP2P" "${_server_log_file}" | tail -n 1 | cut -d']' -f 3 | cut -d' ' -f 7 | tr -dc "[[:print:]]")
	_ServerID=${_server_ip/:/_}
	
	# Get current running map:
	# This is useless atm, becasue there is only Isla_Spiro.
	# But there might be other maps again in the near future.
	# Like with the SteamP2P the TI devs should expose the currently running map somwhere else because log files are heavy to crawl and will rotate sooner or later.
	# An API or rcon would make much sense here.
	_currentmap=$(egrep "LoadMap" "${_server_log_file}" | tail -n 1 | cut -d'(' -f 2 | tr -d ")" | tr -dc "[[:print:]]")
	_ServerMap=${_currentmap##*/}
	#
	#########
}

findRecentLogBackup () {
	_RecentLogBackup="$(find "${_server_log_folder}" -maxdepth 1 -quit -type f -iname 'TheIsle-backup-*' -mmin 0.5)"
}

# crawl the server logs once at first start
crawlServerLog
echo "Initial update syncs all known players to TI-Nav..."
./TINC-send.sh "${_ServerID}" "${_ServerMap}" "${_server_game_ini}" "${_server_playerdata_folder}" true

while true
do
	inotifywait -qq "${_playerdata}"
	sleep .2
	
	# crawl the server logs only if the log rotates
	findRecentLogBackup
	if [[ -n "${_RecentLogBackup}"  ]]
	then
		crawlServerLog
		echo -n "Log rotation detected... "
		date
		echo "Next update will sync all known players to TI-Nav"
		./TINC-send.sh "${_ServerID}" "${_ServerMap}" "${_server_game_ini}" "${_server_playerdata_folder}" true
	else
		./TINC-send.sh "${_ServerID}" "${_ServerMap}" "${_server_game_ini}" "${_server_playerdata_folder}" false
	fi
	echo "waiting for next run ..."
	echo
done
