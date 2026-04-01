import requests
import sys
import os

# ====== CONFIG ======
DEFECTDOJO_HOST = os.environ.get('DEFECTDOJO_TARGET_IP')
DEFECTDOJO_URL = f"http://{DEFECTDOJO_HOST}:8081/api/v2/import-scan/"
ENGAGEMENT_ID = 1
API_TOKEN = os.environ.get('DEFECTDOJO_API_TOKEN')

headers = {
    "Authorization": f"Token {API_TOKEN}"
}

# ====== FILES TO SCAN WITH THEIR TYPES ======
scans = [
    {"file": "checkov-dockerfile-insecure-report.json", "type": "Checkov Scan"},
    {"file": "checkov-dockerfile-report.json", "type": "Checkov Scan"},
    {"file": "checkov-iac-report.json", "type": "Checkov Scan"},
    {"file": "checkov-secret-report.json", "type": "Checkov Scan"},
    {"file": "dependency-check-report.xml", "type": "Dependency Check Scan"},
    {"file": "gitleaks-report.json", "type": "Gitleaks Scan"},
    {"file": "semgrep-report.json", "type": "Semgrep JSON Report"},
    {"file": "trivy-iac-report.json", "type": "Trivy Scan"},
    {"file": "trivy-image-report.json", "type": "Trivy Scan"},
    {"file": "zap-report.xml", "type": "ZAP Scan"}
]

# ====== LOOP THROUGH FILES ======
for scan in scans:
    file_path = scan["file"]
    scan_type = scan["type"]

    # Check if file exists
    if not os.path.exists(file_path):
        print(f"[!] File not found: {file_path}, skipping...")
        continue

    print(f"[+] Found {file_path}, uploading as {scan_type}...")

    data = {
        "active": True,
        "verified": True,
        "scan_type": scan_type,
        "minimum_severity": "Low",
        "engagement": ENGAGEMENT_ID,
        "close_old_findings": True
    }

    try:
        with open(file_path, "rb") as f:
            files = {"file": f}
            response = requests.post(
                DEFECTDOJO_URL,
                headers=headers,
                data=data,
                files=files,
                timeout=120
            )

        if response.status_code == 201:
            print(f"[✓] {file_path} uploaded successfully")
        else:
            print(f"[✗] Failed to upload {file_path}")
            print(f"Status Code: {response.status_code}")
            print(response.text)

    except requests.exceptions.RequestException as e:
        print(f"[✗] Request failed for {file_path}: {e}")

    print("-" * 60)

print("[+] Script finished")
