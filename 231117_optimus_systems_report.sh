#!/bin/bash

currentDatetime="$(date "+%Y-%m-%d %H:%M:%S")"
oneDayAgo="$(date --date='24 hours ago' '+%Y-%m-%d %H:%M:%S')"
recipient="anquadros@gmail.com"
subject="⚠️ Optimus $currentDatetime"

report="----------------------------------------------------------\n"
report+="OPTIMUS $currentDatetime\n"
report+="----------------------------------------------------------\n"
ubuntu_version="$(lsb_release -r -s 2>/dev/null | grep -oP '\d+\.\d+')"
ubuntu_codename="$(lsb_release -c | cut -f2)"
ubuntu_update="$(cat /var/log/apt/history.log | grep 'Start-Date' | tail -n 1 | cut -d ' ' -f2-)"
#----
report+="- UBUNTU $ubuntu_version $ubuntu_codename\n"
report+="- Updated $ubuntu_update\n\n"

report+="----------------------------------------------------------\n"
report+="UNATTENDED UPDATES\n"
report+="----------------------------------------------------------\n"
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

report+="----------------------------------------------------------\n"
pihole_version="$(pihole version | grep 'Pi-hole version' | awk '{print $4, $5, $6}')"
report+="PIHOLE $pihole_version\n"
report+="----------------------------------------------------------\n"
pihole_installation_date="$(stat -c %y /opt/pihole/gravity.sh | cut -d ' ' -f1)"
pihole_status="$(pihole status | grep -vE '^\s*$' | tr '\n' ' ')"
pihole_ftl_status="$(sudo systemctl status pihole-FTL | awk '/Active:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print}')"
#----
pihole_blocked_file1="$(sudo grep 'gravity blocked' /var/log/pihole/pihole.log | wc -l)"
pihole_blocked_file2="$(sudo grep "$(date --date='1 day ago' '+%b %d')" /var/log/pihole/pihole.log.1 | grep 'gravity blocked' | wc -l)"
pihole_blocked="$((pihole_blocked_file1 + pihole_blocked_file2))"
#----
report+="- STATUS: $pihole_status\n"
report+="- FTL: $pihole_ftl_status\n"
report+="- BLOCKEDQUERIES: $pihole_blocked\n"
report+="- GRAVITY.SH UPDATE: $pihole_installation_date\n"
report+="- ERRORS:\n"
report+="$(journalctl -u pihole-FTL -u pihole --since '24 hours ago' | grep -i 'error')\n\n"

report+="----------------------------------------------------------\n"
timeshift_version="$(timeshift --version | awk '{print $2}')"
report+="TIMESHIFT $timeshift_version\n"
report+="----------------------------------------------------------\n"
timeshift_status="$(sudo timeshift --list | grep -A 1 "Status :" | awk 'NR%2==1 { status=$0 } NR%2==0 { gsub("Status :", "", status); print status, $0 }')"
timeshift_last_backup="$(sudo timeshift --list | grep -Po '(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})' | tail -n 1)"
#----
report+="- STATUS:$timeshift_status\n"
report+="- LAST BACKUP: $timeshift_last_backup\n"
report+="- ERRORS:\n"
report+="$(journalctl -u timeshift --since '24 hours ago' | grep -i 'error')\n\n"

report+="----------------------------------------------------------\n"
plex_version="$(dpkg -l | grep plexmediaserver | awk '{print $3}')"
report+="PLEX $plex_version\n"
report+="----------------------------------------------------------\n"
plex_status="$(sudo systemctl is-active plexmediaserver)"
plex_last_started=$(sudo systemctl show --property=ActiveEnterTimestamp plexmediaserver | awk -F= '{print $2}')
#----
report+="- STATUS: $plex_status\n"
report+="- LAST STARTED: $plex_last_started\n"
report+="- ERRORS:\n"
report+="$(journalctl -u plexmediaserver --since '24 hours ago' | grep -i 'error')\n\n"

report+="----------------------------------------------------------\n"
report+="OTHER ERRORS \n"
report+="----------------------------------------------------------\n"
error_logs=$(awk -v current="$currentDatetime" -v oneDayAgo="$oneDayAgo" '
function toEpoch(t,    a, b, c) {
    split(t, a, "T");
    split(a[2], b, "-");
    split(b[1], c, ":");
    return mktime(a[1] " " c[1] " " c[2] " " c[3]);
}
BEGIN {
    gsub(/-|:/, " ", oneDayAgo);
    gsub(/-|:/, " ", current);
    startEpoch = toEpoch(oneDayAgo);
    endEpoch = toEpoch(current);
}
{
    logTimestamp = $1 " " $2;
    gsub(/-|:/, " ", logTimestamp);
    logEpoch = toEpoch(logTimestamp);
    if (logEpoch >= startEpoch && logEpoch <= endEpoch && /ERROR/ && !/pihole-FTL|pihole|plex|timeshift/) {
        print $0;
    }
}' /var/log/syslog)

report+="$error_logs\n"

# ----------------------------------------------------------

# Send the report via email
echo -e "$report" | mail -s "$subject" "$recipient"
