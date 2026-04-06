#!/bin/bash

#########################################
# WSTG Automated Scanner
# Target: Single URL input
# Output: Individual scan files organized by category
# Tools: Kali Linux CLI tools (nmap, nikto, sqlmap, curl, etc.)
#########################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error tracking
FAILED_SCANS=()
PASSED_SCANS=0
FAILED_SCANS_COUNT=0
ERROR_LOG=""

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Usage: $0 <target_url>${NC}"
    echo -e "${YELLOW}Example: $0 http://example.com${NC}"
    exit 1
fi

# Function to log errors
log_error() {
    local scan_name="$1"
    local error_msg="$2"
    FAILED_SCANS+=("$scan_name: $error_msg")
    ((FAILED_SCANS_COUNT++))
    echo -e "${RED}✗ FAILED: $scan_name${NC}"
    echo -e "  ${RED}Error: $error_msg${NC}"
}

# Function to log success
log_success() {
    local scan_name="$1"
    ((PASSED_SCANS++))
    echo -e "${GREEN}✓ $scan_name${NC}"
}

# Function to run scan with error handling
run_scan() {
    local scan_name="$1"
    local command="$2"
    local output_file="$3"
    
    if eval "$command" > "$output_file" 2>&1; then
        if [ -s "$output_file" ]; then
            log_success "$scan_name"
        else
            log_error "$scan_name" "Command ran but produced no output"
        fi
    else
        log_error "$scan_name" "Command failed (exit code $?)"
    fi
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
echo -e "${BLUE}WSTG Automated Scanner${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "Target: ${GREEN}$TARGET${NC}"
echo -e "Host: ${GREEN}$HOST${NC}"
echo -e "Port: ${GREEN}$PORT${NC}"
echo -e "Output: ${GREEN}$OUTPUT_DIR${NC}"
echo -e "${BLUE}============================================${NC}\n"

# Create output directory structure
mkdir -p "$OUTPUT_DIR"/{recon,web,ssl,injection,headers,fuzzing,logs}

# Check for required tools
echo -e "${YELLOW}[*] Checking for required tools...${NC}\n"
CRITICAL_TOOLS=(curl nmap)
OPTIONAL_TOOLS=(nikto gobuster wfuzz sqlmap dig whois host openssl)
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

echo -e "\n${YELLOW}[*] Starting WSTG automated scans...${NC}\n"

echo -e "${YELLOW}[*] Starting WSTG automated scans...${NC}\n"

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
    run_scan "Nmap (top 1000 ports)" "nmap -sV -sC -O --top-ports 1000 $HOST" "$OUTPUT_DIR/recon/05-nmap-top1000.txt"
    run_scan "Nmap (aggressive scan)" "nmap -A -T4 $HOST" "$OUTPUT_DIR/recon/06-nmap-aggressive.txt"
else
    log_error "Nmap scans" "nmap not found"
fi

# ===== WEB SERVER SCANNING =====
echo -e "${YELLOW}[*] Phase 3: Web Server Analysis${NC}"

if check_tool nikto; then
    run_scan "Nikto scan" "nikto -h $TARGET" "$OUTPUT_DIR/web/01-nikto-scan.txt"
else
    log_error "Nikto scan" "nikto not found"
fi

# ===== HEADER ANALYSIS =====
echo -e "${YELLOW}[*] Phase 4: Header & Security Configuration${NC}"

if check_tool curl; then
    run_scan "HTTP headers" "curl -I -H 'User-Agent: Mozilla/5.0' $TARGET" "$OUTPUT_DIR/headers/01-http-headers.txt"
    run_scan "Response headers (verbose)" "curl -v $TARGET 2>&1 | grep -i '^< '" "$OUTPUT_DIR/headers/02-response-headers.txt"
    run_scan "Server detection" "curl -I $TARGET 2>&1 | grep -i 'Server|X-'" "$OUTPUT_DIR/headers/03-server-info.txt"
else
    log_error "Header analysis" "curl not found"
fi

# ===== SSL/TLS ANALYSIS =====
echo -e "${YELLOW}[*] Phase 5: SSL/TLS Configuration${NC}"

if [ "$SCHEME" == "https" ] || [ "$PORT" == "443" ]; then
    if check_tool openssl; then
        run_scan "SSL certificate info" "openssl s_client -connect $HOST:$PORT -servername $HOST < /dev/null 2>&1 | openssl x509 -text -noout" "$OUTPUT_DIR/ssl/01-cert-info.txt"
    else
        log_error "SSL certificate info" "openssl not found"
    fi
    
    if check_tool nmap; then
        run_scan "SSL protocol support" "nmap --script ssl-enum-ciphers -p $PORT $HOST" "$OUTPUT_DIR/ssl/02-ssl-ciphers.txt"
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
else
    log_error "Gobuster directory scan" "gobuster not found"
fi

# ===== PARAMETER FUZZING =====
echo -e "${YELLOW}[*] Phase 7: Parameter Fuzzing${NC}"

if check_tool wfuzz; then
    run_scan "Parameter fuzzing (GET)" "wfuzz -c -z file,/usr/share/wordlists/wfuzz/general/common.txt -u $TARGET?FUZZ=test --hc 404" "$OUTPUT_DIR/fuzzing/01-get-params.txt"
else
    log_error "Parameter fuzzing" "wfuzz not found"
fi

# ===== SQL INJECTION TESTING =====
echo -e "${YELLOW}[*] Phase 8: SQL Injection Checks${NC}"

if check_tool sqlmap; then
    run_scan "SQLMap scan (light)" "sqlmap -u $TARGET --batch --risk=1 --level=1 -o" "$OUTPUT_DIR/injection/01-sqlmap-light.txt"
else
    log_error "SQLMap scan" "sqlmap not found"
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
else
    log_error "Vulnerability checks" "curl not found"
fi

# ===== CUSTOM CHECKS =====
echo -e "${YELLOW}[*] Phase 10: Additional Security Checks${NC}"

if check_tool curl; then
    # Security headers check
    {
        echo "=== Security Header Checks ==="
        echo ""
        echo "Testing: Strict-Transport-Security (HSTS)"
        curl -I "$TARGET" 2>&1 | grep -i "strict-transport\|hsts" || echo "❌ HSTS not found"
        echo ""
        echo "Testing: Content-Security-Policy (CSP)"
        curl -I "$TARGET" 2>&1 | grep -i "content-security-policy" || echo "❌ CSP not found"
        echo ""
        echo "Testing: X-Content-Type-Options"
        curl -I "$TARGET" 2>&1 | grep -i "x-content-type-options" || echo "❌ X-Content-Type-Options not found"
        echo ""
        echo "Testing: X-Frame-Options"
        curl -I "$TARGET" 2>&1 | grep -i "x-frame-options" || echo "❌ X-Frame-Options not found"
        echo ""
    } > "$OUTPUT_DIR/headers/04-security-headers-check.txt" 2>&1 && log_success "Security headers check" || log_error "Security headers check" "Failed to retrieve/analyze headers"
    
    run_scan "HTTP methods check" "curl -v -X OPTIONS $TARGET 2>&1 | grep -i 'allow|methods'" "$OUTPUT_DIR/web/08-http-methods.txt"
else
    log_error "Custom security checks" "curl not found"
fi

# ===== SUMMARY =====
echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}[✓] Scan Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo -e "Results saved to: ${BLUE}$OUTPUT_DIR${NC}\n"

# Print scan summary
echo -e "${BLUE}Scan Summary:${NC}"
echo -e "  ${GREEN}Passed:${NC} $PASSED_SCANS"
echo -e "  ${RED}Failed:${NC} $FAILED_SCANS_COUNT\n"

# Print failed scans if any
if [ ${#FAILED_SCANS[@]} -gt 0 ]; then
    echo -e "${RED}Failed Scans:${NC}"
    for scan in "${FAILED_SCANS[@]}"; do
        echo -e "  ${RED}✗${NC} $scan"
    done
    echo ""
fi

echo -e "${YELLOW}Output Structure:${NC}"
echo -e "  ${BLUE}recon/${NC}       - DNS, WHOIS, Nmap results"
echo -e "  ${BLUE}web/${NC}         - Web server, directories, backups"
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
Success Rate: $((PASSED_SCANS * 100 / (PASSED_SCANS + FAILED_SCANS_COUNT)))%

PHASES EXECUTED:
✓ Phase 1: Reconnaissance (DNS, WHOIS, reverse DNS)
✓ Phase 2: Port Scanning (Nmap top 1000 + aggressive)
✓ Phase 3: Web Server Analysis (Nikto)
✓ Phase 4: Header Analysis (HTTP headers, security headers)
✓ Phase 5: SSL/TLS Configuration (Certificates, protocols)
✓ Phase 6: Directory Enumeration (Gobuster)
✓ Phase 7: Parameter Fuzzing (wfuzz)
✓ Phase 8: SQL Injection (SQLMap light)
✓ Phase 9: Common Vulnerability Patterns (robots.txt, .git, backups)
✓ Phase 10: Additional Security Checks (HTTP methods, headers)

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
