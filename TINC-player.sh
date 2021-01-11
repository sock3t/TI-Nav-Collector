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
# provide ms precision which is 13 digits
_epoch="${_ts2:0:13}";

#########################
## prepare JSON according to TI-Nav API
###########

# get Steam ID from player json - player json is named by steamID already but this might change in future, so we stick with this.
_SteamID="$(jq -j '.SteamId' "${_json}")"

#(location code such as -100,50) - the json file has the coordinates with proper sign and high precision, yet vulnona does not support minute precision today so the digits in front of the period are sufficient
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

###############################################################################################
## check whether we need to send an update - did the coordinates change?
###############
#if [[ -s "./IDs/${_SteamID}.lastcoord" ]]
#then
#	egrep -q -- "${_Coordinates};${_Yaw}" ./IDs/${_SteamID}.lastcoord
#	_ret=$?
#	if [[ ${_ret} -eq 0 ]]
#	then
#		# remove players json so it will not be included in the next update
#		rm ./IDs/${_SteamID}.json &> /dev/null
#		exit 2
#	fi
#fi
###############
## ^^ A player might not be moving, yet other parameters like health, stam, growth, etc. might change - at least as long as the player is online and connected to the TI server
## ^^ Also there is a scenario called safe-logout or the opposite of that. In that case the player has diconnected from the TI server but did not wait for the safe logout period.
## ^^ In such a case the player's dino will remain present inside the TI server for 5 or 10 minutes. So other player passing by could "interact" with this dino and thus change the dino's parameters.
## ^^ But even plain things like heal and stam recover etc. will be applied to that dino during this period - the dino could also die.
## ^^ The TI server continues to update the player's json for that entire period.
## ^^ So TI-Nav-Collector needs to keep sending updates for dinos/players even if the coordinates do not change.
## ^^ I keep this here for future reference in case performance becomes an issue and I need to do "tuning" of player updates at the cost of some accuracy.
###############################################################################################

_DinoSpecies=$(jq -j '.Class' "${_json}")
_HerdID=$(jq -j '.TargetingTeamId' "${_json}")
_Growth=$(jq -j '.Growth' "${_json}")
_Health=$(jq -j '.Health' "${_json}")
_Stamina=$(jq -j '.Stamina' "${_json}")
_Hunger=$(jq -j '.Hunger' "${_json}")
_Thirst=$(jq -j '.Thirst' "${_json}")

# write json file for player
jo -- -s SteamID="${_SteamID}" -s UpdateEpoch="${_epoch}" -s DinoSpecies="${_DinoSpecies}" -s Coordinates="${_Coordinates}" -s Yaw="${_Yaw}" -s HerdID="${_HerdID}" -s Growth="${_Growth}" -s Health="${_Health}" -s Stamina="${_Stamina}" -s Hunger="${_Hunger}" -s Thirst="${_Thirst}" > ./IDs/${_SteamID}.json

echo -n "${_Coordinates}" > ./IDs/${_SteamID}.lastcoord
