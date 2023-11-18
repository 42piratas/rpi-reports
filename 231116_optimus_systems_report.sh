#!/bin/bash

# Calculate the timestamp for 24 hours ago
last_24_hours=$(date -d '24 hours ago' +\%Y-\%m-\%d\ \%H:\%M:\%S)

# Define the subject line with the emoji and current date
subject="⚠️ Optimus Report $(date +\%Y-\%m-\%d)"

# Define the processes you want to monitor, including Plex and Pi-hole
processes=("plex" "pihole" "pihole-FTL" "timeshift" "unattended")

# Initialize variables to store process, upgrade, error, and DNS status information
process_info=""
upgrade_info=""
warning_error_info=""
dns_status=""

# Loop through the processes and gather process-related information
for process in "${processes[@]}"; do
    process_info+="\n\nProcess: $process\n"
    process_info+="------------------\n"
    
    # Check if the process is the Pi-hole DNS service
    if [ "$process" == "pihole-FTL" ]; then
        dns_status=$(systemctl is-active "$process")
        process_info+="DNS Status: $dns_status\n"
    else
        process_info+="Current Status:\n"
        process_info+="$(ps aux | grep "$process" | grep -v "grep")\n"
    fi

    # Use journalctl to gather logs related to this process from the last 24 hours with a priority of 4 or higher
    process_logs=$(journalctl --since "$last_24_hours" -p 4..0 | grep -i "$process")
    process_info+="$process_logs\n"

    # Check if the process has been upgraded in the last 24 hours
    upgrade_logs=$(journalctl --since "$last_24_hours" | grep -i "$process" | grep -i "upgraded")
    if [ -n "$upgrade_logs" ]; then
        upgrade_info+="\n\n$process Upgrades in the Last 24 Hours\n"
        upgrade_info+="------------------\n"
        upgrade_info+="$upgrade_logs\n"
    fi
done

# Use journalctl to gather logs with priority level 4 (Warning) from other processes
warning_logs=$(journalctl --since "$last_24_hours" -p 4 | grep -v -e "journal" -e "systemd")

# Remove logs related to the listed processes from the warning logs
for process in "${processes[@]}"; do
    warning_logs=$(echo "$warning_logs" | grep -v -i "$process")
done

# Append warning logs to the warning_error_info variable
warning_error_info+="\n\nWarning Logs from Other Processes in the Last 24 Hours\n"
warning_error_info+="------------------\n"
warning_error_info+="$warning_logs"

# Send an email with the combined process, upgrade, error, and DNS status information
echo -e "$process_info$upgrade_info$warning_error_info" | mail -s "$subject" anquadros@gmail.com