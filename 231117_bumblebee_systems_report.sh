#!/bin/bash

currentDatetime="$(date "+%Y-%m-%d %H:%M:%S")"
oneDayAgo="$(date --date='24 hours ago' '+%Y-%m-%d %H:%M:%S')"
recipient="anquadros@gmail.com"
subject="⚠️ Bumblebee $currentDatetime"

report+="---------------------------------------------\n"
report="BUMBLEBEE $currentDatetime\n"
report+="---------------------------------------------\n"
ubuntu_version="$(lsb_release -r -s 2>/dev/null | grep -oP '\d+\.\d+')"
ubuntu_codename="$(lsb_release -c | cut -f2)"
ubuntu_update="$(cat /var/log/apt/history.log | grep 'Start-Date' | tail -n 1 | cut -d ' ' -f2-)"
#----
report+="- UBUNTU $ubuntu_version $ubuntu_codename\n"
report+="- UPDATED: $ubuntu_update\n\n"

report+="---------------------------------------------\n"
report+="UNATTENDED UPDATES\n"
report+="---------------------------------------------\n"
#----
unattended_last_run="$(tail -n 1 /var/log/unattended-upgrades/unattended-upgrades.log | awk '{print $1, $2}')"
unattended_last_info="$(tail -n 1 /var/log/unattended-upgrades/unattended-upgrades.log | grep -o "INFO .*$" | cut -c 6-)"
unattended_pkgs="$(grep 'Install: ' /var/log/unattended-upgrades/unattended-upgrades-dpkg.log | wc -l)"
unattended_erros="$(cat /var/log/unattended-upgrades/unattended-upgrades.log | grep "ERROR")"
#----
report+="- LAST: $unattended_last_run\n"
report+="- INFO: $unattended_last_info\n"
report+="- PKGS: $unattended_pkgs\n"
report+="- ERRORS:\n"
report+="$unattended_erros\n\n"

report+="---------------------------------------------\n"
timeshift_version="$(timeshift --version | awk '{print $2}')"
report+="TIMESHIFT $timeshift_version\n"
report+="---------------------------------------------\n"
#----
timeshift_status="$(sudo timeshift --list | grep -A 1 "Status :" | awk 'NR%2==1 { status=$0 } NR%2==0 { gsub("Status :", "", status); print status, $0 }')"
timeshift_last_backup="$(sudo timeshift --list | grep -Po '(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})' | tail -n 1)"
#----
report+="- STATUS:$timeshift_status\n"
report+="- LAST BACKUP: $timeshift_last_backup\n"
report+="- ERRORS:\n"
report+="$(journalctl -u timeshift --since '24 hours ago' | grep -i 'error')\n\n"

report+="---------------------------------------------\n"
tor_version="$(sudo tor --version | awk 'NR==1 {print $3}')"
report+="TOR $tor_version\n"
report+="---------------------------------------------\n"
#----
tor_status="$(systemctl is-active tor)"
tor_default="$(systemctl is-active tor@default)"
#----
report+="- STATUS: $tor_status\n"
report+="- @DEFAULT: $tor_default\n"
report+="- ERRORS:\n"
report+="$(journalctl -u tor -u tor@default --since '24 hours ago' | grep -i 'error')\n\n"

report+="---------------------------------------------\n"
ipfs_agent="$(ipfs id -f "<aver>")"
report+="IPFS $ipfs_agent\n"
report+="---------------------------------------------\n"
#----
ipfs_id="$(ipfs id -f "<id>")"
ipfs_key="$(ipfs id -f "<pubkey>")"
ipfs_peers="$(ipfs swarm peers | wc -l)"
ipfs_bandwidth="$(ipfs stats bw | grep 'TotalIn\|TotalOut\|RateIn\|RateOut' | awk '{printf "%s %s %s ", $1, $2, $3}' && echo)"
#----
report+="- ID: $ipfs_id\n"
report+="- KEY: $ipfs_key\n"
report+="- PEERS: $ipfs_peers\n"
report+="- BANDWIDTH: $ipfs_bandwidth\n"
report+="- ERRORS:\n"
report+="$(journalctl -u ipfs --since '24 hours ago' | grep -i 'error')\n\n"

report+="---------------------------------------------\n"
#----
geth_info="$(geth attach --datadir /media/tisuang/Bumblebee/ethereum --exec 'admin.nodeInfo')"
geth_id="$(echo "$geth_info" | grep "id:" | awk -F " " '{print $2}')"
geth_name_line="$(echo "$geth_info" | grep "name:")"
geth_name="$(echo "\"$(echo "$geth_name_line" | cut -d '"' -f 2)\"")"
geth_block="$(geth attach --datadir /media/tisuang/Bumblebee/ethereum --exec 'eth.blockNumber')"
geth_net="$(echo "$geth_info" | sed -n '/protocols: {/,/^  }/p' | grep "network:" | awk -F ": " '{print $2}' | tr -d ',')"
#----
report+="ETHEREUM $geth_name\n"
report+="----------------------------------------------------------\n"
#----
report+="- ID: $geth_id\n"
report+="- NET: $geth_net\n"
report+="- BLOCK: $geth_block\n"
report+="- ERRORS:\n"
report+="$(journalctl -u geth --since '24 hours ago' | grep -i 'error')\n\n"

# report+="----------------------------------------------------------\n"
# report+="OTHER ERRORS \n"
# report+="----------------------------------------------------------\n"

# error_logs=$(awk -v current="$currentDatetime" -v oneDayAgo="$oneDayAgo" '
# function toEpoch(t,    a, b, c) {
#     split(t, a, "T");
#     split(a[2], b, "-");
#     split(b[1], c, ":");
#     return mktime(a[1] " " c[1] " " c[2] " " c[3]);
# }
# BEGIN {
#     gsub(/-|:/, " ", oneDayAgo);
#     gsub(/-|:/, " ", current);
#     startEpoch = toEpoch(oneDayAgo);
#     endEpoch = toEpoch(current);
# }
# {
#     logTimestamp = $1 " " $2;
#     gsub(/-|:/, " ", logTimestamp);
#     logEpoch = toEpoch(logTimestamp);
#     if (logEpoch >= startEpoch && logEpoch <= endEpoch && /ERROR/ && !/pihole-FTL|pihole|plex|timeshift/) {
#         print $0;
#     }
# }' /var/log/syslog)

# report+="$error_logs\n"

# ----------------------------------------------------------

# Send the report via email
echo -e "$report" | mail -s "$subject" "$recipient"