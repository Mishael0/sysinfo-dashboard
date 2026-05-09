#!/usr/bin/env bash
set -euo pipefail

# ===========================================
# SysInfo Health Dashboard
# ===========================================
# Author: Udo-Esinna Mishael
# Description: Displays live system health
#              information for Linux servers
# Usage: ./sysinfo.sh [--json]
# ===========================================

  # --- Colors ---

  if [[ -t 1 ]]; then
	  RED='\033[0;31m'
	  YELLOW='\033[1;33m'
	  GREEN='\033[0;32m'
	  CYAN='\033[0;36m'
	  BOLD='\033[1m'
	  NC='\033[0m'
  else
	  RED=''
	  YELLOW=''
	  GREEN=''
	  CYAN=''
	  BOLD=''
	  NC=''
  fi

  # --- Thresholds ---
  readonly  WARN_THRESHOLD=70
  readonly  CRIT_THRESHOLD=90

  # --- Services to check ---
  readonly SERVICES=("ssh" "cron" "nginx")

  # SYSTEM INFORMATION

  system_info() {
	  # local variables
	  local hostname
	  local os
	  local kernel
	  local uptime_seconds
	  local days
	  local hours
	  local minutes
	  local uptime_formatted

	  # Gather Data
	  hostname=$(hostname -f 2>/dev/null || hostname)
	  os=$(grep -oP '(?<=PRETTY_NAME=").*(?=")' /etc/os-release)
	  kernel=$(uname -r)

	  # Calculate Uptime from /proc/uptime
	  if [[ -f /proc/uptime ]]; then
		  uptime_seconds=$(awk '{print int($1)}' /proc/uptime)
		  days=$((uptime_seconds / 86400))
		  hours=$(( (uptime_seconds % 86400) / 3600 ))
		  minutes=$(( (uptime_seconds % 3600) / 60 ))
		  uptime_formatted="${days}d ${hours}h ${minutes}m"

	  else
		  uptime_formatted="N/A"

	  fi

	  if [[ "${JSON_MODE:-false}" == "true" ]]; then
		  JSON_HOSTNAME="$hostname"
		  JSON_OS="$os"
		  JSON_KERNEL="$kernel"
		  JSON_UPTIME="$uptime_formatted"

	  else

		  echo -e "${CYAN}${BOLD}"
		  echo "      LINUX SYSTEM HEALTH DASHBOARD      "
		  echo -e "========================================${NC}"
		  echo -e "${BOLD}[ SYSTEM INFO ]${NC}"
		  printf "%-15s: %s\n" "Hostname" "$hostname"
		  printf "%-15s: %s\n" "OS"       "$os"
		  printf "%-15s: %s\n" "Kernel"   "$kernel"
		  printf "%-15s: %s\n" "Uptime"   "$uptime_formatted"
		  echo ""

	  fi
  }

  cpu_info() {
	  local loadavg_1
	  local loadavg_2
	  local loadavg_3
	  local cpu_idle
	  local cpu_usage
	  local color
	  # Read load averages in one command
	  read loadavg_1 loadavg_2 loadavg_3 _ < /proc/loadavg

	#  Extract idle percentage and calculate usage
	cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{for(i=1;i<=NF;i++) if($i=="id," || $i=="id") print $(i-1)}')
	cpu_usage=$(awk -v idle="$cpu_idle" 'BEGIN {printf "%.0f", 100 - idle}')

	# Set color based on thresholds
	if [ "$cpu_usage" -ge "$CRIT_THRESHOLD" ]; then
		color="${RED}"
	elif [ "$cpu_usage" -ge "$WARN_THRESHOLD" ]; then
		color="${YELLOW}"
	else
		color="${GREEN}"
	fi

	# JSON or display
	if [[ "${JSON_MODE:-false}" == "true" ]]; then
		JSON_CPU_USAGE="$cpu_usage"
		JSON_LOAD_1="$loadavg_1"
		JSON_LOAD_5="$loadavg_2"
		JSON_LOAD_15="$loadavg_3"
	else
		echo -e "${BOLD}[ CPU STATUS ]${NC}"
		printf "%-15s: %s%s%%${NC}\n"        "CPU Usage"     "$color"  "$cpu_usage"
		printf "%-15s: %s, %s, %s\n"         "Load (1/5/15)" "$loadavg_1" "$loadavg_2" "$loadavg_3"
		echo ""
	fi
}
mem_info() {
	local mem_total
	local mem_used
	local mem_free
	local mem_pecnt
	local swap_total
	local swap_used
	local swap_pecnt
	local mem_color
	local swap_color

	   # Read RAM data in one command
	   read mem_total mem_used mem_free < <(free -m | awk '/Mem:/ {print $2, $3, $4}')

	    # Calculate RAM percentage
	    mem_pecnt=$(( (mem_used * 100) / mem_total ))

	    # Read swap data
	    read swap_total swap_used < <(free -m | awk '/Swap:/ {print $2, $3}')

	    # Prevent division by zero
	    if [ "$swap_total" -gt 0 ]; then
		    swap_pecnt=$(( (swap_used * 100) / swap_total ))
	    else
		    swap_pecnt=0
	    fi

	    # RAM color
	    if [ "$mem_pecnt" -ge "$CRIT_THRESHOLD" ]; then
		    mem_color="${RED}"
	    elif [ "$mem_pecnt" -ge "$WARN_THRESHOLD" ]; then
		    mem_color="${YELLOW}"
	    else
		    mem_color="${GREEN}"
	    fi

	    # Swap color
	    if [ "$swap_pecnt" -gt 0 ]; then
		    swap_color="${YELLOW}"
	    else
		    swap_color="${GREEN}"
	    fi

	    # JSON or display
	    if [[ "${JSON_MODE:-false}" == "true" ]]; then
		    JSON_MEM_PCT="$mem_pecnt"
		    JSON_SWAP_PCT="$swap_pecnt"
	    else
		    echo -e "${BOLD}[ MEMORY STATUS ]${NC}"
		    printf "%-15s: %s%s%%${NC} (%sMB / %sMB)\n" "RAM Usage"  "$mem_color"  "$mem_pecnt"  "$mem_used"  "$mem_total"

		    if [ "$swap_total" -gt 0 ]; then
			    printf "%-15s: %s%s%%${NC} (%sMB / %sMB)\n" "Swap Usage" "$swap_color" "$swap_pecnt" "$swap_used" "$swap_total"
		    else
			    printf "%-15s: %s\n" "Swap" "None Configured"
		    fi
		    echo ""
	    fi



    }

  disk_info() {
	 local line filesystem size used avail pcent pcent_int mount
	 local color status
	 local disk_json="" entry

	   # Header (non-JSON mode)
	   if [[ "${JSON_MODE:-false}" != "true" ]]; then
		   echo -e "${BOLD}[ DISK USAGE ]${NC}"
		   printf "%-20s %-8s %-8s %-8s %-6s %s\n" \
			   "Filesystem" "Size" "Used" "Avail" "Use%" "Status"
	   fi

	   while IFS= read -r line; do
		   # Extract all columns in one operation
		   read -r filesystem size used avail pcent mount <<< "$line"

	  # Strip % sign to get clean integer
	  pcent_int=${pcent//%/}

	  # Threshold color logic
	  if (( pcent_int >= CRIT_THRESHOLD )); then
		  color="${RED}"
		  status="✖ CRITICAL"
	  elif (( pcent_int >= WARN_THRESHOLD )); then
		  color="${YELLOW}"
		  status="⚠ WARNING"
	  else
		  color="${GREEN}"
		  status="✔ OK"
	  fi   

	  # JSON accumulation
	  if [[ "${JSON_MODE:-false}" == "true" ]]; then
		  entry="{\"mount\":\"$mount\",\"used_percent\":$pcent_int}"
		  if [[ -z "$disk_json" ]]; then
			  disk_json="$entry"																	             else
			  disk_json="${disk_json}, $entry"																     fi
			  printf "%-20s %-8s %-8s %-8s %s%-6s${NC} %s\n" \
				  "$filesystem" "$size" "$used" "$avail" \																     "$color" "$pcent" "$status"
	  fi
 		 done < <(df -h --output=source,size,used,avail,pcent,target | grep '^/dev/')

	   #finalise
	   if [[ "${JSON_MODE:-false}" == "true" ]]; then 																    JSON_DISKS="[$disk_json]"							    										    else
		   echo "" 
	   fi	
   }

top_processes() {
	 local line pid mem cpu cmd mem_int color
	 local proc_json="" entry

	   if [[ "${JSON_MODE:-false}" != "true" ]]; then
		   echo -e "${BOLD}[ TOP 5 PROCESSES BY MEMORY ]${NC}"
		   printf "%-8s %-8s %-8s %s\n" "PID" "%MEM" "%CPU" "COMMAND"
	   fi
	   while IFS= read -r line; do
		   # Parse the four pre-formatted fields
		   read -r pid mem cpu cmd <<< "$line"

																					       	#  Strip path — get base command name only
																					         cmd=$(basename "$cmd" 2>/dev/null || echo "$cmd")

																						#  Convert float to integer for threshold comparison
																						 mem_int=${mem%.*}

																						## Color logic based on memory percentage
																						 if (( mem_int >= CRIT_THRESHOLD )); then
																							color="${RED}"
																						 elif (( mem_int >= WARN_THRESHOLD )); then
																							color="${YELLOW}"
																						 else
																							color="${GREEN}"
																						 fi

																						#  JSON or display
																						 if [[ "${JSON_MODE:-false}" == "true" ]]; then
																							entry="{\"pid\":$pid,\"mem_percent\":$mem,\"cpu_percent\":$cpu,\"command\":\"$cmd\"}"
																							if [[ -z "$proc_json" ]]; then
																								proc_json="$entry"
																							else
																								proc_json="${proc_json}, $entry"						        									fi
																						else
																								printf "%-8s %s%-8s${NC} %-8s %s\n" \
																									"$pid" "$color" "$mem" "$cpu" "$cmd"
																						fi
																							done < <(ps aux --sort=-%mem | awk 'NR>1 {print $2, $4, $3, $11}' | head -n 5)

																						# Finalise JSON array
																						if [[ "${JSON_MODE:-false}" == "true" ]]; then
																							JSON_PROCESSES="[$proc_json]"
																						else
																							echo ""
																						fi
																					}
																					network() {
																					       local line iface ip_cidr ip_addr mac internet_status
																					       local net_json="" entry

																						if [[ "${JSON_MODE:-false}" != "true" ]]; then
																							echo -e "${BOLD}[ NETWORK INTERFACES ]${NC}"
																							printf "%-15s %-20s %s\n" "Interface" "IP Address" "MAC Address"
																						fi
																						while IFS= read -r line; do
																							# Extract interface and IP in one read
																							read -r iface ip_cidr <<< "$line"
																							ip_addr=${ip_cidr%%/*}

																						 # Get MAC for this interface
																						 mac=$(ip link show "$iface" 2>/dev/null | awk '/ether/ {print $2}')
																						 mac="${mac:-N/A}"

																						 # JSON or display
																						 if [[ "${JSON_MODE:-false}" == "true" ]]; then
																							 entry="{\"interface\":\"$iface\",\"ip\":\"$ip_addr\",\"mac\":\"$mac\"}"
																							 if [[ -z "$net_json" ]]; then
																								 net_json="$entry"
																							 else
																								 net_json="${net_json}, $entry"
																							 fi
																						 else
																							 printf "%-15s %-20s %s\n" "$iface" "$ip_addr" "$mac"
																						 fi
																					 	done < <(ip -o addr show | grep ' inet ' | awk '{print $2, $4}')

																						# Finalise JSON array
																						if [[ "${JSON_MODE:-false}" == "true" ]]; then
																							JSON_NETWORK="[$net_json]"
																						fi
																						# Connectivity check
																						if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
																							internet_status="${GREEN}✔ Connected${NC}"
																							JSON_INTERNET="true"
																						else
																							internet_status="${RED}✖ No Connectivity${NC}"
																							JSON_INTERNET="false"
																						fi

																						if [[ "${JSON_MODE:-false}" != "true" ]]; then																	echo -e "\nInternet         : $internet_status"
																							echo ""
																						fi
																					}
