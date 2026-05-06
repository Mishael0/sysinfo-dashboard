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
   readonly SERVICES=("ssh" "cron" "nginx"


