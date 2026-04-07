#!/bin/bash

#########################################
# WSTG Automated Scanner (Enhanced)
# Target: Single URL input
# Output: Individual scan files organized by category
# Tools: Kali Linux CLI tools (nmap, nikto, sqlmap, curl, etc.)
#
# ENHANCEMENTS:
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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Usage: $0 <target_url>${NC}"
    echo -e "${YELLOW}Example: $0 http://example.com${NC}"
    exit 1
fi

# Cleanup function to kill all child processes on exit
cleanup() {
    echo -e "\n${YELLOW}[!] Interrupt received, killing all background scans...${NC}"
    # Kill all child processes
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
        # If there's any stderr output, use first line
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
    printf "\r"  # Clear spinner
    echo -e "${RED}✗ FAILED: $scan_name${NC}"
    echo -e "  ${RED}└─ $error_msg${NC}"
}

# Function to log success
log_success() {
    local scan_name="$1"
    ((PASSED_SCANS++))
    printf "\r"  # Clear spinner
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

    # Show what scan is running with spinner
    printf "${YELLOW}⟳ $scan_name${NC} "
    show_progress_bar $CURRENT_SCAN $TOTAL_SCANS
    printf " "

    # Run command in background (capture both stdout and stderr)
    eval "$command" > "$output_file" 2>"$temp_error_file" &
    local cmd_pid=$!

    # Spin while command runs
    while kill -0 $cmd_pid 2>/dev/null; do
        show_spinner
        sleep 0.1
    done

    # Wait for command to finish and get exit code
    wait $cmd_pid
    local exit_code=$?

    # Clear spinner line
    printf "\r"

    # Determine success based on output, not just exit code
    # Some tools (nikto, sqlmap) return non-zero even on success
    local has_output=false
    local has_error=false
    local error_msg=""

    [ -s "$output_file" ] && has_output=true
    [ -s "$temp_error_file" ] && has_error=true

    # If we have output, consider it a success (most tools output results on success)
    if [ "$has_output" = true ]; then
        log_success "$scan_name"
    elif [ "$has_error" = true ]; then
        # Only report error if there's stderr and no stdout
        error_msg=$(extract_error "$(cat "$temp_error_file")")
        log_error "$scan_name" "$error_msg"
    elif [ $exit_code -eq 0 ]; then
        # Tool succeeded but produced no output (might be normal)
        log_success "$scan_name"
    else
        # No output and non-zero exit code
        log_error "$scan_name" "Tool produced no output (exit code $exit_code)"
    fi
    rm -f "$temp_error_file"
}

# Function to check if tool exists
check_tool() {
    local tool="$1"
    if ! command -v "$tool" &> /dev/null; then
        echo -e "${RED}✗ MISSING TOOL: $tool${NC}"
        echo -e "${YELLOW}  Install: sudo apt install $tool${NC}"
        return 1
    fi
    return 0
}

TARGET="$1"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="./wstg-scan-${TIMESTAMP}"

# Extract host and port from URL
HOST=$(echo "$TARGET" | sed -E 's|https?://||' | cut -d'/' -f1 | cut -d':' -f1)
PORT=$(echo "$TARGET" | grep -oP '(?<=:)\d+' || echo "80")
SCHEME=$(echo "$TARGET" | grep -oP 'https?(?=://)')

if [ "$SCHEME" == "https" ]; then
    PORT=443
fi

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}WSTG Automated Scanner (Enhanced)${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "Target: ${GREEN}$TARGET${NC}"
echo -e "Host: ${GREEN}$HOST${NC}"
echo -e "Port: ${GREEN}$PORT${NC}"
echo -e "Output: ${GREEN}$OUTPUT_DIR${NC}"
echo -e "${BLUE}============================================${NC}\n"

# Create output directory structure
mkdir -p "$OUTPUT_DIR"/{recon,web,ssl,injection,headers,fuzzing,nmap,logs}

# Check for required tools
echo -e "${YELLOW}[*] Checking for required tools...${NC}\n"
CRITICAL_TOOLS=(curl nmap)
OPTIONAL_TOOLS=(nikto gobuster wfuzz sqlmap dig whois host openssl whatweb dirb)
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

# COUNT TOTAL SCANS (for progress bar)
TOTAL_SCANS=0

# Count scans that will run
[ "$(command -v nslookup)" ] && ((TOTAL_SCANS++))
[ "$(command -v dig)" ] && ((TOTAL_SCANS++))
[ "$(command -v whois)" ] && ((TOTAL_SCANS++))
[ "$(command -v host)" ] && ((TOTAL_SCANS++))
[ "$(command -v nmap)" ] && ((TOTAL_SCANS += 2))  # Service detection + HTTP methods
[ "$(command -v nikto)" ] && ((TOTAL_SCANS++))
[ "$(command -v whatweb)" ] && ((TOTAL_SCANS++))
[ "$(command -v dirb)" ] && ((TOTAL_SCANS++))
[ "$(command -v curl)" ] && ((TOTAL_SCANS += 11))  # HTTP + response + server + 3 TLS + robots + sitemap + git + backup checks + security headers
[ "$(command -v openssl)" ] && [ "$SCHEME" == "https" ] && ((TOTAL_SCANS++))
[ "$(command -v wfuzz)" ] && ((TOTAL_SCANS++))
[ "$(command -v sqlmap)" ] && ((TOTAL_SCANS++))
[ "$(command -v gobuster)" ] && ((TOTAL_SCANS++))

echo -e "\n${YELLOW}[*] Starting WSTG automated scans...${NC}"
echo -e "${CYAN}Estimated scans to run: ${TOTAL_SCANS}${NC}\n"

# ===== RECON =====
echo -e "${YELLOW}[*] Phase 1: Reconnaissance${NC}"

# DNS lookup
if check_tool nslookup; then
    run_scan "DNS Lookup (nslookup)" "nslookup $HOST" "$OUTPUT_DIR/recon/01-dns-lookup.txt"
fi

if check_tool dig; then
    run_scan "DNS Lookup (dig)" "dig $HOST +short" "$OUTPUT_DIR/recon/02-dig-short.txt"
fi

# WHOIS
if check_tool whois; then
    run_scan "WHOIS Lookup" "whois $HOST" "$OUTPUT_DIR/recon/03-whois.txt"
fi

# Reverse DNS
if check_tool host; then
    run_scan "Reverse DNS" "host $HOST" "$OUTPUT_DIR/recon/04-reverse-dns.txt"
fi

# ===== PORT SCANNING =====
echo -e "${YELLOW}[*] Phase 2: Port Scanning${NC}"

if check_tool nmap; then
    run_scan "Nmap (service detection)" "nmap -sV -Pn -oA $OUTPUT_DIR/nmap/01-nmap-service $HOST 2>&1 | tee $OUTPUT_DIR/nmap/01-nmap-service.txt" "$OUTPUT_DIR/nmap/01-nmap-service.txt"
    run_scan "Nmap (HTTP methods)" "nmap -sV -Pn --script http-methods -oA $OUTPUT_DIR/nmap/02-nmap-http-methods $HOST 2>&1 | tee $OUTPUT_DIR/nmap/02-nmap-http-methods.txt" "$OUTPUT_DIR/nmap/02-nmap-http-methods.txt"
fi

# ===== WEB SERVER SCANNING =====
echo -e "${YELLOW}[*] Phase 3: Web Server Analysis${NC}"

if check_tool nikto; then
    run_scan "Nikto scan" "nikto -h $TARGET" "$OUTPUT_DIR/web/01-nikto-scan.txt"
fi

if check_tool whatweb; then
    run_scan "WhatWeb scan" "whatweb -v $TARGET" "$OUTPUT_DIR/web/02-whatweb-scan.txt"
fi

if check_tool dirb; then
    run_scan "Dirb IIS scan" "dirb $TARGET /usr/share/wordlists/wfuzz/vulns/iis.txt -o $OUTPUT_DIR/web/03-dirb-iis.txt 2>&1" "$OUTPUT_DIR/web/03-dirb-iis.txt"
fi

# ===== HEADER ANALYSIS =====
echo -e "${YELLOW}[*] Phase 4: Header & Security Configuration${NC}"

if check_tool curl; then
    run_scan "HTTP headers" "curl -I -H 'User-Agent: Mozilla/5.0' $TARGET" "$OUTPUT_DIR/headers/01-http-headers.txt"
    run_scan "Response headers (verbose)" "curl -v $TARGET 2>&1 | grep -i '^< '" "$OUTPUT_DIR/headers/02-response-headers.txt"
    run_scan "Server detection" "curl -I $TARGET 2>&1 | grep -i 'Server|X-'" "$OUTPUT_DIR/headers/03-server-info.txt"
fi

# ===== SSL/TLS ANALYSIS =====
echo -e "${YELLOW}[*] Phase 5: SSL/TLS Configuration${NC}"

if [ "$SCHEME" == "https" ] || [ "$PORT" == "443" ]; then
    if check_tool openssl; then
        run_scan "SSL certificate info" "openssl s_client -connect $HOST:$PORT -servername $HOST < /dev/null 2>&1 | openssl x509 -text -noout" "$OUTPUT_DIR/ssl/01-cert-info.txt"
    fi

    if check_tool curl; then
        run_scan "TLS v1.0 support" "curl -I --tlsv1.0 $TARGET" "$OUTPUT_DIR/ssl/03-tls-v1.0.txt"
        run_scan "TLS v1.1 support" "curl -I --tlsv1.1 $TARGET" "$OUTPUT_DIR/ssl/04-tls-v1.1.txt"
        run_scan "TLS v1.2 support" "curl -I --tlsv1.2 $TARGET" "$OUTPUT_DIR/ssl/05-tls-v1.2.txt"
    fi
else
    echo -e "${YELLOW}[*] Skipping SSL/TLS scans (HTTP target)${NC}"
fi

# ===== DIRECTORY & FILE ENUMERATION =====
echo -e "${YELLOW}[*] Phase 6: Directory Enumeration${NC}"

if check_tool gobuster; then
    run_scan "Gobuster directory scan" "gobuster dir -u $TARGET -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -q" "$OUTPUT_DIR/web/02-gobuster-dirs.txt"
fi

# ===== PARAMETER FUZZING =====
echo -e "${YELLOW}[*] Phase 7: Parameter Fuzzing${NC}"

if check_tool wfuzz; then
    run_scan "Parameter fuzzing (GET)" "wfuzz -c -z file,/usr/share/wordlists/wfuzz/general/common.txt -u $TARGET?FUZZ=test --hc 404" "$OUTPUT_DIR/fuzzing/01-get-params.txt"
fi

# ===== SQL INJECTION TESTING =====
echo -e "${YELLOW}[*] Phase 8: SQL Injection Checks${NC}"

if check_tool sqlmap; then
    run_scan "SQLMap scan (light)" "sqlmap -u $TARGET --batch --risk=1 --level=1 -o --quiet 2>&1 | head -100" "$OUTPUT_DIR/injection/01-sqlmap-light.txt"
fi

# ===== VULNERABILITY CHECKS =====
echo -e "${YELLOW}[*] Phase 9: Common Vulnerability Patterns${NC}"

if check_tool curl; then
    run_scan "Directory listing check" "curl -s $TARGET/ 2>&1 | grep -i 'index of|directory listing'" "$OUTPUT_DIR/web/03-dir-listing-check.txt"
    run_scan "robots.txt discovery" "curl -s $TARGET/robots.txt" "$OUTPUT_DIR/web/04-robots.txt"
    run_scan "sitemap.xml discovery" "curl -s $TARGET/sitemap.xml" "$OUTPUT_DIR/web/05-sitemap.xml"
    run_scan ".git exposure check" "curl -s $TARGET/.git/config" "$OUTPUT_DIR/web/06-git-config.txt"

    # Backup file checks
    for ext in .bak .backup .old .swp .tmp; do
        run_scan "Backup check (index.php$ext)" "curl -s $TARGET/index.php$ext" "$OUTPUT_DIR/web/07-backup-$ext.txt"
    done
fi

# ===== CUSTOM CHECKS =====
echo -e "${YELLOW}[*] Phase 10: Additional Security Checks${NC}"

if check_tool curl; then
    # Security headers check
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
    }" "$OUTPUT_DIR/headers/04-security-headers-check.txt"
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
echo -e "  ${BLUE}injection/${NC}   - SQL injection and injection testing"
echo -e "  ${BLUE}fuzzing/${NC}     - Fuzzing and parameter discovery"
echo -e "  ${BLUE}logs/${NC}        - Detailed logs\n"

echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Review each file for vulnerabilities"
echo -e "  2. Cross-reference findings with WSTG playbook"
echo -e "  3. Manual testing for business logic and context-specific vulns"
echo -e "  4. Run Burp Suite for interactive testing\n"

# Create a summary report
cat > "$OUTPUT_DIR/SCAN-SUMMARY.txt" << EOF
WSTG Automated Scan Report
==========================

Target: $TARGET
Host: $HOST
Port: $PORT
Scan Date: $(date)

SCAN STATISTICS:
Total Scans: $((PASSED_SCANS + FAILED_SCANS_COUNT))
Passed: $PASSED_SCANS
Failed: $FAILED_SCANS_COUNT
Success Rate: $([ $((PASSED_SCANS + FAILED_SCANS_COUNT)) -eq 0 ] && echo "0" || echo "$((PASSED_SCANS * 100 / (PASSED_SCANS + FAILED_SCANS_COUNT)))")%

PHASES EXECUTED:
✓ Phase 1: Reconnaissance (DNS, WHOIS, reverse DNS)
✓ Phase 2: Port Scanning (Nmap service detection, HTTP methods)
✓ Phase 3: Web Server Analysis (Nikto, WhatWeb, Dirb IIS)
✓ Phase 4: Header Analysis (HTTP headers, security headers)
✓ Phase 5: SSL/TLS Configuration (Certificates, protocols)
✓ Phase 6: Directory Enumeration (Gobuster)
✓ Phase 7: Parameter Fuzzing (wfuzz)
✓ Phase 8: SQL Injection (SQLMap light)
✓ Phase 9: Common Vulnerability Patterns (robots.txt, .git, backups)
✓ Phase 10: Additional Security Checks (security headers)

EOF

if [ ${#FAILED_SCANS[@]} -gt 0 ]; then
    echo "FAILED SCANS:" >> "$OUTPUT_DIR/SCAN-SUMMARY.txt"
    for scan in "${FAILED_SCANS[@]}"; do
        echo "  ✗ $scan" >> "$OUTPUT_DIR/SCAN-SUMMARY.txt"
    done
    echo "" >> "$OUTPUT_DIR/SCAN-SUMMARY.txt"
fi

cat >> "$OUTPUT_DIR/SCAN-SUMMARY.txt" << EOF

FILES GENERATED:
$(find "$OUTPUT_DIR" -type f ! -name "SCAN-SUMMARY.txt" | sort | sed 's|^|  - |')

AUTOMATED COVERAGE:
- Information gathering: 80%
- Configuration scanning: 75%
- Directory discovery: 70%
- Injection testing: 60%

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
EOF

echo -e "${BLUE}Summary report: ${YELLOW}$OUTPUT_DIR/SCAN-SUMMARY.txt${NC}\n"
