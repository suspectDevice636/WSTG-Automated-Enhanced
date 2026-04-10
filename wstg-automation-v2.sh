#!/bin/bash

#########################################
# WSTG Automated Scanner (v2 - Interactive)
# VERSION: 2.0.0
# Target: Single URL input with scan selection menu
# Output: Individual scan files organized by category
# Tools: Kali Linux CLI tools (nmap, nikto, sqlmap, curl, etc.)
#
# FEATURES:
# - Interactive menu for scan selection (all checked by default)
# - Real-time spinner showing scan progress
# - Overall progress bar (X/Y scans completed)
# - Detailed error messages with actual stderr
#########################################

#########################################
# ⚠️  IMPORTANT LEGAL NOTICE ⚠️
#########################################
# THIS SCRIPT IS FOR AUTHORIZED SECURITY TESTING ONLY
#
# ❌ DO NOT use this script to scan any systems without explicit,
#    written authorization from the system owner.
#
# ⚠️  UNAUTHORIZED ACCESS is ILLEGAL and may result in:
#    - Criminal prosecution
#    - Civil liability
#    - Imprisonment
#    - Substantial fines
#
# 📖 EDUCATIONAL USE ONLY
#    This tool is designed for learning and authorized penetration testing
#    in controlled environments with proper authorization.
#
# ✅ BEFORE RUNNING:
#    1. Verify you have written permission to test the target
#    2. Ensure the target is within your authorized scope
#    3. Review your local laws regarding security testing
#    4. Follow responsible disclosure practices
#
#########################################

VERSION="2.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Spinner frames - pure ASCII for maximum compatibility
SPINNER=( '/' '-' '\' '|' )
SPINNER_IDX=0

# Error tracking
FAILED_SCANS=()
PASSED_SCANS=0
FAILED_SCANS_COUNT=0
TOTAL_SCANS=0
CURRENT_SCAN=0

# Define all available scans with descriptions
declare -A SCANS
declare -A SCAN_ENABLED
declare -a SCAN_ORDER

# Reconnaissance scans
SCANS["dns_nslookup"]="DNS Lookup (nslookup)"
SCANS["dns_dig"]="DNS Lookup (dig)"
SCANS["dns_host_ns"]="DNS Nameservers (host -t ns)"
SCANS["dnsrecon"]="DNS Reconnaissance (dnsrecon)"
SCANS["whois"]="WHOIS Lookup"
SCANS["reverse_dns"]="Reverse DNS Lookup"

# Port scanning
SCANS["nmap_service"]="Nmap Service Detection"
SCANS["nmap_http_methods"]="Nmap HTTP Methods (NSE)"

# Web server analysis
SCANS["nikto"]="Nikto Web Server Scan"
SCANS["whatweb"]="WhatWeb Technology Detection"
SCANS["dirb_iis"]="Dirb IIS Vulnerability Scan"

# Header analysis
SCANS["http_headers"]="HTTP Headers Analysis"
SCANS["security_headers"]="Security Headers Check"

# SSL/TLS
SCANS["ssl_cert"]="SSL Certificate Analysis"
SCANS["ssl_scan"]="SSL Configuration Scan (sslscan)"
SCANS["tls_versions"]="TLS Version Support"

# Directory enumeration
SCANS["gobuster"]="Gobuster Directory Enumeration"

# Fuzzing
SCANS["wfuzz"]="WFuzz Parameter Fuzzing"

# Vulnerability checks
SCANS["dir_listing"]="Directory Listing Check"
SCANS["robots_txt"]="Robots.txt Discovery"
SCANS["sitemap"]="Sitemap.xml Discovery"
SCANS["git_exposure"]="Git Exposure Check"
SCANS["backup_files"]="Backup Files Check"

# Advanced checks
SCANS["cors_check"]="CORS Misconfiguration Check"
SCANS["api_discovery"]="API Endpoint Discovery"
SCANS["sensitive_data"]="Sensitive Data Exposure Check"

# Set scan order
SCAN_ORDER=(dns_nslookup dns_dig dns_host_ns dnsrecon whois reverse_dns nmap_service nmap_http_methods nikto whatweb dirb_iis http_headers security_headers ssl_cert ssl_scan tls_versions gobuster wfuzz dir_listing robots_txt sitemap git_exposure backup_files cors_check api_discovery sensitive_data)

# Initialize all scans as enabled
for scan in "${SCAN_ORDER[@]}"; do
    SCAN_ENABLED[$scan]=1
done

# Function to display help and disclaimer
show_help() {
    cat << EOF
========================================
WSTG Automated Security Scanner v2.0.0
(Interactive Menu - Selective Scanning)
========================================

IMPORTANT LEGAL NOTICE

THIS SCRIPT IS FOR AUTHORIZED SECURITY TESTING ONLY

DO NOT use this script to scan any systems without explicit,
written authorization from the system owner.

UNAUTHORIZED ACCESS IS ILLEGAL and may result in:
   - Criminal prosecution
   - Civil liability
   - Imprisonment
   - Substantial fines

EDUCATIONAL USE ONLY
   This tool is designed for learning and authorized penetration testing
   in controlled environments with proper authorization.

BEFORE RUNNING:
   1. Verify you have written permission to test the target
   2. Ensure the target is within your authorized scope
   3. Review your local laws regarding security testing
   4. Follow responsible disclosure practices

USAGE:
   $0 <target_url> [-o output_directory]

OPTIONS:
   <target_url>           Target URL (e.g., http://example.com)
   -o <output_directory>  Output directory for scan results (default: ./scans)
   -h, --help             Display this help message

EXAMPLES:
   $0 http://example.com
   $0 http://example.com -o ./my-scans
   $0 -h

MENU NAVIGATION:
   Up/Down arrows         Navigate menu items
   Left/Right arrows      Toggle scan on/off
   ENTER                  Start selected scans

OUTPUT STRUCTURE:
   recon/       - DNS, WHOIS results
   nmap/        - Nmap service detection and HTTP methods
   web/         - Web server analysis, directories, backups
   ssl/         - Certificate and TLS configuration
   headers/     - HTTP headers and security checks
   fuzzing/     - Fuzzing and parameter discovery
   logs/        - Detailed logs

========================================
EOF
    exit 0
}

# Check for help flag first
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        show_help
    fi
done

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Usage: $0 <target_url> -o <output_directory>${NC}"
    echo -e "${YELLOW}Example: $0 http://example.com -o ./scans${NC}"
    echo -e "${CYAN}Run '$0 -h' for full help and disclaimer${NC}"
    exit 1
fi

TARGET="$1"
OUTPUT_DIR="scans"  # Default output directory

# Parse optional arguments
while [[ $# -gt 1 ]]; do
    case "$2" in
        -o)
            OUTPUT_DIR="$3"
            shift 2
            ;;
        *)
            echo -e "${RED}Unknown option: $2${NC}"
            exit 1
            ;;
    esac
done

# Cleanup function to kill all child processes on exit
cleanup() {
    echo -e "\n${YELLOW}[!] Interrupt received, killing all background scans...${NC}"
    jobs -p | xargs -r kill -9 2>/dev/null
    wait 2>/dev/null
    echo -e "${RED}[!] Scan cancelled${NC}"
    exit 130
}

# Set trap to catch Ctrl+C (SIGINT) and termination (SIGTERM)
trap cleanup SIGINT SIGTERM

# Function to show spinner
show_spinner() {
    printf "\r${CYAN}[${SPINNER[$SPINNER_IDX]}]${NC}" >&1
    SPINNER_IDX=$(( (SPINNER_IDX + 1) % ${#SPINNER[@]} ))
}

# Function to show progress bar
show_progress_bar() {
    local current=$1
    local total=$2
    local percent=$((current * 100 / total))
    local filled=$((percent / 5))

    printf "[${BLUE}"
    printf "%${filled}s" | tr ' ' '█'
    printf "%$((20 - filled))s${NC}] ${CYAN}${current}/${total}${NC} "
}

# Function to extract error details from stderr
extract_error() {
    local error_output="$1"

    # Look for common error patterns
    if echo "$error_output" | grep -qi "error"; then
        echo "$error_output" | grep -i "error" | head -1 | cut -c1-80
    elif echo "$error_output" | grep -qi "failed\|fail"; then
        echo "$error_output" | grep -i "fail" | head -1 | cut -c1-80
    elif echo "$error_output" | grep -qi "refused\|connection"; then
        echo "$error_output" | grep -i "refused\|connection" | head -1 | cut -c1-80
    elif echo "$error_output" | grep -qi "timeout\|timed out"; then
        echo "Timeout - target not responding"
    elif echo "$error_output" | grep -qi "not found"; then
        echo "$error_output" | grep -i "not found" | head -1 | cut -c1-80
    elif echo "$error_output" | grep -qi "permission denied"; then
        echo "Permission denied - check tool permissions"
    elif [ -n "$error_output" ]; then
        echo "$error_output" | head -1 | cut -c1-80
    else
        echo "Unknown error"
    fi
}

# Function to log errors with detailed messages
log_error() {
    local scan_name="$1"
    local error_msg="$2"
    FAILED_SCANS+=("$scan_name: $error_msg")
    ((FAILED_SCANS_COUNT++))
    printf "\r\033[K"  # Clear line completely
    echo -e "${RED}✗ FAILED: $scan_name${NC}"
    echo -e "  ${RED}└─ $error_msg${NC}"
}

# Function to log success
log_success() {
    local scan_name="$1"
    ((PASSED_SCANS++))
    printf "\r"
    echo -e "${GREEN}✓ $scan_name${NC}"
    ((CURRENT_SCAN++))
    show_progress_bar $CURRENT_SCAN $TOTAL_SCANS
    echo ""
}

# Function to run scan with error handling, spinner, and progress
run_scan() {
    local scan_name="$1"
    local command="$2"
    local output_file="$3"
    local temp_error_file=$(mktemp)

    show_progress_bar $CURRENT_SCAN $TOTAL_SCANS
    printf " ${YELLOW}⟳ $scan_name${NC} "

    eval "$command" > "$output_file" 2>"$temp_error_file" &
    local cmd_pid=$!

    while kill -0 $cmd_pid 2>/dev/null; do
        show_spinner
        sleep 0.1
    done

    wait $cmd_pid
    local exit_code=$?

    printf "\r"

    local has_output=false
    local has_error=false
    local error_msg=""

    [ -s "$output_file" ] && has_output=true
    [ -s "$temp_error_file" ] && has_error=true

    if [ "$has_output" = true ]; then
        log_success "$scan_name"
    elif [ "$has_error" = true ]; then
        error_msg=$(extract_error "$(cat "$temp_error_file")")
        log_error "$scan_name" "$error_msg"
    elif [ $exit_code -eq 0 ]; then
        log_success "$scan_name"
    else
        log_error "$scan_name" "Tool produced no output (exit code $exit_code)"
    fi
    rm -f "$temp_error_file"
}

# Function to check if tool exists
check_tool() {
    local tool="$1"
    if ! command -v "$tool" &> /dev/null; then
        return 1
    fi
    return 0
}

# Function to display interactive menu
display_menu() {
    local current_idx=$1
    clear
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}WSTG Automated Scanner v${VERSION}${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    echo -e "${MAGENTA}SELECT SCANS TO RUN${NC}"
    echo ""

    local idx=0
    for scan in "${SCAN_ORDER[@]}"; do
        local enabled=${SCAN_ENABLED[$scan]}
        local checkbox="[ ]"
        local color="$RED"

        if [ $enabled -eq 1 ]; then
            checkbox="[✓]"
            color="$GREEN"
        fi

        # Highlight current selection
        if [ $idx -eq $current_idx ]; then
            printf "${CYAN}→ ${color}%s %-40s${NC}\n" "$checkbox" "${SCANS[$scan]}"
        else
            printf "  ${color}%s %-40s${NC}\n" "$checkbox" "${SCANS[$scan]}"
        fi
        ((idx++))
    done

    echo ""
    echo -e "${CYAN}Navigation:${NC}"
    echo -e "  ${CYAN}↑ ↓${NC} - Navigate up/down"
    echo -e "  ${CYAN}← →${NC} - Toggle scan on/off"
    echo -e "  ${CYAN}Enter${NC} - Start scans with selected options"
    echo -e "  ${CYAN}q${NC} - Quit"
    echo ""

    # Count enabled scans
    local enabled_count=0
    for scan in "${SCAN_ORDER[@]}"; do
        [ ${SCAN_ENABLED[$scan]} -eq 1 ] && ((enabled_count++))
    done

    echo -e "${YELLOW}Scans enabled: $enabled_count / ${#SCAN_ORDER[@]}${NC}"
}

# Function to handle menu input with arrow keys
handle_menu_input() {
    local current_idx=0

    while true; do
        display_menu $current_idx

        # Read first character
        IFS= read -rsn1 key

        if [ "$key" = $'\x1b' ]; then
            # Escape sequence - read next 2 characters for arrow keys
            IFS= read -rsn2 arrow_key

            case "$arrow_key" in
                '[A') # Up arrow
                    if [ $current_idx -gt 0 ]; then
                        ((current_idx--))
                    fi
                    ;;
                '[B') # Down arrow
                    if [ $current_idx -lt $((${#SCAN_ORDER[@]} - 1)) ]; then
                        ((current_idx++))
                    fi
                    ;;
                '[C') # Right arrow - toggle ON
                    local scan=${SCAN_ORDER[$current_idx]}
                    SCAN_ENABLED[$scan]=1
                    ;;
                '[D') # Left arrow - toggle OFF
                    local scan=${SCAN_ORDER[$current_idx]}
                    SCAN_ENABLED[$scan]=0
                    ;;
            esac
        elif [ "$key" = "q" ] || [ "$key" = "Q" ]; then
            # Quit
            echo -e "${RED}Exiting...${NC}"
            exit 0
        elif [ "$key" = "" ]; then
            # Empty string means Enter was pressed (newline)
            local enabled_count=0
            for scan in "${SCAN_ORDER[@]}"; do
                [ ${SCAN_ENABLED[$scan]} -eq 1 ] && ((enabled_count++))
            done

            if [ $enabled_count -gt 0 ]; then
                return 0
            else
                echo -e "${RED}Please enable at least one scan!${NC}"
                sleep 2
            fi
        fi
    done
}

# Main script starts here
# Extract host and port from URL
HOST=$(echo "$TARGET" | sed -E 's|https?://||' | cut -d'/' -f1 | cut -d':' -f1)
PORT=$(echo "$TARGET" | grep -oP '(?<=:)\d+' || echo "80")
SCHEME=$(echo "$TARGET" | grep -oP 'https?(?=://)')

if [ "$SCHEME" == "https" ]; then
    PORT=443
fi

# Show legal notice first
echo -e "${RED}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║      ⚠️  AUTHORIZED TESTING ONLY - LEGAL NOTICE  ⚠️     ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}This tool is designed for authorized security testing only.${NC}"
echo -e "${YELLOW}Unauthorized access to computer systems is ILLEGAL.${NC}"
echo ""
echo -e "Target: ${GREEN}$TARGET${NC}"
echo ""
echo -n "Do you have explicit authorization to test this target? (yes/no): "
read -r auth_check

if [[ ! "$auth_check" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${RED}Exiting - authorization required${NC}"
    exit 1
fi

# Display scan selection menu
handle_menu_input

echo -e "\n${BLUE}============================================${NC}"
echo -e "${BLUE}WSTG Automated Scanner v${VERSION}${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "Target: ${GREEN}$TARGET${NC}"
echo -e "Host: ${GREEN}$HOST${NC}"
echo -e "Port: ${GREEN}$PORT${NC}"
echo -e "Output: ${GREEN}$OUTPUT_DIR${NC}"
echo -e "${BLUE}============================================${NC}\n"

# Create output directory structure
mkdir -p "$OUTPUT_DIR"/{recon,web,ssl,headers,fuzzing,nmap,logs}

# Check for required tools
echo -e "${YELLOW}[*] Checking for required tools...${NC}\n"
CRITICAL_TOOLS=(curl nmap)
OPTIONAL_TOOLS=(nikto gobuster wfuzz dig dnsrecon whois host openssl sslscan whatweb dirb)
MISSING_CRITICAL=0

for tool in "${CRITICAL_TOOLS[@]}"; do
    if check_tool "$tool"; then
        echo -e "${GREEN}✓ $tool${NC}"
    else
        MISSING_CRITICAL=1
    fi
done

if [ $MISSING_CRITICAL -eq 1 ]; then
    echo -e "${RED}\n✗ Missing critical tools. Cannot continue.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Optional tools:${NC}"
for tool in "${OPTIONAL_TOOLS[@]}"; do
    if check_tool "$tool"; then
        echo -e "${GREEN}✓ $tool${NC}"
    else
        echo -e "${RED}✗ $tool (some scans will be skipped)${NC}"
    fi
done

# COUNT TOTAL SCANS based on user selection
TOTAL_SCANS=0
for scan in "${SCAN_ORDER[@]}"; do
    if [ ${SCAN_ENABLED[$scan]} -eq 1 ]; then
        ((TOTAL_SCANS++))
    fi
done

echo -e "\n${YELLOW}[*] Starting WSTG automated scans...${NC}"
echo -e "${CYAN}Selected scans to run: ${TOTAL_SCANS}${NC}\n"

# ===== RECONNAISSANCE =====
if [ ${SCAN_ENABLED[dns_nslookup]} -eq 1 ] && check_tool nslookup; then
    echo -e "${YELLOW}[*] Phase 1: Reconnaissance${NC}"
    run_scan "DNS Lookup (nslookup)" "nslookup $HOST" "$OUTPUT_DIR/recon/01-dns-lookup.txt"
fi

if [ ${SCAN_ENABLED[dns_dig]} -eq 1 ] && check_tool dig; then
    run_scan "DNS Lookup (dig)" "dig $HOST +short" "$OUTPUT_DIR/recon/02-dig-short.txt"
fi

if [ ${SCAN_ENABLED[dns_host_ns]} -eq 1 ] && check_tool host; then
    run_scan "DNS Nameservers (host -t ns)" "host -t ns $HOST" "$OUTPUT_DIR/recon/03-dns-nameservers.txt"
fi

if [ ${SCAN_ENABLED[dnsrecon]} -eq 1 ] && check_tool dnsrecon; then
    run_scan "DNS Reconnaissance (dnsrecon)" "dnsrecon -d $HOST 2>&1" "$OUTPUT_DIR/recon/04-dnsrecon.txt"
fi

if [ ${SCAN_ENABLED[whois]} -eq 1 ] && check_tool whois; then
    run_scan "WHOIS Lookup" "whois $HOST" "$OUTPUT_DIR/recon/05-whois.txt"
fi

if [ ${SCAN_ENABLED[reverse_dns]} -eq 1 ] && check_tool host; then
    run_scan "Reverse DNS" "host $HOST" "$OUTPUT_DIR/recon/04-reverse-dns.txt"
fi

# ===== PORT SCANNING =====
if [ ${SCAN_ENABLED[nmap_service]} -eq 1 ] || [ ${SCAN_ENABLED[nmap_http_methods]} -eq 1 ]; then
    echo -e "${YELLOW}[*] Phase 2: Port Scanning${NC}"
fi

if [ ${SCAN_ENABLED[nmap_service]} -eq 1 ] && check_tool nmap; then
    run_scan "Nmap Service Detection" "nmap -sV -Pn -oA $OUTPUT_DIR/nmap/01-nmap-service $HOST 2>&1 | tee $OUTPUT_DIR/nmap/01-nmap-service.txt" "$OUTPUT_DIR/nmap/01-nmap-service.txt"
fi

if [ ${SCAN_ENABLED[nmap_http_methods]} -eq 1 ] && check_tool nmap; then
    run_scan "Nmap HTTP Methods" "nmap -sV -Pn --script http-methods -oA $OUTPUT_DIR/nmap/02-nmap-http-methods $HOST 2>&1 | tee $OUTPUT_DIR/nmap/02-nmap-http-methods.txt" "$OUTPUT_DIR/nmap/02-nmap-http-methods.txt"
fi

# ===== WEB SERVER SCANNING =====
if [ ${SCAN_ENABLED[nikto]} -eq 1 ] || [ ${SCAN_ENABLED[whatweb]} -eq 1 ] || [ ${SCAN_ENABLED[dirb_iis]} -eq 1 ]; then
    echo -e "${YELLOW}[*] Phase 3: Web Server Analysis${NC}"
fi

if [ ${SCAN_ENABLED[nikto]} -eq 1 ] && check_tool nikto; then
    run_scan "Nikto scan" "nikto -h $TARGET" "$OUTPUT_DIR/web/01-nikto-scan.txt"
fi

if [ ${SCAN_ENABLED[whatweb]} -eq 1 ] && check_tool whatweb; then
    run_scan "WhatWeb scan" "whatweb -v $TARGET" "$OUTPUT_DIR/web/02-whatweb-scan.txt"
fi

if [ ${SCAN_ENABLED[dirb_iis]} -eq 1 ] && check_tool dirb; then
    run_scan "Dirb IIS scan" "dirb $TARGET /usr/share/wordlists/wfuzz/vulns/iis.txt -o $OUTPUT_DIR/web/03-dirb-iis.txt 2>&1" "$OUTPUT_DIR/web/03-dirb-iis.txt"
fi

# ===== HEADER ANALYSIS =====
if [ ${SCAN_ENABLED[http_headers]} -eq 1 ] || [ ${SCAN_ENABLED[security_headers]} -eq 1 ]; then
    echo -e "${YELLOW}[*] Phase 4: Header & Security Configuration${NC}"
fi

if [ ${SCAN_ENABLED[http_headers]} -eq 1 ] && check_tool curl; then
    run_scan "HTTP headers" "curl -I -H 'User-Agent: Mozilla/5.0' $TARGET" "$OUTPUT_DIR/headers/01-http-headers.txt"
fi

if [ ${SCAN_ENABLED[security_headers]} -eq 1 ] && check_tool curl; then
    run_scan "Security headers check" "{
        echo '=== Security Header Checks ==='; echo '';
        echo 'Testing: Strict-Transport-Security (HSTS)';
        curl -I '$TARGET' 2>&1 | grep -i 'strict-transport|hsts' || echo '❌ HSTS not found';
        echo ''; echo 'Testing: Content-Security-Policy (CSP)';
        curl -I '$TARGET' 2>&1 | grep -i 'content-security-policy' || echo '❌ CSP not found';
        echo ''; echo 'Testing: X-Content-Type-Options';
        curl -I '$TARGET' 2>&1 | grep -i 'x-content-type-options' || echo '❌ X-Content-Type-Options not found';
        echo ''; echo 'Testing: X-Frame-Options';
        curl -I '$TARGET' 2>&1 | grep -i 'x-frame-options' || echo '❌ X-Frame-Options not found'; echo '';
    }" "$OUTPUT_DIR/headers/02-security-headers-check.txt"
fi

# ===== SSL/TLS ANALYSIS =====
if [ ${SCAN_ENABLED[ssl_cert]} -eq 1 ] || [ ${SCAN_ENABLED[tls_versions]} -eq 1 ]; then
    if [ "$SCHEME" == "https" ] || [ "$PORT" == "443" ]; then
        echo -e "${YELLOW}[*] Phase 5: SSL/TLS Configuration${NC}"
    fi
fi

if [ ${SCAN_ENABLED[ssl_cert]} -eq 1 ] && check_tool openssl && ([ "$SCHEME" == "https" ] || [ "$PORT" == "443" ]); then
    run_scan "SSL certificate info" "openssl s_client -connect $HOST:$PORT -servername $HOST < /dev/null 2>&1 | openssl x509 -text -noout" "$OUTPUT_DIR/ssl/01-cert-info.txt"
fi

if [ ${SCAN_ENABLED[ssl_scan]} -eq 1 ] && check_tool sslscan && ([ "$SCHEME" == "https" ] || [ "$PORT" == "443" ]); then
    run_scan "SSL configuration scan (sslscan)" "sslscan $HOST:$PORT 2>&1" "$OUTPUT_DIR/ssl/02-sslscan.txt"
fi

if [ ${SCAN_ENABLED[tls_versions]} -eq 1 ] && check_tool curl && ([ "$SCHEME" == "https" ] || [ "$PORT" == "443" ]); then
    run_scan "TLS v1.0 support" "curl -I --tlsv1.0 $TARGET" "$OUTPUT_DIR/ssl/03-tls-v1.0.txt"
    run_scan "TLS v1.1 support" "curl -I --tlsv1.1 $TARGET" "$OUTPUT_DIR/ssl/04-tls-v1.1.txt"
    run_scan "TLS v1.2 support" "curl -I --tlsv1.2 $TARGET" "$OUTPUT_DIR/ssl/05-tls-v1.2.txt"
fi

# ===== DIRECTORY ENUMERATION =====
if [ ${SCAN_ENABLED[gobuster]} -eq 1 ] && check_tool gobuster; then
    echo -e "${YELLOW}[*] Phase 6: Directory Enumeration${NC}"
    run_scan "Gobuster directory scan" "gobuster dir -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -u $TARGET -k -s "204,301,302,307,401,403" -b "" " "$OUTPUT_DIR/web/04-gobuster-dirs.txt"
fi

# ===== PARAMETER FUZZING =====
if [ ${SCAN_ENABLED[wfuzz]} -eq 1 ] && check_tool wfuzz; then
    echo -e "${YELLOW}[*] Phase 7: Parameter Fuzzing${NC}"
    run_scan "Parameter fuzzing (GET)" "wfuzz -c -z file,/usr/share/wordlists/wfuzz/general/common.txt -u $TARGET?FUZZ=test --hc 404" "$OUTPUT_DIR/fuzzing/01-get-params.txt"
fi

# ===== VULNERABILITY CHECKS =====
echo -e "${YELLOW}[*] Phase 8: Common Vulnerability Patterns${NC}"

# ===== DIRECTORY & FILE CHECKS =====
if [ ${SCAN_ENABLED[dir_listing]} -eq 1 ] || [ ${SCAN_ENABLED[robots_txt]} -eq 1 ] || [ ${SCAN_ENABLED[sitemap]} -eq 1 ] || [ ${SCAN_ENABLED[git_exposure]} -eq 1 ] || [ ${SCAN_ENABLED[backup_files]} -eq 1 ]; then
    true  # Phase already declared above
fi

if [ ${SCAN_ENABLED[dir_listing]} -eq 1 ] && check_tool curl; then
    run_scan "Directory listing check" "curl -s $TARGET/ > $OUTPUT_DIR/web/05-dir-listing-check.txt 2>&1 && grep -i 'index of|directory listing' $OUTPUT_DIR/web/05-dir-listing-check.txt > /dev/null && echo 'VULNERABLE: Directory listing detected' || echo 'OK: No directory listing'" "$OUTPUT_DIR/web/05-dir-listing-check.txt"
fi

if [ ${SCAN_ENABLED[robots_txt]} -eq 1 ] && check_tool curl; then
    run_scan "robots.txt discovery" "curl -s $TARGET/robots.txt" "$OUTPUT_DIR/web/06-robots.txt"
fi

if [ ${SCAN_ENABLED[sitemap]} -eq 1 ] && check_tool curl; then
    run_scan "sitemap.xml discovery" "curl -s $TARGET/sitemap.xml" "$OUTPUT_DIR/web/07-sitemap.xml"
fi

if [ ${SCAN_ENABLED[git_exposure]} -eq 1 ] && check_tool curl; then
    run_scan ".git exposure check" "curl -s $TARGET/.git/config" "$OUTPUT_DIR/web/08-git-config.txt"
fi

if [ ${SCAN_ENABLED[backup_files]} -eq 1 ] && check_tool curl; then
    for ext in .bak .backup .old .swp .tmp; do
        run_scan "Backup check (index.php$ext)" "curl -s $TARGET/index.php$ext" "$OUTPUT_DIR/web/09-backup-$ext.txt"
    done
fi

# ===== ADVANCED CHECKS =====
if [ ${SCAN_ENABLED[cors_check]} -eq 1 ] || [ ${SCAN_ENABLED[api_discovery]} -eq 1 ] || [ ${SCAN_ENABLED[sensitive_data]} -eq 1 ]; then
    echo -e "${YELLOW}[*] Phase 9: Advanced Security Checks${NC}"
fi

if [ ${SCAN_ENABLED[cors_check]} -eq 1 ] && check_tool curl; then
    run_scan "CORS misconfiguration check" "{
        echo '=== CORS Configuration Check ==='; echo '';
        echo 'Testing: Access-Control-Allow-Origin';
        curl -sI '$TARGET' -H 'Origin: http://attacker.com' 2>&1 | grep -i 'access-control-allow' || echo 'CORS headers not found';
        echo ''; echo 'Testing: Access-Control-Allow-Credentials';
        curl -sI '$TARGET' 2>&1 | grep -i 'access-control-allow-credentials' || echo 'No allow-credentials header';
    }" "$OUTPUT_DIR/headers/05-cors-check.txt"
fi

if [ ${SCAN_ENABLED[api_discovery]} -eq 1 ] && check_tool curl; then
    run_scan "API endpoint discovery" "{
        echo '=== API Endpoint Discovery ==='; echo '';
        for path in /api /api/v1 /api/v2 /graphql /swagger /openapi /docs /api-docs /swagger.json /openapi.json; do
            echo \"Checking \$path:\";
            curl -s -I \"$TARGET\$path\" 2>&1 | grep -E '(200|301|302|401|403)' | head -1 || echo '  Not found';
        done
    }" "$OUTPUT_DIR/web/10-api-discovery.txt"
fi

if [ ${SCAN_ENABLED[sensitive_data]} -eq 1 ] && check_tool curl; then
    run_scan "Sensitive data exposure check" "{
        echo '=== Sensitive Data Exposure Check ==='; echo '';
        echo 'Scanning for exposed secrets (API keys, tokens, credentials)...'; echo '';
        curl -s '$TARGET' 2>&1 | grep -iE '(api[_-]?key|secret|password|token|auth|apikey|access[_-]?token|private[_-]?key|aws_access_key)' | head -20 || echo 'No obvious sensitive data found in response';
    }" "$OUTPUT_DIR/headers/06-sensitive-data.txt"
fi

# ===== SUMMARY =====
echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}[✓] Scan Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo -e "Results saved to: ${BLUE}$OUTPUT_DIR${NC}\n"

# Print scan summary
echo -e "${BLUE}Scan Summary:${NC}"
echo -e "  ${GREEN}Passed:${NC} $PASSED_SCANS"
echo -e "  ${RED}Failed:${NC} $FAILED_SCANS_COUNT"
echo -e "  ${CYAN}Total:${NC} $((PASSED_SCANS + FAILED_SCANS_COUNT))\n"

# Print failed scans if any
if [ ${#FAILED_SCANS[@]} -gt 0 ]; then
    echo -e "${RED}Failed Scans:${NC}"
    for scan in "${FAILED_SCANS[@]}"; do
        echo -e "  ${RED}✗${NC} $scan"
    done
    echo ""
fi

echo -e "${YELLOW}Output Structure:${NC}"
echo -e "  ${BLUE}recon/${NC}       - DNS, WHOIS results"
echo -e "  ${BLUE}nmap/${NC}        - Nmap service detection and HTTP methods (all formats)"
echo -e "  ${BLUE}web/${NC}         - Web server (Nikto, WhatWeb, Dirb), directories, backups"
echo -e "  ${BLUE}ssl/${NC}         - Certificate and TLS configuration"
echo -e "  ${BLUE}headers/${NC}     - HTTP headers and security checks"
echo -e "  ${BLUE}fuzzing/${NC}     - Fuzzing and parameter discovery"
echo -e "  ${BLUE}logs/${NC}        - Detailed logs\n"

echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Review each file for vulnerabilities"
echo -e "  2. Cross-reference findings with WSTG playbook"
echo -e "  3. Manual testing for business logic and context-specific vulns"
echo -e "  4. Run Burp Suite for interactive testing\n"

# Create a summary report
cat > "$OUTPUT_DIR/SCAN-SUMMARY.txt" << EOF
WSTG Automated Scan Report (v${VERSION})
==========================

Target: $TARGET
Host: $HOST
Port: $PORT
Scan Date: $(date)
Version: $VERSION

SCAN STATISTICS:
Total Scans Enabled: $TOTAL_SCANS
Scans Passed: $PASSED_SCANS
Scans Failed: $FAILED_SCANS_COUNT
Success Rate: $([ $((PASSED_SCANS + FAILED_SCANS_COUNT)) -eq 0 ] && echo "0" || echo "$((PASSED_SCANS * 100 / (PASSED_SCANS + FAILED_SCANS_COUNT)))")%

SCANS EXECUTED:
EOF

for scan in "${SCAN_ORDER[@]}"; do
    if [ ${SCAN_ENABLED[$scan]} -eq 1 ]; then
        echo "✓ ${SCANS[$scan]}" >> "$OUTPUT_DIR/SCAN-SUMMARY.txt"
    else
        echo "○ ${SCANS[$scan]} (skipped)" >> "$OUTPUT_DIR/SCAN-SUMMARY.txt"
    fi
done

cat >> "$OUTPUT_DIR/SCAN-SUMMARY.txt" << EOF

FILES GENERATED:
$(find "$OUTPUT_DIR" -type f ! -name "SCAN-SUMMARY.txt" | sort | sed 's|^|  - |')

REQUIRES MANUAL TESTING:
- Business logic exploitation
- Authentication bypass (context-specific)
- Authorization flaws
- CSRF exploitation
- Client-side vulnerabilities
- Cryptography analysis (detailed)

RECOMMENDATION:
Use these automated results as a baseline. Follow up with:
1. Burp Suite Pro scanning
2. Manual exploitation of discovered findings
3. Business logic testing
4. Source code review (if available)

NOTES:
- Empty files may indicate tool not installed or target not vulnerable
- Check tool availability at start of report
- Review failed scans for missing dependencies

Generated with WSTG Automated Scanner v${VERSION}
EOF

echo -e "${BLUE}Summary report: ${YELLOW}$OUTPUT_DIR/SCAN-SUMMARY.txt${NC}\n"
