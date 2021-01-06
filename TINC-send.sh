#!/bin/bash

# parameters:
# ${_ServerID} ${_ServerMap} ${_server_game_ini} ${_server_playerdata_folder} [true|false]

if [[ -z "$1" ]] 
then
	echo "1st parameter missing: ServerID"
	exit 1
else
	_ServerID="$1";
fi

if [[ -z "$2" ]] 
then
	echo "2nd parameter missing: ServerMap"
	exit 1
else
	_ServerMap="$2";
fi

if [[ -z "$3" ]] 
then
	echo "3rd parameter missing: Full path of game.ini"
	exit 1
else
	_server_game_ini="$3";
fi

if [[ -z "$4" ]] 
then
	echo "4th parameter missing: Full path of Playerdata folder"
	exit 1
else
	_server_playerdata_folder="$4";
fi

if [[ -z "$5" ]] 
then
	echo "5th parameter missing: boolean whether to update all players or only players who are currently playing on this server"
	exit 1
else
	_updateAll="$5";
fi

## fixed variables

# curl stuff
_curl="curl -o curl.api_response -s -S --stderr curl.err -H \\\"Content-Type: application/json\\\" "
_URL="https://ti-nav.net/apis/api-bulk.php"

# get TI server name
_ServerName=$(awk -F "=" '/ServerName/ {print $2}' "${_server_game_ini}" | tr -dc "[[:print:]]")

# get Server Admins SteamdIDs
_ServerAdmins=$(awk -F "=" '/AdminsSteamIDs/ {print $2}' "${_server_game_ini}" | tr -d '\r')

# set up counters for basic stats
_online_count=0
_update_count=0
_no_change_count=0

if [[ "${_updateAll}" = "true"  ]]
then
	# list all player json files for full sync
	# +
	#(timestamp of milliseconds from 1970/01/01 00:00:00 UTC) conforms to the timestamp format that is required by vulnona
	#_OnlinePlayers="$(find "${_server_playerdata_folder}" -type f -regextype posix-extended -regex '.*/[0-9]{17}.json')"
	_OnlinePlayers="$(find "${_server_playerdata_folder}" -type f -regextype posix-extended -regex '.*/[0-9]{17}.json' -printf '%p;%T@\n')"
	# make sure they get all incl. in the bulk.json
	rm ./IDs/* &> /dev/null
else
	# find players who are currently online by checking which jsons have been modified wihtin then last 10 secs - TI server writes a json file for each player currently online every 10 secs
	# +
	#(timestamp of milliseconds from 1970/01/01 00:00:00 UTC) conforms to the timestamp format that is required by vulnona
	_OnlinePlayers="$(find "${_server_playerdata_folder}" -type f -regextype posix-extended -regex '.*/[0-9]{17}.json' -printf '%p;%T@\n' -mmin 0.17)"
	# delete all temporary json files from last run
	rm ./IDs/*.json &> /dev/null
fi

# wc -l does not work if there is one singel player, so we need to grep for lines but not newlines
_online_count=$(echo -n "${_OnlinePlayers}" | egrep -c '^')

# create IDs folder if needed
if [[ ! -d "./IDs" ]]; then mkdir -p ./IDs; fi

# now create TI-Nav compatible json file for each player
echo -n "${_OnlinePlayers}" | egrep -v "^$" | parallel -j 6 --joblog ./joblog "./TINC-player.sh {}"

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
	#eval echo ${_curl} -d @./bulk.json \\\"${_URL}\\\" | bash
fi
# reporting
_update_count=$(awk '$7==0' ./joblog | wc -l)
_no_change_count=$(awk '$7==2' ./joblog | wc -l)
echo "${_online_count} online players / ${_update_count} updated / ${_no_change_count} ignored due to no coordinate change"
