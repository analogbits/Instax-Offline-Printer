# Security Policy

## 🔒 100% Offline & Privacy-First Architecture

The **Instax Offline Printer Applications Suite** is engineered with a strict **airgap security philosophy**:
* **No Telemetry**: The applications contain zero analytics, zero trackers, and zero metrics-gathering code.
* **No Cloud Connections**: Images, passwords, and photo metadata never leave your local machine or local Wi-Fi network.
* **Direct Hardware Communication**: All data exchanges occur strictly over local Bluetooth Low Energy GATT characteristics or local Wi-Fi Direct TCP sockets (`192.168.0.251:8080`).

---

## 🛡️ Supported Versions

| Version | Supported |
| :--- | :---: |
| 1.6.x (Latest) | ✅ |
| < 1.6.0 | ❌ |

We encourage all users to run the latest release tag to ensure all hardware timing and buffer fixes are active.

---

## 🚨 Reporting a Vulnerability

If you discover a potential security vulnerability (e.g., in local socket binding, buffer handling, or input validation):

1. **Do not disclose publicly** in open GitHub issues or discussions.
2. Report the vulnerability privately via **GitHub Private Vulnerability Reporting** on the repository:
   - Navigate to **Security** $\to$ **Advisories** $\to$ **Report a vulnerability**.
   - Alternatively, open a private issue or contact the maintainer via GitHub.
3. Please include:
   - Description of the issue and potential impact
   - Minimal reproduction script or command
   - Proposed remediation, if known

We take security seriously and will investigate and patch verified issues promptly.
