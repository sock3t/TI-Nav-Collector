#!/bin/bash

if [[ -z "$1" ]] 
then
	echo "1st parameter missing: full path to PlayerData json file"
	exit 1
else
	_userjson="$1";
fi

if [[ -z "$2" ]] 
then
	echo "2nd parameter missing: timestamp of this update in epoch milliseconds"
	exit 1
else
	_UpdateEpoch="$2";
fi


#########################
## prepare JSON according to TI-Nav API
###########

# get Steam ID from player json
_SteamID="$(jq -j '.SteamId' "${_userjson}")"

#(location code such as -100,50) - the json file has the coordinated with proper sign, vulnona does not support minute precision today so the first characters in front of the period are sufficient
_X=$(jq -j '.X' "${_userjson}")
_x=${_X%%.*}
_lat=${_x:0:-3}
_Y=$(jq -j '.Y' "${_userjson}")
_y=${_Y%%.*}
_long=${_y:0:-3}
_Coordinates="${_long},${_lat}"
# for testing we can randomly generate coordinates (just comment _Coordinates variable above):
if [[ -z "$_Coordinates" ]] 
then
	_lat=$(( $RANDOM % 1000 ))
	_long=$(( $RANDOM % 800 ))
	_Coordinates="-${_long},-${_lat}"
fi

#########################

# check whether we need to send an update - did the coordinates change?
if [[ -s "./IDs/${_SteamID}.lastcoord" ]]
then
	egrep -q -- "${_Coordinates}" ./IDs/${_SteamID}.lastcoord
	_ret=$?
	if [[ ${_ret} -eq 0 ]]
	then
		# remove players json so it will not be included in the next update
		rm ./IDs/${_SteamID}.json
		exit 2
	fi
else
	_DinoSpecies=$(jq -j '.Class' "${_userjson}")
	_HerdID=$(jq -j '.TargetingTeamId' "${_userjson}")

	# write json file for player
	jo -- -s SteamID="${_SteamID}" -s UpdateEpoch="${_UpdateEpoch}" -s DinoSpecies="${_DinoSpecies}" -s Coordinates="${_Coordinates}" -s HerdID="${_HerdID}" > ./IDs/${_SteamID}.json
fi

echo -n ${_Coordinates} > ./IDs/${_SteamID}.lastcoord
