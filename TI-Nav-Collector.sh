#!/bin/bash
# simple endless loop to update coordinates of player to vulnona:

# get folder of The Isle server from config file:
. ./TI-Nav-Collector.conf

# folder of the PlayerData 
_playerdata="${_the_isle_server_folder}/TheIsle/Saved/PlayerData/"

while true
do
	inotifywait -qq "${_playerdata}"
	sleep .2
	./TINC-send.sh
	# uncomment this line for testing - comment the two lines above ./TINC-send.sh
	#sleep 10
	echo "waiting for next run ..."
	echo
done
