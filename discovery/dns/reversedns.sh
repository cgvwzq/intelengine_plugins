#!/bin/bash

# Ask for inverse DNS resolutions to given NS for each IP
# Author: Pepe Vila
# Date: 2015/02/09

# Input - JSON stind:
#
# {
#  "servers" : ["dns1", "dns2", ...],
#  "ips" : ["ip1", "ip2", ...],
# }
#

# Output - JSON stodout:
# 
# {
#  "ip1" : ["domain11", "domain12", ...],
#  "ip2" : ["domain21", "domain22", ...],
#  ...
# }

# Dependencies
# - jshon (libjansson-dev)
# - dig

# Exit with error
function exit_error {
	echo "[!] Error." 
	exit 1
} >&2

# Add domain to IP list if not included yet
function add {
	IP=$1
	NAME=$2	
	if [ -z "${output[$IP]}" ] || [[ ! "${output[$IP]}" == *"$NAME"* ]]; then
		output[$IP]+="$NAME "
	fi
}

# Parse input
RAW_INPUT=$(cat -)
declare -a IPS=($(echo "$RAW_INPUT" | jshon -Q -e "ips" -a -u))
declare -a SERVERS=($(echo "$RAW_INPUT" | jshon -Q -e "servers" -a -u))

# If no servers given, use default NS 
if [ -z $SERVERS ]; then
	SERVERS=('8.8.8.8')
fi

# Create an output hash map for each entry
declare -A output=()

# For each IP perform inverse resolution with each Name Server
for NS in ${SERVERS[@]}; do
	for IP in ${IPS[@]}; do
		output[$IP]+=""
		for NAME in $(dig -x "$IP" "@$NS" | grep -Po "^[^;].*PTR\t\K(.*)$"); do
			add "$IP" "$NAME"	
		done
	done
done

# Generate JSON output
OUT=$(jshon -Q -n {})
for IP in ${!output[@]}; do
	OUT=$(echo $OUT | jshon -Q -n [] -i "$IP")
	for NAME in ${output[$IP]}; do
		OUT=$(echo $OUT | jshon -e "$IP" -s "$NAME" -i 0 -p)
	done
done

# Print output to stdout
echo $OUT

exit
