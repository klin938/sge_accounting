#!/bin/sh

hostname="$(hostname | awk -F"." '{print $1}')"
current_time="$(date "+%Y.%m.%d-%H.%M.%S")"

# We always detect the script path, which is also the path of the local repository 
script_path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
repo_path="$script_path" # this script always inside the repo
trigger="${2:-$USER}"

# We target all rotated logs in the format of accounting-DATEEXT
SGE_CONF_PATH="/opt/gridengine/default/common"
SGE_ACCT_FILE="accounting-*"

exec > /tmp/sge_accounting_data_collector.log
exec 2>&1

printf "#############################################$current_time#####################################\n"
printf "## HOST: $hostname    WHO: $trigger    REPOSITORY: $repo_path\n"
printf "#####################################################################################################\n"

if [[ -z "$1" ]]
then
	printf "Usage - $0 XDMOD_RES_NAME [TRIGGER|USER]\n"
	exit 2
else
	xdmod_res="$1"
fi

# Check if accounting file has been rotated
if test -n "$(find $SGE_CONF_PATH -maxdepth 1 -name $SGE_ACCT_FILE -print -quit)"
then
	printf "FOUND the following rotated accounting files:\n$(ls ${SGE_CONF_PATH}/${SGE_ACCT_FILE})\n\n"
else
	printf "ERROR: rotated $SGE_CONF_PATH/$SGE_ACCT_FILE NOT FOUND.\n"
	exit 2
fi	


datadir="${repo_path}/${xdmod_res}_accounting"

if [[ ! -d "$datadir" ]]
then
	printf "ERROR: $datadir not found. Please check if the XDMoD resource name is correct.\n"
	exit 2
fi

mv -vn ${SGE_CONF_PATH}/${SGE_ACCT_FILE} "$datadir"

# Go to the Git repository
cd "$repo_path"
#git status
git add "$xdmod_res"_accounting/*
git commit -m "AUTO COMMIT: $hostname | $trigger | $current_time"

cat /tmp/sge_accounting_data_collector.log | mailx -s "$hostname: SGE accounting log rotated" root

exit 0
