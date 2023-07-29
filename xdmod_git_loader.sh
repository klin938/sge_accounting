#!/bin/bash

hostname="$(hostname | awk -F"." '{print $1}')"
current_time="$(date "+%Y.%m.%d-%H.%M.%S")"

# Usage: $0 [TRIGGER|USER] [FROM_COMMIT_HASH] [TO_COMMIT_HASH
#
# FROM_COMMIT_HASH: the hash of a last commit from where the script should start to
# process. Normally this is the TO_COMMIT_HASH from the previous run.
# 
# TO_COMMIT_HASH: the hash of the commit up to where the script should be processing.
# This hash will be recorded in a text file for the next run. 

trigger="${1:-$USER}"
FROM_H="${2:-FROM_COMMIT_HASH}"
TO_H="${3:-$(git rev-parse --verify HEAD)}"

# Detect the script path
script_path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
repo_path="$script_path" # this script always inside the repo

exec > /tmp/xdmod_git_loader.log
exec 2>&1

printf "#############################################$current_time#####################################\n"
printf "## HOST: $hostname    WHO: $trigger    REPOSITORY: $repo_path\n"
printf "##\n"
printf "## FROM_COMMIT_HASH: $FROM_H\n"
printf "## TO_COMMIT_HASH: $TO_H\n"
printf "#####################################################################################################\n"

cd "$repo_path"

todo_list="$(git diff --name-status $FROM_H $TO_H | grep -e "^A")"

if [[ -z "$todo_list" ]]
then
	printf "ERROR: todo_list is empty. No new commited files found in the repository.\n"
	exit 2
else
	printf "$todo_list\n"
fi

while read -r file; do
	printf "\n###########################$file###########################\n"
	dir="$(echo $file | awk -F"/" '{print $1}')"
	file_name="$(echo $file | awk -F"/" '{print $2}')"
	xdmod_res="$(echo $dir | awk -F"_" '{print $1}')"
	xdmod-shredder -r $xdmod_res -f sge -i $file
	sleep 10
	printf "\n\n\n"
done <<< "$(echo "$todo_list" | awk '{print $2}')"

xdmod-ingestor

# Record the hash used as the starting point of next run
echo $TO_H > ./FROM_COMMIT_HASH

cat /tmp/xdmod_git_loader.log | mailx -s "$hostname: XDMoD has processed new data" root

exit 0
