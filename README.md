# WSTG Automation Script

Automated penetration testing framework for Kali Linux using CLI tools. Takes a target URL and generates comprehensive output organized by testing category.

**🆕 Features:**
- ✅ **Two versions:** Fully automated (v1) or interactive menu (v2)
- ✅ **24 WSTG-aligned scans** across 9 phases
- ✅ **Real-time progress tracking** with spinner and progress bar
- ✅ **Vulnerable test app** included for local validation
- ✅ **Legal disclaimers** with authorization checks built-in

---

## Version Selection

### v1.0.0 - Fully Automated Scanner
**File:** `wstg-automation.sh`

Runs all 24 scans automatically. Perfect for:
- Quick full assessments
- Automated scanning in scripts
- When you want everything tested

```bash
./wstg-automation.sh http://target.com
```

### v2.0.0 - Interactive Menu Scanner
**File:** `wstg-automation-v2.sh`

Interactive menu with scan selection. Perfect for:
- Targeted assessments (specific vulnerability types)
- Time-constrained testing
- When you want to skip certain scans

```bash
./wstg-automation-v2.sh http://target.com
```

Select scans with arrow keys (↑↓), toggle with (←→), press Enter to start.

---

## Quick Testing

Want to test immediately without a real target? Use the included vulnerable app:

```bash
# Start the vulnerable app
cd vulnerable-app/
docker-compose up -d

# In another terminal, run the WSTG script
cd ..
./wstg-automation-v2.sh http://localhost:5000

# View results
cat wstg-scan-*/SCAN-SUMMARY.txt

# Stop the app
cd vulnerable-app/
docker-compose down
```

---

## Installation

### Requirements
Ensure these tools are installed on Kali Linux:

```bash
# Core tools (usually pre-installed)
nmap curl openssl

# Install optional tools:
sudo apt update
sudo apt install nikto gobuster wfuzz dnsrecon sslscan whatweb dirb
```

### Setup
```bash
git clone https://github.com/suspectDevice636/WSTG_Automated-main.git
cd WSTG_Automated-main
chmod +x wstg-automation.sh wstg-automation-v2.sh
```

---

## Usage

### Automated (v1)
```bash
./wstg-automation.sh <target_url>

# Examples
./wstg-automation.sh http://example.com
./wstg-automation.sh https://example.com:8443
./wstg-automation.sh http://192.168.1.100:8080
```

### Interactive (v2)
```bash
./wstg-automation-v2.sh <target_url>

# Verify authorization, select scans, press Enter to start
```

---

## Scans Included (24 Total)

### Phase 1: Reconnaissance (6 scans)
- DNS Lookup (nslookup)
- DNS Lookup (dig)
- **DNS Nameservers** (host -t ns)
- **DNS Reconnaissance** (dnsrecon)
- WHOIS Lookup
- Reverse DNS Lookup

### Phase 2: Port Scanning (2 scans)
- Nmap Service Detection (-sV -Pn)
- Nmap HTTP Methods (NSE script)

### Phase 3: Web Server Analysis (3 scans)
- Nikto Web Server Scan
- WhatWeb Technology Detection
- Dirb IIS Vulnerability Scan

### Phase 4: Headers & Security Configuration (2 scans)
- HTTP Headers Analysis
- Security Headers Check (HSTS, CSP, X-Frame-Options)

### Phase 5: SSL/TLS Configuration (3 scans)
- SSL Certificate Analysis (openssl)
- **SSL Configuration Scan** (sslscan)
- TLS Version Support (v1.0, v1.1, v1.2)

### Phase 6: Directory Enumeration (1 scan)
- Gobuster Directory Brute-Force

### Phase 7: Parameter Fuzzing (1 scan)
- WFuzz GET Parameter Discovery

### Phase 8: Common Vulnerability Patterns (5 scans)
- Directory Listing Check
- robots.txt Discovery
- sitemap.xml Discovery
- .git Exposure Check
- Backup Files Check (*.bak, *.backup, *.old, *.swp, *.tmp)

### Phase 9: Advanced Security Checks (3 scans)
- CORS Misconfiguration Check
- API Endpoint Discovery
- Sensitive Data Exposure Check

---

## Output Structure

Script creates a timestamped directory with organized results:

```
wstg-scan-20260409_142015/
├── SCAN-SUMMARY.txt          # Executive summary with statistics
├── recon/
│   ├── 01-dns-lookup.txt
│   ├── 02-dig-short.txt
│   ├── 03-dns-nameservers.txt
│   ├── 04-dnsrecon.txt
│   ├── 05-whois.txt
│   └── 06-reverse-dns.txt
├── nmap/
│   ├── 01-nmap-service.txt
│   ├── 01-nmap-service.nmap
│   ├── 01-nmap-service.xml
│   ├── 02-nmap-http-methods.txt
│   ├── 02-nmap-http-methods.nmap
│   └── 02-nmap-http-methods.xml
├── web/
│   ├── 01-nikto-scan.txt
│   ├── 02-whatweb-scan.txt
│   ├── 03-dirb-iis.txt
│   ├── 04-gobuster-dirs.txt
│   ├── 05-dir-listing-check.txt
│   ├── 06-robots.txt
│   ├── 07-sitemap.xml
│   ├── 08-git-config.txt
│   └── 09-backup-*.txt
├── ssl/
│   ├── 01-cert-info.txt
│   ├── 02-sslscan.txt
│   ├── 03-tls-v1.0.txt
│   ├── 04-tls-v1.1.txt
│   └── 05-tls-v1.2.txt
├── headers/
│   ├── 01-http-headers.txt
│   ├── 02-security-headers-check.txt
│   ├── 05-cors-check.txt
│   └── 06-sensitive-data.txt
├── fuzzing/
│   └── 01-get-params.txt
├── web/
│   └── 10-api-discovery.txt
└── logs/
```

---

## Features

### Real-Time Progress Tracking
- ✅ Animated spinner showing scan is active
- ✅ Progress bar with current/total scan count
- ✅ Detailed error messages with actual stderr output
- ✅ Color-coded output (green ✓, red ✗)

### Smart Error Handling
- Shows actual error messages instead of generic exit codes
- Connection refused, Timeout, Permission denied, etc.
- Failed scans don't stop the script
- Summary report of all failures

### Organized Output
- Timestamped directories prevent conflicts
- Results grouped by testing category
- Multiple output formats (txt, nmap, xml, gnmap)
- Executive summary with statistics

### Legal & Authorization
- ⚠️ Legal disclaimer at startup
- Requires explicit authorization confirmation
- Educational use notice
- Safe for authorized penetration testing

---

## WSTG Alignment

### Fully Automated (70-80% of WSTG)
✅ Information Gathering
✅ Configuration & Deployment Testing
✅ Authentication Testing (basic)
✅ Authorization Testing (basic)
✅ Session Management Testing
✅ Input Validation Testing
✅ Error Handling & Logging
✅ Weak Cryptography
✅ Business Logic (basic patterns)

### Requires Manual Testing (Burp Suite)
❌ Complex Authorization Chains
❌ Business Logic Exploitation
❌ CSRF Attacks
❌ XSS Exploitation
❌ Client-Side Vulnerabilities
❌ Advanced Cryptography Analysis
❌ Sensitive Data Analysis

---

## Workflow

### 1. Run Automated Scan
```bash
./wstg-automation-v2.sh http://target.com
# Select scans → Press Enter → Wait for results
```

### 2. Review Summary
```bash
cat wstg-scan-*/SCAN-SUMMARY.txt
```

### 3. Check Key Findings
```bash
# Open ports and services
cat wstg-scan-*/nmap/01-nmap-service.txt

# Web server issues
cat wstg-scan-*/web/01-nikto-scan.txt

# DNS information
cat wstg-scan-*/recon/04-dnsrecon.txt
```

### 4. Manual Testing in Burp
1. Open Burp Suite
2. Configure proxy
3. Load discovered endpoints
4. Test business logic and context-specific vulns

### 5. Compile Report
Combine automated + manual findings

---

## 🧪 Vulnerable Test App

Included Flask application with intentional vulnerabilities for testing and validation.

### Vulnerabilities Included

- ✅ **SQL Injection** - Direct string concatenation in queries
- ✅ **IDOR** - Insecure Direct Object References in API
- ✅ **Weak Authentication** - Default credentials (admin/admin123)
- ✅ **CORS Misconfiguration** - Overly permissive CORS headers
- ✅ **Insecure CSP** - Weak Content-Security-Policy with unsafe-inline
- ✅ **Information Disclosure** - Admin panel, exposed backup files
- ✅ **Missing Security Headers** - No HSTS, weak CSP
- ✅ **Unrestricted HTTP Methods** - PUT, DELETE without auth
- ✅ **Unvalidated Redirects** - Open redirect vulnerability
- ✅ **Debug Mode Enabled** - Flask debug mode for testing

### Quick Start

```bash
cd vulnerable-app/
docker-compose up -d

# Test with WSTG script
cd ..
./wstg-automation-v2.sh http://localhost:5000

# Stop
cd vulnerable-app/
docker-compose down
```

See `vulnerable-app/README.md` for comprehensive vulnerability details.

---

## Configuration

### Change Wordlist
Edit the gobuster line in the script:
```bash
-w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt
```

### Adjust Nmap Aggressiveness
Modify timing template:
```bash
# -T4 = Aggressive (default)
# -T3 = Normal
# -T2 = Polite
-sV -Pn -T2 $HOST
```

### Skip HTTPS-Only Checks
Script auto-detects. For HTTP targets, SSL scans are skipped.

---

## Tips & Tricks

### Review All Findings Quickly
```bash
cd wstg-scan-*/
grep -r "VULNERABLE\|ERROR\|WARNING" .
```

### Extract URLs
```bash
cat web/*.txt | grep -oP 'https?://[^\s"<>]+' | sort -u
```

### Check Open Ports
```bash
grep "open" nmap/01-nmap-service.txt
```

---

## Performance Notes

- Sequential execution (stable, slower)
- 5-15 minutes depending on target
- 120 second timeout per command
- Failed scans continue (resilient)
- Progress shown in real-time

---

## Security Warnings

⚠️ **IMPORTANT:** Only run against targets you own or have explicit written permission to test. Unauthorized security testing is illegal.

- Run from Kali VM or isolated network
- Use VPN/proxy for internet testing
- Log all scans for compliance
- Follow Rules of Engagement (ROE)
- Document authorization

---

## Git Versions

```bash
# Get v1.0.0 (automated)
git checkout v1.0.0
./wstg-automation.sh http://target.com

# Get v2.0.0 (interactive)
git checkout v2.0.0
./wstg-automation-v2.sh http://target.com
```

---

## Support & Contribution

For issues, enhancements, or new scans:
- Check existing issues on GitHub
- Submit pull requests for improvements
- Report terminal corruption or crashes
- Suggest new WSTG-aligned scans

---

**Version:** 2.0.0 (Interactive)
**Last Updated:** 2026-04-09
**For:** Authorized Penetration Testing
**License:** Educational Use Only
