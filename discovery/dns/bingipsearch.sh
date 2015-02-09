#!/bin/bash

# Given a IP use Bing searcher to obtain domains hosted in that IP
# Author: Pepe Vila
# Date: 2015/02/09

# Input - JSON stind:
#
# {
#  "ips" : ["ip1", "ip2", ...],
# }
#

# Output - JSON stodout:
# 
# {
#  "ip1" : ["name12", "name12", ...],
#  "ip2" : ["name21", "name22", ...],
#  ...
# }

# Exit with error
function exit_error {
	echo "[!] Error." 
	exit 1
} >&2

# Add domain to IP list if not included yet
function add {
	ip=$1
	name=$2	
	if [ -z "${output[$ip]}" ] || [[ ! "${output[$ip]}" == *"$name"* ]]; then
		output[$ip]+="$name "
	fi
}

# Download URL and returns unique matches according to regexp
function get_and_parse {
	url=$1
	regex=$2

	declare -a agents=(
		'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.93 Safari/537.36'
		'Mozilla/5.0 (Windows NT 6.3; rv:36.0) Gecko/20100101 Firefox/36.0'
	)

	if [ -z url ]; then
		return
	fi

	curl -s -H "User-Agent: ${agents[$(($RANDOM%${#agents[@]}))]}" --url "$url" | grep -Po "$regex" | sort -u
} 

# Parse input
RAW_INPUT=$(cat -)
declare -a IPS=($(echo "$RAW_INPUT" | jshon -Q -e "ips" -a -u))

# Create an output hash map for each entry
declare -A output=()

# For each IP search on Bing for hostnames
# TODO: implement pagination
for IP in ${IPS[@]}; do
	DATA=$(get_and_parse "http://www.bing.com/search?q=ip:$IP" '<li class="b_algo">(?:<div class="b_title">)?<h2><a href="(https?|ftps?)://\K([^/]*)')
	for NAME in $DATA; do
		# Verification
		if ( dig "$NAME" | grep -Poq "IN\tA\t$IP" ); then
			add "$IP" "$NAME"
		fi
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
