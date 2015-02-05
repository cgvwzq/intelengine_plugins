#!/bin/bash

# ReverSHe DNS
# Author: Pepe Vila
# Date: 2015/02/05

# Input - JSON stdin: 
#
# {
#   "source" : ["ip1", "ip2", ...],
#   "domain" : ""
# }
#

# Output - JSON stodout:
#
# {
#   "ip1" : ["domainA", "domainB", ...],
#   "ip2" : ["domainC", "domainD", ...]
# }
#

# Dependecies:
# - jshon (libjansson-dev)
# - dig

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
		'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/536.5 (KHTML, like Gecko) Chrome/19.0.1084.56 Safari/536.5'
		'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:13.0) Gecko/20100101 Firefox/13.0.1'
		'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_4) AppleWebKit/534.57.2 (KHTML, like Gecko) Version/5.1.7 Safari/534.57.2'
		'Opera/9.80 (Windows NT 5.1; U; en) Presto/2.10.229 Version/11.60'
		'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)'
		'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; en-GB)'
		'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1)'
		'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)'
	)

	if [ -z url ]; then
		return
	fi

	curl -s -H "User-Agent: ${agents[$(($RANDOM%${#agents[@]}))]}" --url "$url" | grep -Po "$regex" | sort -u
} 

# Parse input
INPUT=$(cat -)
declare -a iplist=($(echo "$INPUT" | jshon -Q -e source -a -u))
domain=$(echo "$INPUT" | jshon -Q -e domain -u)

# If domain is provided, get DNS servers
declare -a NS=('8.8.8.8')
if [ ! -z $domain ]; then
	NS+=($(dig NS "$domain" | grep -Po "^[^;].*NS\t\K(.*)$"))
fi

# Create an output hash map for each IP
declare -A output=()

# For each NS do a reverse DNS resolution of every IP
for SERVER in ${NS[@]}; do
	for IP in ${iplist[@]}; do
		output[$IP]+=""
		for name in $(dig -x "$IP" "@$SERVER" | grep -Po "^[^;].*PTR\t\K(.*)$"); do
			add "$IP" "$name"
		done
	done
done

# Retrofeed with Bing API
# TODO: implement pagination 
for IP in ${iplist[@]}; do
	data=$(get_and_parse "http://www.bing.com/search?q=ip:$IP" '<li class="b_algo">(?:<div class="b_title">)?<h2><a href="(https?|ftps?)://\K([^/]*)')
	for name in $data; do
		# Check correctnesa
		# TODO: improve with NS or remove it
		if ( dig "$name" | grep -Pq "IN\tA\t$IP" ); then
			add "$IP" "$name"
		fi
	done
done

# Generate JSON output
OUT=$(jshon -Q -n {} -n [] -i "askedto")
for ip in ${!output[@]}; do
	OUT=$(echo $OUT | sed '/^$/d' | jshon -Q -n [] -i "$ip")
	for domain in ${output[$ip]}; do
		OUT=$(echo $OUT | jshon -e "$ip" -s "$domain" -i 0 -p)	
	done
done

for name in ${NS[@]}; do
	OUT=$(echo $OUT | jshon -Q -e "askedto" -s "$name" -i 0 -p)
done

# Print output to stdout
echo $OUT

exit
