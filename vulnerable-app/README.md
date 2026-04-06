# WSTG Vulnerable Web Application

A deliberately vulnerable Flask web application designed for testing and validating WSTG (Web Security Testing Guide) penetration testing automation scripts.

## ⚠️ WARNING

This application contains **intentional security vulnerabilities** and is designed **ONLY** for:
- ✅ Authorized security testing
- ✅ Educational purposes
- ✅ Validating penetration testing tools
- ✅ CI/CD pipeline security testing

**DO NOT deploy this to production or public networks.** Only run in isolated environments or locally.

---

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose installed
- Or: Python 3.9+ with Flask 2.0.1

### Option 1: Docker Compose (Recommended)

```bash
# Clone or navigate to the repo
cd WSTG-VulnerableApp

# Start the vulnerable app
docker-compose up -d

# Verify it's running
curl http://localhost:5000

# View logs
docker-compose logs -f

# Stop the app
docker-compose down
```

### Option 2: Docker Build

```bash
# Build image
docker build -t wstg-vulnerable-app .

# Run container
docker run -p 5000:5000 wstg-vulnerable-app

# Access at http://localhost:5000
```

### Option 3: Run Locally

```bash
pip install -r requirements.txt
python app.py

# Access at http://localhost:5000
```

---

## 📋 Vulnerabilities Included

### 1. **SQL Injection** 🔴 CRITICAL
- **Endpoints:** `/api/user/<id>`, `/search`
- **Vulnerability:** Direct string concatenation in SQL queries
- **Detection:** SQLMap, manual query testing
- **Example:**
  ```
  /api/user/1 OR 1=1
  /search?username=admin' OR '1'='1
  ```

### 2. **Insecure Direct Object Reference (IDOR)** 🔴 CRITICAL
- **Endpoint:** `/api/profile/<id>`
- **Vulnerability:** No authorization checks on user data access
- **Detection:** Try accessing `/api/profile/1`, `/api/profile/2`, `/api/profile/999`
- **Impact:** Unauthorized access to all user data including passwords

### 3. **Weak Authentication** 🔴 CRITICAL
- **Endpoint:** `/login`
- **Vulnerability:** No rate limiting, weak credentials stored in plain text
- **Test Credentials:**
  - `admin` / `admin123`
  - `user` / `password123`
  - `guest` / `guest`
- **Impact:** Easy credential guessing, no brute force protection

### 4. **Reflected XSS (Cross-Site Scripting)** 🟠 HIGH
- **Endpoint:** `/xss`
- **Vulnerability:** Unsanitized user input rendered in HTML
- **Detection:** Try `?message=<script>alert('XSS')</script>`
- **Impact:** Session hijacking, credential theft

### 5. **Information Disclosure** 🟠 HIGH
- **Exposed Files:**
  - `/admin` — Admin panel with debug info (no authentication required)
  - `/backup` — Exposed backup files containing credentials
  - `/robots.txt` — Lists sensitive paths
  - `/sitemap.xml` — Lists all endpoints
  - `/.git/config` — Exposed git configuration
- **Impact:** Attacker gains knowledge of system architecture and credentials

### 6. **Missing Security Headers** 🟠 HIGH
- **Vulnerability:** No `Content-Security-Policy`, `X-Frame-Options`, `Strict-Transport-Security`, etc.
- **Detection:** Use header analysis tools, curl:
  ```bash
  curl -I http://localhost:5000
  ```

### 7. **Exposed Credentials** 🟠 HIGH
- **Location:** `/backup` endpoint, `/admin` page, `/api/profile/<id>`
- **Hardcoded credentials:** In app.py comments and exposed files
- **Impact:** Direct unauthorized access

### 8. **Unrestricted HTTP Methods** 🟡 MEDIUM
- **Endpoint:** `/resource/<id>`
- **Vulnerability:** PUT, DELETE, PATCH methods allowed without authentication
- **Detection:**
  ```bash
  curl -X DELETE http://localhost:5000/resource/1
  curl -X PUT http://localhost:5000/resource/1
  ```

### 9. **Unvalidated Redirects** 🟡 MEDIUM
- **Endpoint:** `/redirect`
- **Vulnerability:** No validation of redirect URLs
- **Detection:** `/redirect?url=http://attacker.com`
- **Impact:** Phishing attacks

### 10. **Debug Mode Enabled** 🟡 MEDIUM
- **Vulnerability:** Flask debug mode enabled in production (app.config['DEBUG'] = True)
- **Impact:** Information disclosure, potential code execution

---

## 🔍 Testing with WSTG Automation Script

### Run the WSTG Automated Scanner

Once the vulnerable app is running on `http://localhost:5000`:

```bash
# Make sure you have the WSTG_Automated script
cd /path/to/WSTG_Automated-main

# Run the script against localhost
./wstg-automation.sh http://localhost:5000

# Results will be in wstg-scan-<timestamp>/
cd wstg-scan-*/
cat SCAN-SUMMARY.txt
```

### Expected Findings

The WSTG script should detect:
- ✅ Open port 5000 (HTTP)
- ✅ Missing security headers
- ✅ Directory listing/exposure
- ✅ robots.txt and sitemap.xml
- ✅ Exposed `.git` directory
- ✅ Nikto vulnerabilities (outdated Flask version)
- ✅ Potential SQL injection parameters
- ✅ Multiple HTTP methods allowed

---

## 📁 Project Structure

```
WSTG-VulnerableApp/
├── app.py                # Main Flask application with vulnerabilities
├── requirements.txt      # Python dependencies
├── Dockerfile           # Docker image configuration
├── docker-compose.yml   # Easy orchestration with docker-compose
├── README.md            # This file
└── data/                # (Optional) Data storage
```

---

## 🛠️ Customization

### Add More Vulnerabilities

Edit `app.py` and add new routes:

```python
@app.route('/custom-vuln')
def custom_vulnerability():
    # Your vulnerable code here
    return "Vulnerable endpoint"
```

### Change Port

Edit `docker-compose.yml`:
```yaml
ports:
  - "8080:5000"  # Changed from 5000 to 8080
```

### Modify Flask Settings

Edit `app.py`:
```python
app.config['DEBUG'] = False  # Disable debug mode
app.config['TESTING'] = True  # Enable testing mode
```

---

## 🧪 Manual Testing Examples

### SQL Injection
```bash
# Basic test
curl "http://localhost:5000/api/user/1"

# SQL Injection
curl "http://localhost:5000/api/user/1 OR 1=1"

# With SQLMap
sqlmap -u "http://localhost:5000/api/user/*" --batch
```

### IDOR
```bash
# Access different users
curl http://localhost:5000/api/profile/1
curl http://localhost:5000/api/profile/2
curl http://localhost:5000/api/profile/999
```

### XSS
```bash
# Reflected XSS payload
curl "http://localhost:5000/xss?message=<script>alert('XSS')</script>"
```

### HTTP Methods
```bash
# Check allowed methods
curl -X OPTIONS -v http://localhost:5000/resource/1

# Try DELETE
curl -X DELETE http://localhost:5000/resource/1
```

### Brute Force Login
```bash
for pass in admin password 123 test; do
  curl -X POST http://localhost:5000/login \
    -d "username=admin&password=$pass" \
    -L -i
done
```

---

## 📊 Vulnerability Severity Map

| Vulnerability | CVSS | OWASP Top 10 | Detection |
|--------------|------|--------------|-----------|
| SQL Injection | 9.8 | A1 | Nikto, SQLMap, manual |
| IDOR | 7.5 | A1 | Manual, directory fuzzing |
| Weak Auth | 7.3 | A7 | Manual, brute force tools |
| XSS | 6.1 | A7 | XSStrike, manual |
| Info Disclosure | 7.5 | A1 | robots.txt, directory listing |
| Missing Headers | 5.3 | A5 | Header analysis |
| Exposed Creds | 7.5 | A2 | Manual inspection |
| HTTP Methods | 4.3 | A1 | curl, Burp |
| Redirects | 4.3 | A5 | Manual testing |
| Debug Mode | 5.3 | A5 | Server fingerprinting |

---

## 🔐 Security Notes

### Running in Production (DO NOT!)
If you accidentally expose this:
1. Immediately shut down the container
2. Do not use the same credentials elsewhere
3. Secure your network

### Network Isolation
- Run only on `localhost` or isolated Docker network
- Never expose to public internet
- Use firewall rules to restrict access

### Logging & Monitoring
- Check logs: `docker-compose logs -f`
- Monitor system resources: `docker stats`
- Clear database: `rm /tmp/wstg_vulnerable.db`

---

## 📚 Learning Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [WSTG (Web Security Testing Guide)](https://owasp.org/www-project-web-security-testing-guide/)
- [OWASP Testing Checklist](https://owasp.org/www-project-web-security-testing-guide/stable/4-Web_Application_Security_Testing/)
- [PortSwigger Web Security Academy](https://portswigger.net/web-security)

---

## 🤝 Contributing

To add more vulnerabilities or improve the app:

1. Create a new endpoint with a clear vulnerability
2. Document it in this README
3. Commit with message: `feat: add <vulnerability-type> vulnerability`

---

## ⚖️ License

This project is provided for educational and authorized security testing purposes only.

---

## ⚠️ Disclaimer

**This application is intentionally vulnerable.** Do not use this code in production or any real-world application. The author is not responsible for misuse or damage caused by this application.

Use of this application for unauthorized security testing is illegal. Only use with explicit written permission from the system owner.

---

**Created for:** Security testing and WSTG automation validation
**Last Updated:** April 2026
**Maintained by:** Suspect Device
