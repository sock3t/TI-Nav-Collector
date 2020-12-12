#!/bin/bash
# simple endless loop to update coordinates of player to vulnona:

# folder of the TI Server 
_the_isle_folder="/mnt/c/SteamCMD/steamapps/common/The Isle Dedicated Server"

# folder of the PlayerData 
_playerdata="${_the_isle_folder}/TheIsle/Saved/PlayerData/"

while true
do
	inotifywait -qq "${_playerdata}"
	sleep .2
	./TINC-send.sh
	# uncomment this line for testing - comment the two lines above TINC-send.sh
	#sleep 10
	echo "waiting for next run ..."
	echo
done
