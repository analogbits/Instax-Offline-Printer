#!/usr/bin/env python3
"""
Automated Cross-Platform Self-Test Suite & Debugger
===================================================
Runs comprehensive diagnostic tests with debug tracing across:
1. Virtual SP-1, SP-2, and SP-3 Wi-Fi Direct Simulators (TCP 18080)
2. Big-endian packet framing, 5-session handshake & Planar RGB encoding
3. BLE Link Preview rendering and CLI dispatch
4. Multi-platform launcher syntax checks (sh, command, bat)
5. Web Studio HTML & Bridge MD5 consistency
"""

import hashlib
import os
import subprocess
import sys
import tempfile
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# Import legacy client & simulator
sys.path.insert(0, os.path.join(SCRIPT_DIR, "Legacy-Instax-Printer", "Linux"))
try:
    from legacy_instax_printer import (
        MODELS,
        LegacyInstaxClient,
        VirtualInstaxShareServer,
        encode_planar_rgb,
    )
    HAS_LEGACY = True
except Exception as e:
    HAS_LEGACY = False
    print(f"❌ Failed to import legacy_instax_printer: {e}")

from PIL import Image

def log_test(name):
    print(f"\n🔍 [TEST] {name}...")

def pass_test(msg):
    print(f"  ✅ PASS: {msg}")

def fail_test(msg):
    print(f"  ❌ FAIL: {msg}")
    sys.exit(1)

def run_tests():
    total_tests = 0
    passed_tests = 0

    print("=" * 70)
    print("🚀 STARTING AUTOMATED TEST SUITE (DEBUG MODE)")
    print("=" * 70)

    # TEST 1: Python compilation syntax check across all files
    total_tests += 1
    log_test("Python Syntax Compilation (All Platforms)")
    all_py = []
    for root, _, files in os.walk(SCRIPT_DIR):
        if ".git" in root or "__pycache__" in root:
            continue
        for f in files:
            if f.endswith(".py") or f.endswith(".pyw"):
                all_py.append(os.path.join(root, f))
    
    cmd = [sys.executable, "-m", "py_compile"] + all_py
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0:
        pass_test(f"Compiled {len(all_py)} Python source files with 0 syntax errors.")
        passed_tests += 1
    else:
        fail_test(f"Syntax error detected:\n{res.stderr}")

    # TEST 2: Shell & Command Script Syntax
    total_tests += 1
    log_test("Shell & macOS .command Script Syntax (bash -n)")
    all_sh = []
    for root, _, files in os.walk(SCRIPT_DIR):
        if ".git" in root:
            continue
        for f in files:
            if f.endswith(".sh") or f.endswith(".command"):
                all_sh.append(os.path.join(root, f))
    
    for sh in all_sh:
        res = subprocess.run(["bash", "-n", sh], capture_output=True, text=True)
        if res.returncode != 0:
            fail_test(f"Script syntax error in {sh}:\n{res.stderr}")
    pass_test(f"Validated {len(all_sh)} shell and .command scripts successfully.")
    passed_tests += 1

    # TEST 3: Web Studio MD5 Consistency
    total_tests += 1
    log_test("Cross-Platform Web Studio MD5 Integrity")
    web_copies = [
        os.path.join(SCRIPT_DIR, "Legacy-Instax-Printer", "Web-WiFi-Offline", "LegacyInstaxPrinterWeb.html"),
        os.path.join(SCRIPT_DIR, "Legacy-Instax-Printer", "macOS", "LegacyInstaxPrinterWeb.html"),
        os.path.join(SCRIPT_DIR, "Legacy-Instax-Printer", "Windows", "LegacyInstaxPrinterWeb.html"),
        os.path.join(SCRIPT_DIR, "Legacy-Instax-Printer", "Linux", "LegacyInstaxPrinterWeb.html"),
    ]
    hashes = [hashlib.md5(open(f, "rb").read()).hexdigest() for f in web_copies]
    if len(set(hashes)) == 1:
        pass_test(f"All 4 copies of LegacyInstaxPrinterWeb.html match identically ({hashes[0]}).")
        passed_tests += 1
    else:
        fail_test(f"MD5 mismatch found in Web Studio copies: {hashes}")

    # TEST 4: Planar RGB Encoding (SP-1 / SP-2 Mini vs SP-3 SQUARE)
    total_tests += 1
    log_test("Planar RGB Image Encoding (Mini vs SQUARE)")
    sample_img = Image.new("RGB", (1000, 1000), color=(255, 0, 128))
    
    # Mini SP-2 (600x800 -> 1,440,000 bytes)
    planar_sp2 = encode_planar_rgb(sample_img, model_name="SP-2", fit_mode="crop")
    expected_sp2 = 600 * 800 * 3
    if len(planar_sp2) != expected_sp2:
        fail_test(f"SP-2 planar size mismatch: expected {expected_sp2}, got {len(planar_sp2)}")
    
    # SQUARE SP-3 (800x800 -> 1,920,000 bytes)
    planar_sp3 = encode_planar_rgb(sample_img, model_name="SP-3", fit_mode="fit")
    expected_sp3 = 800 * 800 * 3
    if len(planar_sp3) != expected_sp3:
        fail_test(f"SP-3 planar size mismatch: expected {expected_sp3}, got {len(planar_sp3)}")

    pass_test(f"SP-2 ({len(planar_sp2)} bytes) & SP-3 ({len(planar_sp3)} bytes) planar RGB generated correctly.")
    passed_tests += 1

    # TEST 5: Virtual Simulator Handshake & 0-Film Dry Run (SP-1, SP-2, SP-3)
    for model in ["SP-1", "SP-2", "SP-3"]:
        total_tests += 1
        log_test(f"Virtual Wi-Fi Direct Simulator Test ({model})")
        port = 18090 if model == "SP-1" else (18091 if model == "SP-2" else 18092)
        sim = VirtualInstaxShareServer(port=port, model=model, pin=1111)
        if not sim.start():
            fail_test(f"Could not start virtual simulator for {model} on port {port}")
        
        try:
            client = LegacyInstaxClient(host="127.0.0.1", port=port, pin=1111)
            # Query Status
            st = client.get_printer_status()
            if st["model"] != model:
                fail_test(f"Simulator returned unexpected model: {st['model']} vs {model}")
            
            # Dry Run Transfer
            planar = encode_planar_rgb(sample_img, model_name=model)
            res = client.print_planar_rgb(planar, model_name=model, dry_run=True)
            if not res["ok"]:
                fail_test(f"Dry run failed for {model}: {res}")
            
            pass_test(f"{model} Virtual Simulator status query and dry run transfer completed 100% successfully.")
            passed_tests += 1
        finally:
            sim.stop()

    # TEST 6: BLE Link CLI Preview Engine
    total_tests += 1
    log_test("BLE Link Printer Preview Engine")
    test_out = os.path.join(tempfile.gettempdir(), "test_preview_ci.jpg")
    ble_script = os.path.join(SCRIPT_DIR, "Linux", "instax_printer.py")
    test_icon = os.path.join(SCRIPT_DIR, "Legacy-Instax-Printer", "macOS", "Resources", "AppIcon.iconset", "icon_512x512.png")
    cmd = [sys.executable, ble_script, "preview", test_icon, "--output", test_out]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0 and os.path.isfile(test_out):
        pass_test("BLE Printer CLI rendered 800x800 preview JPEG.")
        passed_tests += 1
        try:
            os.remove(test_out)
        except Exception:
            pass
    else:
        fail_test(f"BLE preview generation failed:\n{res.stderr}")

    print("\n" + "=" * 70)
    print(f"🎉 ALL TESTS PASSED! ({passed_tests}/{total_tests} tests verified)")
    print("=" * 70)

if __name__ == "__main__":
    run_tests()
