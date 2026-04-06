#!/usr/bin/env python3
"""
WSTG Vulnerable Web Application
================================
A deliberately vulnerable Flask app for testing WSTG penetration testing automation.
Contains common OWASP vulnerabilities for educational and authorized testing purposes.

WARNING: This application contains intentional vulnerabilities and should ONLY be used
for authorized security testing and educational purposes.
"""

from flask import Flask, render_template_string, request, redirect, jsonify
import sqlite3
import os
import logging
from pathlib import Path

app = Flask(__name__)
app.config['DEBUG'] = True  # Intentionally enabled for testing

# Setup logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Database path
DB_PATH = '/tmp/wstg_vulnerable.db'

def init_db():
    """Initialize database with vulnerable schema"""
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    # Create users table
    c.execute('''CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        username TEXT,
        password TEXT,
        email TEXT,
        role TEXT
    )''')

    # Insert test data
    c.execute("INSERT INTO users VALUES (1, 'admin', 'admin123', 'admin@example.com', 'admin')")
    c.execute("INSERT INTO users VALUES (2, 'user', 'password123', 'user@example.com', 'user')")
    c.execute("INSERT INTO users VALUES (3, 'guest', 'guest', 'guest@example.com', 'guest')")

    conn.commit()
    conn.close()

# Initialize DB on startup
init_db()

# ============================================================================
# VULNERABILITY 1: SQL Injection
# ============================================================================
@app.route('/api/user/<user_id>')
def get_user(user_id):
    """SQL Injection vulnerability - direct string concatenation in SQL"""
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()

        # VULNERABLE: Direct string concatenation (SQL Injection)
        query = f"SELECT * FROM users WHERE id = {user_id}"
        c.execute(query)
        user = c.fetchone()
        conn.close()

        if user:
            return jsonify({
                'id': user['id'],
                'username': user['username'],
                'email': user['email'],
                'role': user['role']
            })
        return jsonify({'error': 'User not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e), 'query': query}), 500

@app.route('/search')
def search():
    """Search endpoint with SQL injection vulnerability"""
    username = request.args.get('username', '')
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()

        # VULNERABLE: SQL Injection in search
        query = f"SELECT * FROM users WHERE username LIKE '%{username}%'"
        c.execute(query)
        results = c.fetchall()
        conn.close()

        users = [dict(row) for row in results]
        return jsonify({'results': users})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ============================================================================
# VULNERABILITY 2: Weak Authentication & IDOR
# ============================================================================
@app.route('/api/profile/<user_id>')
def get_profile(user_id):
    """Insecure Direct Object Reference - no authorization checks"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    c.execute("SELECT * FROM users WHERE id = ?", (user_id,))
    user = c.fetchone()
    conn.close()

    if user:
        return jsonify({
            'id': user['id'],
            'username': user['username'],
            'email': user['email'],
            'password': user['password'],  # EXPOSED!
            'role': user['role']
        })
    return jsonify({'error': 'User not found'}), 404

@app.route('/login', methods=['GET', 'POST'])
def login():
    """Weak authentication - no rate limiting, weak validation"""
    if request.method == 'POST':
        username = request.form.get('username', '')
        password = request.form.get('password', '')

        # VULNERABLE: No rate limiting, weak checks
        if username and password:
            conn = sqlite3.connect(DB_PATH)
            c = conn.cursor()
            c.execute("SELECT * FROM users WHERE username = ? AND password = ?", (username, password))
            user = c.fetchone()
            conn.close()

            if user:
                return redirect(f'/dashboard/{user[0]}')
            return "Invalid credentials", 401

    return '''
    <html>
    <body>
        <h1>Login</h1>
        <form method="POST">
            Username: <input name="username"><br>
            Password: <input name="password" type="password"><br>
            <input type="submit">
        </form>
        <p>Test: admin/admin123 or user/password123</p>
    </body>
    </html>
    '''

@app.route('/dashboard/<user_id>')
def dashboard(user_id):
    """IDOR - no authorization checking"""
    return f'''
    <html>
    <body>
        <h1>Dashboard for User {user_id}</h1>
        <p><a href="/api/profile/{user_id}">View Full Profile (JSON)</a></p>
        <p><a href="/api/profile/1">Admin Profile</a></p>
        <p><a href="/api/profile/2">User Profile</a></p>
    </body>
    </html>
    '''

# ============================================================================
# VULNERABILITY 3: Missing Security Headers
# ============================================================================
@app.route('/xss')
def xss_test():
    """Reflected XSS vulnerability - no input validation"""
    message = request.args.get('message', 'No message')

    # VULNERABLE: Direct rendering of user input
    return f'''
    <html>
    <body>
        <h1>Message</h1>
        <p>{message}</p>
        <a href="/xss?message=<script>alert('XSS')</script>">Test XSS</a>
    </body>
    </html>
    '''

# ============================================================================
# VULNERABILITY 4: Directory Listing & Sensitive Files
# ============================================================================
@app.route('/backup')
def backup_files():
    """Exposed backup files"""
    files = [
        'config.bak',
        'database.sql.bak',
        'app.config.backup',
        '.env.backup'
    ]
    return f'''
    <html>
    <body>
        <h1>Backup Files</h1>
        <ul>
            {''.join([f"<li><a href='/files/{f}'>{f}</a></li>" for f in files])}
        </ul>
    </body>
    </html>
    '''

@app.route('/files/<filename>')
def get_file(filename):
    """Serves backup files without restriction"""
    backup_content = {
        'config.bak': 'DATABASE_URL=mysql://admin:password123@localhost/db\nAPI_KEY=sk_test_1234567890abcdef',
        'database.sql.bak': 'INSERT INTO users VALUES (1, "admin", "admin123");',
        'app.config.backup': 'DEBUG=True\nSECRET_KEY=super_secret_key_123\nADMIN_EMAIL=admin@example.com',
        '.env.backup': 'API_KEY=supersecretkey\nDB_PASSWORD=password123\nADMIN_TOKEN=token123'
    }

    if filename in backup_content:
        return backup_content[filename], 200, {'Content-Type': 'text/plain'}
    return 'File not found', 404

# ============================================================================
# VULNERABILITY 5: Unrestricted HTTP Methods
# ============================================================================
@app.route('/resource/<resource_id>', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH'])
def resource_endpoint(resource_id):
    """Allows unrestricted HTTP methods"""
    if request.method == 'GET':
        return jsonify({'id': resource_id, 'name': 'Resource', 'data': 'value'})
    elif request.method == 'PUT':
        return jsonify({'message': 'Resource updated', 'id': resource_id})
    elif request.method == 'DELETE':
        return jsonify({'message': 'Resource deleted', 'id': resource_id})
    elif request.method == 'PATCH':
        return jsonify({'message': 'Resource patched', 'id': resource_id})

    return jsonify({'error': 'Method not allowed'}), 405

# ============================================================================
# VULNERABILITY 6: Exposed Configuration & Information Disclosure
# ============================================================================
@app.route('/admin')
def admin_panel():
    """Exposed admin panel with debug info"""
    return f'''
    <html>
    <body>
        <h1>Admin Panel (No Authentication Required!)</h1>
        <p>Flask Debug: {app.config.get("DEBUG")}</p>
        <p>Database Path: {DB_PATH}</p>
        <p>Python Version: {os.popen("python3 --version").read()}</p>
        <p>Server Software: Flask 2.0.1 (Vulnerable Version)</p>
        <hr>
        <h2>Quick Links</h2>
        <ul>
            <li><a href="/api/user/1">Get User 1</a></li>
            <li><a href="/api/user/1 OR 1=1">SQL Injection Test</a></li>
            <li><a href="/search?username=admin&apos; OR &apos;1&apos;=&apos;1">Search with SQL Injection</a></li>
            <li><a href="/api/profile/1">User Profile (IDOR)</a></li>
            <li><a href="/backup">Backup Files</a></li>
        </ul>
    </body>
    </html>
    '''

# ============================================================================
# VULNERABILITY 7: robots.txt & sitemap exposure
# ============================================================================
@app.route('/robots.txt')
def robots():
    """Exposed robots.txt with sensitive paths"""
    return '''User-agent: *
Allow: /
Disallow: /admin
Disallow: /api/
Disallow: /backup
Disallow: /dashboard/
Disallow: /.git

# Sensitive paths accidentally exposed
# /admin/users
# /api/v1/users
# /config
# /database.sql
'''

@app.route('/sitemap.xml')
def sitemap():
    """Exposed sitemap with all endpoints"""
    return '''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    <url><loc>http://localhost/</loc></url>
    <url><loc>http://localhost/login</loc></url>
    <url><loc>http://localhost/admin</loc></url>
    <url><loc>http://localhost/backup</loc></url>
    <url><loc>http://localhost/api/user/1</loc></url>
    <url><loc>http://localhost/api/profile/1</loc></url>
    <url><loc>http://localhost/search</loc></url>
</urlset>
'''

# ============================================================================
# VULNERABILITY 8: .git directory exposure
# ============================================================================
@app.route('/.git/config')
def git_config():
    """Exposed .git directory"""
    return '''[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true
[remote "origin"]
	url = https://github.com/suspect-device/vulnerable-app.git
	fetch = +refs/heads/*:refs/remotes/origin/*
[branch "main"]
	remote = origin
	merge = refs/heads/main
'''

# ============================================================================
# VULNERABILITY 9: Unvalidated Redirects
# ============================================================================
@app.route('/redirect')
def unvalidated_redirect():
    """Unvalidated redirect vulnerability"""
    url = request.args.get('url', '/')
    return redirect(url)

# ============================================================================
# MAIN ROUTES
# ============================================================================
@app.route('/')
def index():
    """Home page with links to vulnerable endpoints"""
    return '''
    <html>
    <head>
        <title>WSTG Vulnerable Application</title>
        <style>
            body { font-family: Arial; margin: 20px; }
            .vulnerability { border: 1px solid red; padding: 10px; margin: 10px 0; }
            a { color: blue; }
        </style>
    </head>
    <body>
        <h1>🔓 WSTG Vulnerable Web Application</h1>
        <p>This application contains intentional vulnerabilities for testing WSTG automation.</p>

        <div class="vulnerability">
            <h3>SQL Injection</h3>
            <ul>
                <li><a href="/api/user/1">/api/user/1</a> - SQL Injection in user lookup</li>
                <li><a href="/search?username=admin">/search</a> - SQL Injection in search</li>
            </ul>
        </div>

        <div class="vulnerability">
            <h3>Weak Authentication & IDOR</h3>
            <ul>
                <li><a href="/login">/login</a> - Weak auth (admin/admin123)</li>
                <li><a href="/api/profile/1">/api/profile/1</a> - IDOR vulnerability</li>
            </ul>
        </div>

        <div class="vulnerability">
            <h3>XSS & Input Validation</h3>
            <ul>
                <li><a href="/xss?message=Hello">/xss</a> - Reflected XSS</li>
            </ul>
        </div>

        <div class="vulnerability">
            <h3>Information Disclosure</h3>
            <ul>
                <li><a href="/admin">/admin</a> - Exposed admin panel</li>
                <li><a href="/backup">/backup</a> - Exposed backup files</li>
                <li><a href="/robots.txt">/robots.txt</a> - Exposed robots.txt</li>
                <li><a href="/sitemap.xml">/sitemap.xml</a> - Exposed sitemap</li>
                <li><a href="/.git/config">/. git/config</a> - Exposed .git directory</li>
            </ul>
        </div>

        <div class="vulnerability">
            <h3>Other Vulnerabilities</h3>
            <ul>
                <li><a href="/resource/123">/resource/123</a> - Unrestricted HTTP methods</li>
                <li><a href="/redirect?url=http://example.com">/redirect</a> - Unvalidated redirect</li>
            </ul>
        </div>
    </body>
    </html>
    '''

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
