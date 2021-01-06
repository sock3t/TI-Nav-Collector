#!/bin/bash

if [[ -z "$1" ]] 
then
	echo "1st parameter missing: full path to PlayerData json file + epoch separated by ;"
	exit 1
else
	_userjson="$1";
fi

#########################
## transform the given player json + epoch string
###########
# everything left of the semicolon in the userjson is the unc path to the json file
_json="${_userjson%%;*}";
# everything right of the semicolon in the userjson is the epoch string
_ts="${_userjson##*;}";
# remove the decimal dot
_ts2="${_ts//./}";
# remove the last digit
_epoch="${_ts2:0:-1}";

#########################
## prepare JSON according to TI-Nav API
###########

# get Steam ID from player json - player json is named by steamID already but this might change in future, so we stick with this.
_SteamID="$(jq -j '.SteamId' "${_json}")"

#(location code such as -100,50) - the json file has the coordinated with proper sign, vulnona does not support minute precision today so the first characters in front of the period are sufficient
_X=$(jq -j '.X' "${_json}")
_x=${_X%%.*}
_lat=${_x:0:-3}
_Y=$(jq -j '.Y' "${_json}")
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
_YW=$(jq -j '.Yaw' "${_json}")
_Yaw=${_YW%%.*}

#########################

# check whether we need to send an update - did the coordinates change?
if [[ -s "./IDs/${_SteamID}.lastcoord" ]]
then
	egrep -q -- "${_Coordinates};${_Yaw}" ./IDs/${_SteamID}.lastcoord
	_ret=$?
	if [[ ${_ret} -eq 0 ]]
	then
		# remove players json so it will not be included in the next update
		rm ./IDs/${_SteamID}.json &> /dev/null
		exit 2
	fi
fi
_DinoSpecies=$(jq -j '.Class' "${_json}")
_HerdID=$(jq -j '.TargetingTeamId' "${_json}")
_Growth=$(jq -j '.Growth' "${_json}")
_Stamina=$(jq -j '.Stamina' "${_json}")
_Hunger=$(jq -j '.Hunger' "${_json}")
_Thirst=$(jq -j '.Thirst' "${_json}")

# write json file for player
jo -- -s SteamID="${_SteamID}" -s UpdateEpoch="${_epoch}" -s DinoSpecies="${_DinoSpecies}" -s Coordinates="${_Coordinates}" -s Yaw="${_Yaw}" -s HerdID="${_HerdID}" -s Growth="${_Growth}" -s Stamina="${_Stamina}" -s Hunger="${_Hunger}" -s Thirst="${_Thirst}" > ./IDs/${_SteamID}.json

echo -n "${_Coordinates}" > ./IDs/${_SteamID}.lastcoord
