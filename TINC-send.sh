#!/bin/bash

## fixed variables

#(timestamp of milliseconds from 1970/01/01 00:00:00 UTC) conforms to the timestamp format that is required by vulnona we will grab this once for each update - no need to call data for every player json
_UpdateEpoch=$(date +%s%N | cut -b1-13)

# Supported The Isle Server versions
_supported_versions="0.5.19.27 0.5.19.28 0.6.22.12"

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

# curl stuff
_curl="curl -o curl.api_response -s -S --stderr curl.err -H \\\"Content-Type: application/json\\\" "
_URL="https://ti-nav.de/api-bulk.php"

# some of these might fail / return empty on servers which have a high uptime (the TI server, not the OS). This is because the server.log files will be rotated and the lines I am gepping for only appear once during server start. So I might end up asking these from a config file - should be not much of a pain as server IP and name are unlikly to change frequently.

# get TI server STEAM IP
_server_ip=$(egrep "SteamP2P" "${_server_log_file}" | tail -n 1 | cut -d']' -f 3 | cut -d' ' -f 7 | tr -dc "[[:print:]]")
_ServerID=${_server_ip/:/_}
# get TI server name
_ServerName=$(awk -F "=" '/ServerName/ {print $2}' "${_server_game_ini}" | tr -dc "[[:print:]]")
# get Server Admins SteamdIDs
_ServerAdmins=$(awk -F "=" '/AdminsSteamIDs/ {print $2}' "${_server_game_ini}" | tr -d '\r')

# get TI server version
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

# get current running map the log file has some nasty DOS style characters so we need to strip these off before further processing this value:
_currentmap=$(egrep "LoadMap" "${_server_log_file}" | tail -n 1 | cut -d'(' -f 2 | tr -d ")" | tr -dc "[[:print:]]")
_ServerMap=${_currentmap##*/}

# how many player do we have to update @ vulnona?
_online_count=0
_update_count=0
_no_change_count=0

# we find players who are currently online by checking which jsons have been modified wihtin then last 10 secs - TI server writes a json file for each player currently online every 10 secs:
_OnlinePlayers="$(find "${_server_playerdata_folder}" -type f -regextype posix-extended -regex '.*/[0-9]{17}.json' -mmin 0.17)"
# alternatively we can just search all json files for testing
#_OnlinePlayers="$(find "${_server_playerdata_folder}" -type f -regextype posix-extended -regex '.*/[0-9]{17}.json')"

_online_count=$(echo "${_OnlinePlayers}" | wc -l)

# create IDs folder if needed
if [[ ! -d "./IDs" ]]; then mkdir -p ./IDs; fi

# now create TI-Nav compatible json file for each player
echo "${_OnlinePlayers}" | egrep -v "^$" | parallel --joblog ./joblog "./TINC-player.sh {} ${_UpdateEpoch}"

# send the bulk update only if we have any player json - there might be players on the server but no one moved.
if ls ./IDs/*.json &> /dev/null
then
	_Servers_json="$(jo -- -s ServerID="${_ServerID}" -s ServerName="${_ServerName}" -s ServerMap="${_ServerMap}")"
	for _admin in ${_ServerAdmins}
	do
		_Admins_json+=("$(jo -- -s SteamID="${_admin}")")
	done
	
	#jo -p "Servers=$(jo -a "$(echo ${_Servers_json})")" "Admins=$(jo -a "$(echo ${_Admins_json})")" "Players=$(jo -a $(cat ./IDs/*.json))"
	jo "Servers=$(jo -a "$(echo -n ${_Servers_json})")" "Admins=$(jo -a $(echo -n ${_Admins_json[@]}))" "Players=$(jo -a $(cat ./IDs/*.json))" > bulk.json
	
	# send the json to TI-Nav
	eval echo ${_curl} -d @./bulk.json \\\"${_URL}\\\" | bash
fi
# reporting
_update_count=$(awk '$7==0' ./joblog | wc -l)
_no_change_count=$(awk '$7==2' ./joblog | wc -l)
echo "${_online_count} online players / ${_update_count} updated / ${_no_change_count} ignored due to no coordinate change"
