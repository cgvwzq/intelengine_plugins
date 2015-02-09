#!/bin/bash

# Obtains NS entries given a domain name or an IP
# Author: Pepe Vila
# Date: 2015/02/09

# Input - JSON stind:
#
# {
#  "domains" : ["name1", "name2", ...],
# }
#

# Output - JSON stodout:
# 
# {
#  "name1" : ["NS11", "NS12", ...],
#  "name2" : ["NS21", "NS22", ...],
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

# Parse input
RAW_INPUT=$(cat -)
declare -a INPUT=($(echo "$RAW_INPUT" | jshon -Q -e "domains" -a -u))

# Create an output hash map for each entry
declare -A output=()

# For each entry get NS entries from DNS servers
for NAME in ${INPUT[@]}; do
	output[$NAME]=$(dig NS "$NAME" | grep -Po "^[^;].*NS\t\K(.*)$")
done

# Generate JSON output
OUT=$(jshon -Q -n {})
for NAME in ${!output[@]}; do
	OUT=$(echo $OUT | jshon -Q -n [] -i "$NAME")
	for NS in ${output[$NAME]}; do
		OUT=$(echo $OUT | jshon -e "$NAME" -s "$NS" -i 0 -p)
	done
done

# Print output to stdout
echo $OUT

exit
