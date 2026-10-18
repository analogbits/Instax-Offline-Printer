# Contributing to Instax Offline Printer Suite

Thank you for your interest in contributing to the **Instax Offline Printer Applications Suite**! This project is dedicated to providing 100% offline, privacy-focused, zero-cloud desktop and web tools for Fujifilm instant photo printers.

---

## 🛠️ How to Contribute

### 1. Reporting Bugs
When reporting a bug via GitHub Issues, please use the **Bug Report Template** and provide:
- **Printer Model**: (e.g. Instax Link WIDE, Instax SQUARE Link, Mini Link 2, Instax SHARE SP-2)
- **Host Operating System**: (e.g. macOS 14.5 Sonoma, Windows 11 23H2, Ubuntu 24.04 LTS, iOS 17.5)
- **Application Used**: (e.g. Standalone Desktop App, Web Bluetooth Studio, Python CLI, Lightroom Plugin)
- **Printer Firmware Version**: (Firmware version displayed in the official app, e.g. `0101`)
- **Steps to Reproduce & Terminal / Console Logs** (Press `⌘D` in macOS app or open the Protocol Console in the Web Studio).

### 2. Suggesting Features & Hardware Support
- Open an issue using the **Feature Request Template**.
- If you have access to a new Instax or Polaroid model not yet supported, packet dumps or BLE GATT characteristic UUIDs are immensely helpful.

---

## 💻 Development & Architecture Guidelines

### Single Source of Truth for Web Studios
To prevent version divergence across platforms, all web modifications **must** be made to the canonical files:
- **Modern BLE Studio**: [`Web-Bluetooth-Offline/InstaxPrinterWeb.html`](Web-Bluetooth-Offline/InstaxPrinterWeb.html)
- **Legacy Wi-Fi Direct Studio**: [`Legacy-Instax-Printer/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html`](Legacy-Instax-Printer/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html)

*Do not recreate duplicate HTML files in OS folders (`macOS/`, `Windows/`, `Linux/`). The 1-click OS launchers dynamically point to these canonical studios.*

### Zero External CDN Policy
- All scripts, styles, vector assets, and libraries (e.g. the QR generator) must be self-contained within the repository.
- Never add external network calls, Google Analytics, telemetry scripts, or external CDN dependencies (`<script src="https://...">`).

---

## 🧪 Running Automated Tests

Before submitting a Pull Request, verify that all test suites pass with 0 errors:

```bash
# 1. Run the 8-point Protocol & Syntax Test Suite
python3 test_suite.py

# 2. Run the Headless Interactive GUI Robot Test Suite
python3 test_gui.py
```

Both test suites must report:
```
🎉 ALL TESTS PASSED! (8/8 tests verified)
🎉 ALL GRAPHICAL USER INTERFACE (GUI) TESTS PASSED 100%!
```

---

## 🚀 Submitting a Pull Request (PR)

1. Fork the repository and create your branch from `main`:
   ```bash
   git checkout -b feature/my-new-feature
   ```
2. Commit your changes with clear, descriptive commit messages (following conventional commits, e.g., `feat:`, `fix:`, `docs:`).
3. Ensure the test suites pass 100%.
4. Submit your pull request against the `main` branch.

---

## 📜 Code of Conduct
Please review and adhere to our [Code of Conduct](CODE_OF_CONDUCT.md) in all community interactions.
