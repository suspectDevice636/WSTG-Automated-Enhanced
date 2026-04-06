# WSTG Automation Script

Automated penetration testing script for Kali Linux using CLI tools. Takes a target URL and generates individual output files for each scan category.

**🆕 New:** Includes a [vulnerable Flask app](#-testing-with-vulnerable-app) for testing the script locally!

## Quick Testing (New!)

Want to test the WSTG script immediately without a real target? Use the included vulnerable app:

```bash
# Start the vulnerable app
cd vulnerable-app/
docker-compose up -d

# In another terminal, run the WSTG script
cd ..
./wstg-automation.sh http://localhost:5000

# View results
cat wstg-scan-*/SCAN-SUMMARY.txt
```

**→ See [Testing with Vulnerable App](#-testing-with-vulnerable-app) section below for details**

---

## Usage

```bash
./wstg-automation.sh <target_url>
```

### Examples

```bash
# HTTP target
./wstg-automation.sh http://example.com

# HTTPS target
./wstg-automation.sh https://example.com

# Target with custom port
./wstg-automation.sh http://example.com:8080
```

## Output Structure

Script creates a timestamped directory with organized results:

```
wstg-scan-20260402_154300/
├── SCAN-SUMMARY.txt          # Executive summary
├── recon/
│   ├── 01-dns-lookup.txt
│   ├── 02-dig-short.txt
│   ├── 03-whois.txt
│   ├── 04-reverse-dns.txt
│   ├── 05-nmap-top1000.txt
│   └── 06-nmap-aggressive.txt
├── web/
│   ├── 01-nikto-scan.txt
│   ├── 02-gobuster-dirs.txt
│   ├── 03-dir-listing-check.txt
│   ├── 04-robots.txt
│   ├── 05-sitemap.xml
│   ├── 06-git-config.txt
│   ├── 07-backup-*.txt
│   └── 08-http-methods.txt
├── ssl/
│   ├── 01-cert-info.txt
│   ├── 02-ssl-ciphers.txt
│   ├── 03-tls-v1.0.txt
│   ├── 04-tls-v1.1.txt
│   └── 05-tls-v1.2.txt
├── headers/
│   ├── 01-http-headers.txt
│   ├── 02-response-headers.txt
│   ├── 03-server-info.txt
│   └── 04-security-headers-check.txt
├── injection/
│   └── 01-sqlmap-light.txt
├── fuzzing/
│   └── 01-get-params.txt
└── logs/
```

## Scans Included

### Phase 1: Reconnaissance
- DNS lookups (nslookup, dig)
- WHOIS information
- Reverse DNS
- **Output:** DNS records, domain info, IP history

### Phase 2: Port Scanning
- Nmap top 1000 ports with version detection
- Nmap aggressive scan
- **Output:** Open ports, services, OS detection

### Phase 3: Web Server Analysis
- Nikto scanner
- **Output:** CGI issues, outdated software, misconfigurations

### Phase 4: Header & Security Configuration
- HTTP headers extraction
- Server detection
- **Output:** Server version, security headers, technology stack

### Phase 5: SSL/TLS Configuration
- Certificate info (validity, issuer, algorithms)
- Cipher suite enumeration
- TLS version support
- **Output:** Certificate details, weak ciphers, protocol issues

### Phase 6: Directory Enumeration
- Gobuster directory brute-force
- **Output:** Discovered directories and files

### Phase 7: Parameter Fuzzing
- wfuzz GET parameter discovery
- **Output:** Hidden parameters, fuzzing results

### Phase 8: SQL Injection Testing
- SQLMap light scan (risk=1, level=1)
- **Output:** SQL injection vulnerabilities (if found)

### Phase 9: Common Vulnerabilities
- Directory listing checks
- robots.txt / sitemap.xml discovery
- .git exposure
- Backup file detection
- **Output:** Misconfigured files, sensitive paths

### Phase 10: Additional Security Checks
- Security header verification (HSTS, CSP, X-Frame-Options, etc.)
- HTTP methods allowed
- **Output:** Missing headers, insecure methods

## What Gets Automated (70-80% of WSTG)

✅ **Fully Automated:**
- Information gathering
- Port enumeration
- SSL/TLS configuration
- Header analysis
- Common misconfigurations
- Directory discovery
- Basic SQL injection
- Backup/sensitive file detection

⚠️ **Partially Automated:**
- Authorization testing (basic endpoint probing)
- Session management (cookie attribute checks)
- Input validation (fuzzing)

❌ **Requires Manual Testing:**
- Business logic exploitation
- Authentication bypass (context-specific)
- CSRF attacks
- Client-side vulnerabilities
- Complex authorization chains
- Cryptography analysis

## Requirements

Ensure these tools are installed on Kali Linux:

```bash
# Core tools (usually pre-installed on Kali)
nmap
nikto
nslookup / dig
whois
curl
openssl
gobuster
wfuzz
sqlmap

# Install missing tools:
sudo apt update
sudo apt install nikto gobuster wfuzz sqlmap
```

## Configuration & Customization

### Adjust Wordlist for Gobuster
Edit the script and modify the wordlist path:

```bash
# Line ~90 - Change to your preferred wordlist
-w /usr/share/wordlists/dirbuster/directory-list-2.3-small.txt
```

### Skip HTTPS-Only Checks
The script auto-detects HTTPS. For HTTP targets, SSL/TLS scans are skipped.

### Adjust Nmap Aggressiveness
Modify timing template (line ~70):

```bash
# -T4 = Aggressive (default)
# -T3 = Normal
# -T2 = Polite
# -T1 = Sneaky
nmap -A -T2 "$HOST"  # More stealthy
```

### SQLMap Risk Levels
Modify line ~145:

```bash
# Current: risk=1 (low), level=1 (basic)
# Higher values = more aggressive testing
sqlmap -u "$TARGET" --batch --risk=2 --level=3 -o
```

## Tips & Tricks

### Quick Review of All Findings
```bash
cd wstg-scan-*/
grep -r "FOUND\|VULNERABLE\|ERROR\|WARNING" .
```

### Extract All URLs Found
```bash
cat web/*.txt | grep -oP 'https?://[^\s"<>]+' | sort -u
```

### Check for Open Ports Only
```bash
grep "open" recon/05-nmap-top1000.txt
```

### Follow Up with Burp
1. Open Burp Suite
2. Configure proxy to target
3. Load results from automated scan
4. Focus manual testing on discovered endpoints
5. Test business logic and context-specific vulnerabilities

## Workflow

1. **Run automated script**
   ```bash
   ./wstg-automation.sh http://target.com
   ```

2. **Review summary**
   ```bash
   cat wstg-scan-*/SCAN-SUMMARY.txt
   ```

3. **Check high-priority findings**
   ```bash
   cat wstg-scan-*/recon/05-nmap-top1000.txt
   cat wstg-scan-*/web/01-nikto-scan.txt
   ```

4. **Exploit with Burp Suite** — manual exploitation of discovered vulnerabilities

5. **Compile findings** — use findings from script + manual tests

## 🧪 Testing with Vulnerable App

This repo includes a deliberately vulnerable Flask web application for testing and validating the WSTG automation script.

### What's Included

The `vulnerable-app/` folder contains a Flask application with 10 intentional vulnerabilities:

- ✅ **SQL Injection** — SQLMap can detect/exploit
- ✅ **IDOR** — Insecure Direct Object References
- ✅ **Weak Authentication** — Default credentials (`admin/admin123`)
- ✅ **Reflected XSS** — Input validation vulnerabilities
- ✅ **Information Disclosure** — Exposed admin panel, robots.txt, .git directory
- ✅ **Missing Security Headers** — CSP, HSTS, X-Frame-Options missing
- ✅ **Exposed Credentials** — In backup files and API responses
- ✅ **Unrestricted HTTP Methods** — PUT, DELETE without auth
- ✅ **Unvalidated Redirects** — Open redirect vulnerability
- ✅ **Debug Mode** — Flask debug enabled

### Quick Start

```bash
# 1. Start the vulnerable app
cd vulnerable-app/
docker-compose up -d

# 2. Verify it's running
curl http://localhost:5000

# 3. In another terminal, run the WSTG script
cd ..
./wstg-automation.sh http://localhost:5000

# 4. Review findings
cat wstg-scan-*/SCAN-SUMMARY.txt

# 5. Stop the app
cd vulnerable-app/
docker-compose down
```

### Expected Findings

The WSTG script will detect:
- ✅ Open port 5000
- ✅ Missing security headers
- ✅ robots.txt and sitemap.xml exposure
- ✅ .git directory exposure
- ✅ Backup files (Nikto scan)
- ✅ Outdated Flask version detection
- ✅ SQL injection parameters
- ✅ Multiple HTTP methods allowed

### Manual Testing Examples

```bash
# Test SQL Injection
curl "http://localhost:5000/api/user/1 OR 1=1"

# Access user data (IDOR)
curl http://localhost:5000/api/profile/1
curl http://localhost:5000/api/profile/2

# XSS payload
curl "http://localhost:5000/xss?message=<script>alert('XSS')</script>"

# Try unrestricted HTTP methods
curl -X DELETE http://localhost:5000/resource/1
curl -X PUT http://localhost:5000/resource/1

# Test weak authentication
curl -X POST http://localhost:5000/login \
  -d "username=admin&password=admin123"
```

### Full Vulnerable App Documentation

See `vulnerable-app/README.md` for comprehensive vulnerability details and testing methodology.

---

## Notes

- Script runs sequentially (not in parallel) for stability
- Some scans may take 5-15 minutes depending on target size
- Timeout: 120 seconds per individual command
- Failed scans don't stop the script (|| true for resilience)
- All output is timestamped for organization
- Use the included vulnerable app to validate the script in local environments

## Security Warnings

⚠️ **Disclaimer:** Only run against targets you own or have written permission to test. Unauthorized security testing is illegal.

- Run from inside Kali VM or isolated network
- Use VPN/proxy if testing across the internet
- Log all scans for reporting
- Follow rules of engagement (ROE) from the client

---

**Created:** 2026-04-02 | **For:** SD | **Tool:** Kali Linux (Debian-based)
