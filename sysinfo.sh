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


