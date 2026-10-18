# 🔬 Instax Offline Printer Suite — Code Walkthrough & Developer Reference Manual
**Annotated Source Code Explainer, Protocol Math & Algorithmic Deep-Dive**  
*Document Version: 1.7.0 • Standard: Literate / Elucidative Code Specification • Target Release: v1.7.0*

---

## 📑 Table of Contents
1. [Introduction & Repository Structure](#1-introduction--repository-structure)
2. [`instax_printer.py` — Modern BLE Engine Deep-Dive](#2-instax_printerpy--modern-ble-engine-deep-dive)
   - 2.1 [Architecture & Service SIDs](#21-architecture--service-sids)
   - 2.2 [Binary Packet Building & Modulo-256 Checksum](#22-binary-packet-building--modulo-256-checksum)
   - 2.3 [Packet Parsing & Asynchronous Response Stream](#23-packet-parsing--asynchronous-response-stream)
   - 2.4 [Image Chunking & 0-Film Dry-Run Transmission Loop](#24-image-chunking--0-film-dry-run-transmission-loop)
   - 2.5 [CLI Syntax & Command Reference](#25-cli-syntax--command-reference)
   - 2.6 [Pure-PIL Analog Creative FX Pipeline](#26-pure-pil-analog-creative-fx-pipeline)
3. [`legacy_instax_printer.py` — Wi-Fi Direct Engine Deep-Dive](#3-legacy_instax_printerpy--wi-fi-direct-engine-deep-dive)
   - 3.1 [TCP Port 8080 Protocol Architecture](#31-tcp-port-8080-protocol-architecture)
   - 3.2 [Binary Header, PIN Authentication & XOR Checksum](#32-binary-header-pin-authentication--xor-checksum)
   - 3.3 [Planar RGB 90° Scanline Transposition Algorithm](#33-planar-rgb-90-scanline-transposition-algorithm)
   - 3.4 [Segmented Image Transfer Loop (24 vs 32 Segments)](#34-segmented-image-transfer-loop-24-vs-32-segments)
   - 3.5 [Built-in Virtual Instax SHARE Socket Simulator](#35-built-in-virtual-instax-share-socket-simulator)
4. [`instax_wifi_bridge.py` & `legacy_web_bridge.py` — Dual-Radio Bridge](#4-instax_wifi_bridgepy--legacy_web_bridgepy--dual-radio-bridge)
   - 4.1 [LAN IP Discovery & Terminal QR Generation](#41-lan-ip-discovery--terminal-qr-generation)
   - 4.2 [Dual-Radio Wi-Fi to Bluetooth Relay Loop](#42-dual-radio-wi-fi-to-bluetooth-relay-loop)
   - 4.3 [REST API Handlers (`/api/status`, `/api/print`, `/api/scan`)](#43-rest-api-handlers-apistatus-apiprint-apiscan)
5. [`InstaxPrinterWeb.html` & `LegacyInstaxPrinterWeb.html` — Web Studio Engines](#5-instaxprinterwebhtml--legacyinstaxprinterwebhtml--web-studio-engines)
   - 5.1 [HTML5 Canvas 2D Transform & Letterbox Engine](#51-html5-canvas-2d-transform--letterbox-engine)
   - 5.2 [Software Color Science & Film Simulation Curves](#52-software-color-science--film-simulation-curves)
   - 5.3 [Embedded 100% Offline Reed-Solomon QR Generator](#53-embedded-100-offline-reed-solomon-qr-generator)
   - 5.4 [Analog Creative FX & Film Emulation Engine (HTML5 Canvas)](#54-analog-creative-fx--film-emulation-engine-ported-from-polaroidengine)
   - 5.5 [Web Bluetooth API (`navigator.bluetooth`) Engine](#55-web-bluetooth-api-navigatorbluetooth-engine)
6. [`test_suite.py` & `test_gui.py` — Automated Verification](#6-test_suitepy--test_guipy--automated-verification)
   - 6.1 [Protocol Integrity & Planar Encoding Verification (`test_suite.py`)](#61-protocol-integrity--planar-encoding-verification-test_suitepy)
   - 6.2 [Interactive Robot GUI Automation (`test_gui.py`)](#62-interactive-robot-gui-automation-test_guipy)
7. [macOS Native Swift CoreGraphics Analog FX Engine](#7-macos-native-swift-coregraphics-analog-fx-engine)

---

## 1. Introduction & Repository Structure

The **Instax Offline Printer Suite** is organized into cleanly partitioned modules to ensure single-responsibility, cross-platform portability, and maintainability:

```
Instax Offline Printer Applications/
├── Web-Bluetooth-Offline/
│   ├── InstaxPrinterWeb.html        # Canonical Web BLE Studio (Canvas, filters, QR)
│   └── instax_wifi_bridge.py        # Local Wi-Fi HTTP daemon bridging iPhone Safari to BLE
├── Legacy-Instax-Printer/
│   ├── Web-WiFi-Offline/
│   │   ├── LegacyInstaxPrinterWeb.html # Canonical Legacy Web Studio (SP-1/SP-2/SP-3)
│   │   ├── legacy_web_bridge.py        # Local Wi-Fi Direct HTTP daemon for browsers
│   │   └── legacy_instax_printer.py    # Python Wi-Fi Direct TCP 8080 engine & simulator
│   ├── macOS/                       # macOS native Swift app & CLI binary (legacy-instax)
│   ├── Windows/                     # Windows launchers & batch files
│   └── Linux/                       # Linux shell scripts & desktop launchers
├── macOS/                           # macOS native Swift app & CLI binary (instax-square)
├── Windows/                         # Windows standalone .vbs app & instax_printer.py
├── Linux/                           # Linux standalone .sh app & instax_printer.py
├── test_suite.py                    # 8-point protocol & architecture regression test suite
└── test_gui.py                      # Headless Tkinter robot GUI test suite
```

---

## 2. `instax_printer.py` — Modern BLE Engine Deep-Dive

**Target Models**: Instax SQUARE Link (800×800), Link WIDE / WIDE 2 (1260×840), Mini Link 1/2/3/Link+ (600×800).  
**Communication Medium**: Bluetooth Low Energy (GATT).

### 2.1 Architecture & Service SIDs
The engine communicates with three Bluetooth GATT UUIDs under service `70954782-2d83-473d-9e5f-81e1d02d5273`:
- **`WRITE_CHAR_UUID` (`...70954783...`)**: Write without response (transmits command packets and image chunks).
- **`NOTIFY_CHAR_UUID` (`...70954784...`)**: Subscribed notification stream (receives printer acknowledgments, telemetry, and error codes).

#### Service Identifiers (SIDs)
```python
SID_VERSION_INFO = (0x00, 0x00)  # Query firmware version & supported features
SID_DEVICE_INFO  = (0x00, 0x01)  # Query model name string (e.g. "INSTAX-08492048")
SID_SUPPORT_INFO = (0x00, 0x02)  # Query resolution, battery %, film count, status flags
SID_SHUTDOWN     = (0x01, 0x00)  # Power off printer hardware
SID_RESET        = (0x01, 0x01)  # Soft reset printer controller
SID_PRINT_START  = (0x10, 0x00)  # Handshake image download session & declare total bytes
SID_PRINT_DATA   = (0x10, 0x01)  # Stream sequential 1024-byte image chunk
SID_PRINT_END    = (0x10, 0x02)  # Finalize image transfer in printer RAM
SID_PRINT_CANCEL = (0x10, 0x03)  # Abort image download (used in Dry Run mode)
SID_PRINT_EXEC   = (0x10, 0x80)  # Trigger physical film exposure and motor ejection
SID_LED_PATTERN  = (0x30, 0x01)  # Set RGB LED color pulsing pattern
```

---

### 2.2 Binary Packet Building & Modulo-256 Checksum

```python
class InstaxPacket:
    @staticmethod
    def build(sid: Tuple[int, int], payload: bytes = b"") -> bytes:
        total_len = 7 + len(payload)
        hdr = bytes([0x41, 0x62, (total_len >> 8) & 0xFF, total_len & 0xFF, sid[0], sid[1]])
        body = hdr + payload
        chk = (255 - (sum(body) & 0xFF)) & 0xFF
        return body + bytes([chk])
```

#### Line-by-Line Explanation:
1. `total_len = 7 + len(payload)`:
   The total packet length encompasses the 2-byte sync header, 2-byte length, 2-byte SID, the payload itself, and the 1-byte checksum: $2 + 2 + 2 + N + 1 = 7 + N$.
2. `0x41, 0x62`:
   Fixed ASCII synchronizer bytes `'Ab'` (`0x41 0x62`) indicating an outbound host-to-printer command frame.
3. `(total_len >> 8) & 0xFF, total_len & 0xFF`:
   16-bit big-endian representation of `total_len`.
4. `sid[0], sid[1]`:
   Two-byte command Service Identifier (e.g., `0x10, 0x00` for `PrintImageDownloadStart`).
5. `chk = (255 - (sum(body) & 0xFF)) & 0xFF`:
   **Fujifilm Modulo-256 Inverted Checksum**: Sum all bytes in `body` (header + payload), extract the least significant byte (`& 0xFF`), subtract from 255, and clamp to 8 bits. This ensures that:
   $$\left(\sum \text{body} + \text{chk}\right) \pmod{256} = 255 \quad (\text{or } 0 \text{ when inverted})$$
6. `body + bytes([chk])`:
   Appends the calculated checksum byte to the end of the packet.

---

### 2.3 Packet Parsing & Asynchronous Response Stream

```python
    def _on_notify(self, sender, data: bytearray):
        self.rx_buffer.extend(data)
        while len(self.rx_buffer) >= 4:
            # 1. Search for inbound synchronizer bytes 'aB' (0x61, 0x42)
            if self.rx_buffer[0] != 0x61 or self.rx_buffer[1] != 0x42:
                idx = self.rx_buffer.find(b"\x61\x42")
                if idx >= 0:
                    del self.rx_buffer[:idx]
                else:
                    self.rx_buffer.clear()
                    return

            # 2. Extract declared packet length
            pkt_len = (self.rx_buffer[2] << 8) | self.rx_buffer[3]
            if pkt_len < 7 or pkt_len > 4096:
                del self.rx_buffer[:2]
                continue
            if len(self.rx_buffer) < pkt_len:
                return  # Wait for additional BLE GATT notification fragments

            pkt_data = bytes(self.rx_buffer[:pkt_len])
            del self.rx_buffer[:pkt_len]

            # 3. Parse packet structure and fulfill awaiting Future
            parsed = InstaxPacket.parse(pkt_data)
            if parsed and self.response_future and not self.response_future.done():
                if self.pending_sid is None or parsed["sid"] == self.pending_sid:
                    self.response_future.set_result(parsed)
```

#### Line-by-Line Explanation:
1. `rx_buffer.extend(data)`:
   Because Bluetooth Low Energy packets are often fragmented across multiple 20-byte or 180-byte MTU notifications, incoming chunks are appended to a persistent FIFO buffer.
2. `b"\x61\x42"`:
   The printer replies with inverted ASCII synchronizer bytes `'aB'` (`0x61 0x42`), distinguishing responses from outbound commands (`'Ab'`).
3. `pkt_len = (self.rx_buffer[2] << 8) | self.rx_buffer[3]`:
   Reads the 16-bit big-endian length. If fewer bytes have arrived than declared in `pkt_len`, execution returns early to await the remaining BLE notifications.
4. `self.response_future.set_result(parsed)`:
   Resolves Python's `asyncio.Future`, waking the awaiting `send_command()` coroutine with the parsed response payload.

---

### 2.4 Image Chunking & 0-Film Dry-Run Transmission Loop

```python
    async def print_image(self, jpeg_data: bytes, mode: str = "rich", dry_run: bool = False, progress_cb = None):
        st = await self.fetch_status()
        if not dry_run and st.film_remaining <= 0:
            raise RuntimeError("No film remaining (0/10) in printer cartridge.")

        total_bytes = len(jpeg_data)
        frame_sz = st.chunk_size if st.chunk_size > 0 else 1808

        # 1. Initiate download handshake declaring total file byte length
        start_payload = struct.pack(">BBBB I", 0x02, 0x00, 0x00, 0x00, total_bytes)
        r = await self.send_command(SID_PRINT_START, start_payload, timeout=12.0)
        if r["res_code"] != 0:
            raise RuntimeError(f"PRINT_IMAGE_DOWNLOAD_START rejected: code 0x{r['res_code']:02X}")

        # 2. Iterate and transmit sequential image chunks
        tot_frames = (total_bytes + frame_sz - 1) // frame_sz
        for seq in range(tot_frames):
            start_idx = seq * frame_sz
            end_idx = min(start_idx + frame_sz, total_bytes)
            chunk = bytearray(jpeg_data[start_idx:end_idx])
            if len(chunk) < frame_sz:
                chunk.extend(b"\x00" * (frame_sz - len(chunk)))  # Zero-pad final chunk

            payload = struct.pack(">I", seq) + bytes(chunk)
            res = await self.send_command(SID_PRINT_DATA, payload, timeout=15.0)
            if res["res_code"] != 0:
                raise RuntimeError(f"Packet {seq + 1}/{tot_frames} rejected: code 0x{res['res_code']:02X}")

        # 3. Finalize download in printer ASIC buffer
        await self.send_command(SID_PRINT_END, b"", timeout=10.0)

        # 4. Handle Dry Run vs Physical Print Motor Trigger
        if dry_run:
            self.log("[DRY-RUN] ✅ 100% data delivered to printer RAM! Canceling before motor trigger (0 film used).")
            await self.send_command(SID_PRINT_CANCEL, b"", timeout=4.0)
            return await self.fetch_status()

        # 5. Trigger Physical Exposure & Film Ejection
        r = await self.send_command(SID_PRINT_EXEC, b"", timeout=15.0)
        wait_s = st.wait_seconds
        await asyncio.sleep(max(wait_s, 15))
```

#### Line-by-Line Explanation:
1. `start_payload = struct.pack(">BBBB I", 0x02, 0x00, 0x00, 0x00, total_bytes)`:
   Formats the session start command: `0x02` (JPEG format), option flags, and a 32-bit big-endian unsigned integer representing the exact JPEG file size.
2. `payload = struct.pack(">I", seq) + bytes(chunk)`:
   Each chunk packet prefixes the raw JPEG slice with a 32-bit sequential sequence index `seq` ($0, 1, 2 \dots$).
3. `chunk.extend(b"\x00" * (frame_sz - len(chunk)))`:
   The printer hardware expects exact uniform chunk sizes (typically 1808 or 1024 bytes). The final fragment is zero-padded to prevent buffer read errors.
4. **0-Film Dry-Run Safety**:
   When `dry_run=True`, the entire image is transmitted and verified by the printer's onboard RAM. Then, instead of issuing `SID_PRINT_EXEC` (`0x10 0x80`), the engine immediately issues `SID_PRINT_CANCEL` (`0x10 0x03`). The printer clears its buffer with **zero mechanical motion and zero film expended**.

---

### 2.5 CLI Syntax & Command Reference

```bash
# Query hardware telemetry (battery %, film count, resolution)
python3 instax_printer.py status

# Print image with custom fit mode and 90-degree rotation
python3 instax_printer.py print photo.jpg --model wide --fit fit --rotate 90

# Non-destructive 0-film dry-run test
python3 instax_printer.py print photo.jpg --model square --dry-run

# Multi-Photo Collage with custom background border color
python3 instax_printer.py print img1.jpg img2.jpg img3.jpg img4.jpg --model square --collage grid4 --border-color "#FFE4E1"

# Launch local Wi-Fi Bluetooth Bridge server for iPhone Safari
python3 instax_printer.py serve --port 8765

# Print with Analog Creative FX (warmth, light leaks, film grain, LED date stamp)
python3 instax_printer.py print photo.jpg --model wide --warmth 0.35 --vignette 0.4 --light-leak burn --grain 0.25 --date "'98 10 24"
```

---

### 2.6 Pure-PIL Analog Creative FX Pipeline

The cross-platform Python desktop engine (`instax_printer.py`) implements a zero-dependency Pillow/PIL pipeline with mathematical equivalence to the Web Studio's HTML5 Canvas compositing:

```python
def apply_analog_fx(
    canvas: Image.Image,
    warmth: float = 0.0,
    vignette: float = 0.0,
    light_leak: str = "none",
    leak_placement: str = "auto",
    leak_intensity: float = 0.70,
    film_grain: float = 0.0,
    analog_wear: float = 0.0,
    show_vintage_date: bool = False,
    vintage_date_text: str = "",
    vintage_date_color: str = "amber",
    vintage_date_placement: str = "bottomRight",
) -> Image.Image:
    # 1. Warmth color shift using PIL Image.blend
    # 2. Radial lens vignette falloff with ImageChops.multiply
    # 3. Light leak gradient synthesis (burn, sunburst, sunset, rainbow) via ImageChops.screen
    # 4. Procedural silver halide grain via ImageChops.overlay
    # 5. Deterministic wear, dust motes & scratches with seeded LCG PRNG
    # 6. Vintage LED glow date stamp with multi-pass diffused stroke rendering
```

#### Mathematical & Algorithmic Notes:
1. **Light Leak Screen Blending**: `ImageChops.screen(A, B)` implements $1 - (1 - A)(1 - B)$, ensuring that optical intrusions illuminate shadows and midtones organically without clipping highlights.
2. **Deterministic Seed Stability**: The pseudo-random generator uses an exact linear congruential generator seed ($S_{n+1} = (1103515245 \cdot S_n + 12345) \pmod{2^{31}}$) so that dust motes and scratches remain locked in place as the user adjusts intensity sliders.
3. **Diffused LED Glow**: Simulates photographic light blooming in darkroom emulsions by rendering concentric outer offsets ($dx, dy \in [-2..2]$) at reduced alpha before printing the crisp core digital numerals.

---

## 3. `legacy_instax_printer.py` — Wi-Fi Direct Engine Deep-Dive

**Target Models**: Instax SHARE SP-1 (600×800), Instax SHARE SP-2 (600×800), Instax SHARE SP-3 (800×800).  
**Communication Medium**: IEEE 802.11 Wi-Fi Direct raw TCP socket (`192.168.0.251:8080`).

### 3.1 TCP Port 8080 Protocol Architecture
Unlike the BLE Link series, the Instax SHARE family communicates over raw, unencrypted TCP stream sockets on port 8080. The printer operates as an access point assigning host machines IP `192.168.0.x` via DHCP.

---

### 3.2 Binary Header, PIN Authentication & XOR Checksum

```python
def build_command_packet(cmd_type: int, session_time: int, pin_code: int = 1111, payload: bytes = b"") -> bytes:
    total_len = 16 + len(payload)
    header = struct.pack(
        ">BBHIHH",
        0x24,                     # Mode byte (0x24 = command mode)
        cmd_type & 0xFF,          # Command Type (e.g. 0x51 prep, 0x52 send, 0x53 print)
        total_len & 0xFFFF,       # 16-bit total packet byte length
        session_time & 0xFFFFFFFF,# 32-bit Unix epoch session timestamp
        pin_code & 0xFFFF,        # 16-bit numeric PIN (0x0457 = 1111)
        0x0000,                   # Reserved / padding
    )
    body = header + payload
    chk = (sum(body) ^ 0xFFFF) & 0xFFFF  # Bitwise XOR inverted checksum
    trailer = struct.pack(">HBB", chk, 0x0D, 0x0A)  # 16-bit checksum + \r\n (0x0D 0x0A)
    return body + trailer
```

#### Line-by-Line Explanation:
1. `0x24`: Fixed mode byte identifying an active client command (responses return with mode byte `0x2A` = 42).
2. `session_time`: 32-bit integer timestamp preventing replay packet collisions.
3. `pin_code & 0xFFFF`: The 4-digit PIN is stored as a raw 16-bit integer (e.g., default `1111` is represented as hex `0x0457`).
4. `chk = (sum(body) ^ 0xFFFF) & 0xFFFF`:
   **Fujifilm 16-Bit XOR Checksum**: Sums every byte in the 16-byte header plus payload, and bitwise XORs the resulting accumulator against `0xFFFF`.
5. `0x0D, 0x0A`:
   Trailing carriage-return / newline delimiters (`\r\n`) expected by the hardware parser.

---

### 3.3 Planar RGB 90° Scanline Transposition Algorithm

```python
def encode_planar_rgb(pil_image: "Image.Image", model_name: str = "SP-2", fit_mode: str = "crop") -> bytes:
    spec = MODELS.get(model_name.upper(), MODELS["SP-2"])
    portrait_w, portrait_h = spec["width"], spec["height"]  # e.g. 600, 800
    img = pil_image.convert("RGB")

    # 1. Scale and crop/letterbox to exact portrait dimensions
    if fit_mode == "fit":
        img.thumbnail((portrait_w, portrait_h), Image.Resampling.LANCZOS)
        framed = Image.new("RGB", (portrait_w, portrait_h), (255, 255, 255))
        ox = (portrait_w - img.width) // 2
        oy = (portrait_h - img.height) // 2
        framed.paste(img, (ox, oy))
        img = framed
    else:
        # Fill canvas with center crop
        iw, ih = img.size
        scale = max(portrait_w / iw, portrait_h / ih)
        new_w, new_h = int(iw * scale), int(ih * scale)
        img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        left = (new_w - portrait_w) // 2
        top = (new_h - portrait_h) // 2
        img = img.crop((left, top, left + portrait_w, top + portrait_h))

    # 2. Rotate 90° clockwise: print_w becomes 800 scanlines, print_h becomes 600 dots
    img = img.rotate(-90, expand=True)
    print_w, print_h = img.size  # print_w = 800, print_h = 600

    # 3. Transpose row-major interleaved RGB into column-major planar scanlines
    raw_rgb = img.tobytes()
    planar = bytearray(print_w * print_h * 3)
    for h in range(print_h):
        row_offset = h * print_w * 3
        for w in range(print_w):
            px = row_offset + w * 3
            col_base = w * print_h * 3
            planar[col_base + h] = raw_rgb[px]                       # Red plane
            planar[col_base + print_h + h] = raw_rgb[px + 1]         # Green plane
            planar[col_base + (print_h * 2) + h] = raw_rgb[px + 2]   # Blue plane

    return bytes(planar)
```

#### Mathematical Transposition Proof:
- A standard image is stored row-by-row: `(R, G, B), (R, G, B)...`
- An Instax SHARE physical thermal exposure carriage sweeps across the film in **800 distinct scanline columns**.
- At each scanline column $w$, the print head expects all Red dots for that column, followed by all Green dots, followed by all Blue dots:
$$\text{Scanline}_w = \left[ R_0, R_1, \dots, R_{H-1} \right] \mathbin{\Vert} \left[ G_0, G_1, \dots, G_{H-1} \right] \mathbin{\Vert} \left[ B_0, B_1, \dots, B_{H-1} \right]$$
- Total byte footprint:
  - Mini (SP-1 / SP-2): $600 \times 800 \times 3 = 1,440,000 \text{ bytes}$.
  - SQUARE (SP-3): $800 \times 800 \times 3 = 1,920,000 \text{ bytes}$.

---

### 3.4 Segmented Image Transfer Loop (24 vs 32 Segments)

```python
    def print_planar_rgb(self, planar_data: bytes, model_name: str = "SP-2", dry_run: bool = False):
        spec = MODELS.get(model_name.upper(), MODELS["SP-2"])
        seg_size = spec["segment_size"]   # Fixed 60,000 bytes per segment
        tot_segments = spec["segments"]   # 24 for SP-1/SP-2, 32 for SP-3

        # 1. Connect TCP socket to 192.168.0.251:8080
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(12.0)
        s.connect((self.host, self.port))

        # 2. CMD_PREP_IMAGE (0x51)
        prep_payload = struct.pack(">BHI", 0x01, spec["height"], len(planar_data))
        s.sendall(build_command_packet(CMD_PREP_IMAGE, int(time.time()), self.pin, prep_payload))
        resp = parse_response_packet(s.recv(1024))
        if resp["return_code"] != 0:
            raise RuntimeError(f"Preparation rejected: {resp['return_label']}")

        # 3. Stream planar segments (CMD_SEND_IMAGE 0x52)
        for seg_idx in range(tot_segments):
            start = seg_idx * seg_size
            end = start + seg_size
            chunk = planar_data[start:end]

            # Payload header: 1-byte flag, 1-byte segment index (0..23), 2-byte chunk length
            chunk_hdr = struct.pack(">BBH", 0x00, seg_idx, len(chunk))
            pkt = build_command_packet(CMD_SEND_IMAGE, int(time.time()), self.pin, chunk_hdr + chunk)
            s.sendall(pkt)
            seg_resp = parse_response_packet(s.recv(1024))
            if seg_resp["return_code"] != 0:
                raise RuntimeError(f"Segment {seg_idx + 1}/{tot_segments} failed: {seg_resp['return_label']}")

        # 4. Dry Run vs Motor Ejection (CMD_TRIGGER_PRINT 0x53)
        if dry_run:
            s.sendall(build_command_packet(CMD_RESET, int(time.time()), self.pin))
            return {"ok": True, "dry_run": True, "msg": "All segments verified in RAM!"}

        s.sendall(build_command_packet(CMD_TRIGGER_PRINT, int(time.time()), self.pin))
        final_resp = parse_response_packet(s.recv(1024))
        return {"ok": final_resp["return_code"] == 0}
```

---

### 3.5 Built-in Virtual Instax SHARE Socket Simulator

```python
class VirtualInstaxShareServer:
    def __init__(self, port: int = 18080, model: str = "SP-2", pin: int = 1111):
        self.port = port
        self.model = model
        self.pin = pin
        self.film_remaining = 8
        self.battery_level = 4
        self.total_prints = 128
        self._running = False

    def start(self) -> bool:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(("127.0.0.1", self.port))
        s.listen(8)
        self._sock = s
        self._running = True
        threading.Thread(target=self._accept_loop, daemon=True).start()
        return True
```

The virtual simulator binds to `127.0.0.1:18080` and faithfully replicates all binary protocol responses (Specifications, Status, PIN checking, Segment transfers, and Reset). This enables developers and automated CI suites to verify 100% of the transmission stack without requiring physical hardware or consuming instant film.

---

## 4. `instax_wifi_bridge.py` & `legacy_web_bridge.py` — Dual-Radio Bridge

### 4.1 LAN IP Discovery & Terminal QR Generation

```python
def get_lan_ip() -> str:
    try:
        # Probe default route by connecting UDP socket to router without sending data
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("192.168.1.1", 80))
        ip = s.getsockname()[0]
        s.close()
        if ip and not ip.startswith("127."):
            return ip
    except Exception:
        pass
    return "127.0.0.1"
```

The script determines the machine's primary local IP address without making external DNS requests. It then generates an ASCII QR code directly in the terminal window, enabling users to scan with an iPhone camera and open `http://192.168.1.x:8765` instantly.

---

### 4.2 Dual-Radio Wi-Fi to Bluetooth Relay Loop
The bridge implements an asynchronous producer-consumer loop:
1. **Radio 1 (Wi-Fi)**: Built-in `ThreadingHTTPServer` receives high-resolution image uploads from iPhone Safari over the home Wi-Fi network.
2. **RAM Staging**: Decodes the base64 JPEG payload into a memory buffer.
3. **Radio 2 (Bluetooth)**: Spawns the BLE engine (`instax_printer.py` or native `instax-square`), streaming the image chunks over Bluetooth GATT characteristics to the physical Instax printer.

---

### 4.3 REST API Handlers (`/api/status`, `/api/print`, `/api/scan`)

```python
    def do_POST(self):
        if self.path == "/api/print":
            content_len = int(self.headers.get("Content-Length", 0))
            post_body = self.rfile.read(content_len)
            payload = json.loads(post_body.decode("utf-8"))

            img_bytes = base64.b64decode(payload["image_base64"].split(",", 1)[1])
            model = payload.get("model", "square")
            dry_run = bool(payload.get("dry_run", False))

            # Dispatch print job to hardware via CLI
            tmp_path = "/tmp/print_job.jpg"
            with open(tmp_path, "wb") as f:
                f.write(img_bytes)

            args = ["print", tmp_path, "--model", model]
            if dry_run:
                args.append("--dry-run")
            cmd = find_cli_command(args)
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=60)

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"ok": proc.returncode == 0, "log": proc.stdout}).encode())
```

---

## 5. `InstaxPrinterWeb.html` & `LegacyInstaxPrinterWeb.html` — Web Studio Engines

### 5.1 HTML5 Canvas 2D Transform & Letterbox Engine

```javascript
function renderCanvas() {
  const minDim = Math.min(canvas.width, canvas.height);
  ctx.save();
  ctx.fillStyle = document.getElementById('bgColorPicker').value;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  if (loadedImage) {
    const fit = document.getElementById('fitMode').value;
    const zoom = parseFloat(document.getElementById('sliderZoom').value);
    const panX = parseFloat(document.getElementById('sliderPanX').value) * (canvas.width / 2);
    const panY = parseFloat(document.getElementById('sliderPanY').value) * (canvas.height / 2);

    let scale = (fit === 'fit')
      ? Math.min(canvas.width / loadedImage.width, canvas.height / loadedImage.height) * zoom
      : Math.max(canvas.width / loadedImage.width, canvas.height / loadedImage.height) * zoom;

    const drawW = loadedImage.width * scale;
    const drawH = loadedImage.height * scale;

    ctx.translate(canvas.width / 2 + panX, canvas.height / 2 + panY);
    ctx.rotate((currentRotation * Math.PI) / 180);
    ctx.drawImage(loadedImage, -drawW / 2, -drawH / 2, drawW, drawH);
  }
  ctx.restore();
}
```

---

### 5.2 Software Color Science & Film Simulation Curves

To guarantee identical visual output across platforms without relying on browser-specific CSS filters, the web studio implements a direct **ImageData pixel buffer transformation**:

```javascript
function applySoftwareFilters(targetCtx, w, h) {
  const preset = document.getElementById('filterPreset').value;
  const imgData = targetCtx.getImageData(0, 0, w, h);
  const d = imgData.data;

  for (let i = 0; i < d.length; i += 4) {
    let r = d[i], g = d[i + 1], b = d[i + 2];

    if (preset === 'vivid') {
      // Saturation boost via RGB to HSV chrominance expansion
      const max = Math.max(r, g, b), min = Math.min(r, g, b);
      const delta = max - min;
      if (max > 0) {
        d[i]     = Math.min(255, r + (r - min) * 0.35);
        d[i + 1] = Math.min(255, g + (g - min) * 0.35);
        d[i + 2] = Math.min(255, b + (b - min) * 0.35);
      }
    } else if (preset === 'mono') {
      // Rec.601 Luminance Weights
      const lum = 0.299 * r + 0.587 * g + 0.114 * b;
      d[i] = d[i + 1] = d[i + 2] = lum;
    } else if (preset === 'sepia') {
      // Warm vintage matrix
      d[i]     = Math.min(255, (r * 0.393) + (g * 0.769) + (b * 0.189));
      d[i + 1] = Math.min(255, (r * 0.349) + (g * 0.686) + (b * 0.168));
      d[i + 2] = Math.min(255, (r * 0.272) + (g * 0.534) + (b * 0.131));
    }
  }
  targetCtx.putImageData(imgData, 0, 0);
}
```

---

### 5.3 Embedded 100% Offline Reed-Solomon QR Generator

```javascript
function drawQRBadge(targetCtx, text, x, y, size, style) {
  const qr = qrcode(0, 'M');  // Level M (15% error recovery)
  qr.addData(text);
  qr.make();
  const count = qr.getModuleCount();
  const pad = 10;
  const badgeX = x - pad, badgeY = y - pad;
  const badgeW = size + pad * 2, badgeH = size + pad * 2;

  targetCtx.save();
  // Draw styled background card
  if (style === 'frosted') {
    targetCtx.fillStyle = 'rgba(255, 255, 255, 0.92)';
    targetCtx.beginPath();
    targetCtx.roundRect(badgeX, badgeY, badgeW, badgeH, 12);
    targetCtx.fill();
    targetCtx.strokeStyle = 'rgba(0, 0, 0, 0.15)';
    targetCtx.stroke();
  }

  // Draw QR code matrix cells
  const cellSize = size / count;
  targetCtx.fillStyle = (style === 'minimal') ? '#ffffff' : '#000000';
  for (let r = 0; r < count; r++) {
    for (let c = 0; c < count; c++) {
      if (qr.isDark(r, c)) {
        targetCtx.fillRect(
          Math.round(x + c * cellSize),
          Math.round(y + r * cellSize),
          Math.ceil(cellSize),
          Math.ceil(cellSize)
        );
      }
    }
  }
  targetCtx.restore();
}
```

#### Line-by-Line Explanation:
1. `qrcode(0, 'M')`:
   Instantiates the embedded pure-JavaScript QR generator with auto-detecting version size (`0`) and Medium error correction (`'M'`), allowing up to 15% physical damage or film grain noise without loss of scannability.
2. `roundRect(badgeX, badgeY, badgeW, badgeH, 12)`:
   Renders rounded badge borders that aesthetically blend with instant photo aesthetics.
3. `qr.isDark(r, c)`:
   Queries the Boolean bit matrix calculated by the Reed-Solomon generator and renders crisp, anti-aliased square modules on the Canvas.

---

### 5.4 Analog Creative FX & Film Emulation Engine (Ported from PolaroidEngine)

The Analog FX tab introduces physical darkroom chemistry emulation ported directly from the Objective-C `PolaroidEngine`:

```javascript
// Warmth / Temperature Adjustment (-1.0 Cool to +1.0 Golden Amber)
function applyAnalogWarmth(targetCtx, x, y, w, h, warmth) {
  if (Math.abs(warmth) < 0.01) return;
  targetCtx.save();
  targetCtx.beginPath();
  targetCtx.rect(x, y, w, h);
  targetCtx.clip();
  targetCtx.globalCompositeOperation = 'soft-light';
  targetCtx.fillStyle = (warmth > 0)
    ? `rgba(255, 175, 45, ${Math.min(1.0, warmth * 0.65)})`
    : `rgba(45, 135, 255, ${Math.min(1.0, (-warmth) * 0.65)})`;
  targetCtx.fillRect(x, y, w, h);
  targetCtx.restore();
}

// Light Leak Blending (Screen Blend Mode)
function drawLightLeakEffect(targetCtx, x, y, w, h, type, placement, intensity, seed) {
  if (!type || type === 'none' || intensity <= 0.01) return;
  targetCtx.save();
  targetCtx.beginPath();
  targetCtx.rect(x, y, w, h);
  targetCtx.clip();
  targetCtx.globalCompositeOperation = 'screen';
  targetCtx.globalAlpha = Math.min(1.0, intensity);
  // Draws smooth multi-stop linear/radial gradients for burn, sunburst, sunset, and prismatic rainbow
  targetCtx.restore();
}
```

#### Line-by-Line Explanation:
1. `globalCompositeOperation = 'soft-light'`:
   Blends golden amber (`#FFAF2D`) or cool arctic blue (`#2D87FF`) color washes non-destructively into the midtones and highlights, mimicking physical silver halide temperature shifts.
2. `globalCompositeOperation = 'screen'`:
   Light leaks are optical intrusions of light into unexposed film; using `screen` compositing ensures the leak only lightens the underlying scene naturally without clamping shadows to muddy grays.
3. `drawTactileFilmGrain`:
   Employs an offscreen procedural noise canvas blended with `overlay` at `intensity * 0.85` to give physical texture and crystal grain presence without blurring upon downsampling.
4. `drawAnalogWear`:
   Uses a seeded linear congruential pseudo-random generator (LCG) to deterministically generate curved fibers, hairline scratches, fine dust motes, and a chemical roller spread gradient that stay stable as sliders are adjusted.
5. `drawVintageDateStamp`:
   Renders authentic 90s monospaced digital LED datestamps (`'YY MM DD`) with custom color glow halos (`shadowColor` + `shadowBlur: 6`) in Amber Gold (`#FF8C00`), Ruby Red (`#FF2525`), Emerald Green (`#00E676`), or Crisp White (`#F5F5F7`).

---

### 5.5 Web Bluetooth API (`navigator.bluetooth`) Engine

```javascript
async function connectBluetooth() {
  const device = await navigator.bluetooth.requestDevice({
    filters: [{ namePrefix: "INSTAX-" }],
    optionalServices: ["70954782-2d83-473d-9e5f-81e1d02d5273"]
  });

  const server = await device.gatt.connect();
  const service = await server.getPrimaryService("70954782-2d83-473d-9e5f-81e1d02d5273");
  writeChar = await service.getCharacteristic("70954783-2d83-473d-9e5f-81e1d02d5273");
  notifyChar = await service.getCharacteristic("70954784-2d83-473d-9e5f-81e1d02d5273");

  await notifyChar.startNotifications();
  notifyChar.addEventListener('characteristicvaluechanged', onBLEDataReceived);
}
```

---

## 6. `test_suite.py` & `test_gui.py` — Automated Verification

### 6.1 Protocol Integrity & Planar Encoding Verification (`test_suite.py`)
`test_suite.py` provides continuous regression testing without external dependencies:

```python
    # TEST 4: Planar RGB Encoding (Mini vs SQUARE)
    sample_img = Image.new("RGB", (1000, 1000), color=(255, 0, 128))
    
    # Mini SP-2 (600x800 -> 1,440,000 bytes)
    planar_sp2 = encode_planar_rgb(sample_img, model_name="SP-2", fit_mode="crop")
    assert len(planar_sp2) == 600 * 800 * 3, "SP-2 byte size mismatch!"

    # SQUARE SP-3 (800x800 -> 1,920,000 bytes)
    planar_sp3 = encode_planar_rgb(sample_img, model_name="SP-3", fit_mode="fit")
    assert len(planar_sp3) == 800 * 800 * 3, "SP-3 byte size mismatch!"
```

---

### 6.2 Interactive Robot GUI Automation (`test_gui.py`)
`test_gui.py` executes headless event-driven UI automation:

```python
    # Robot simulates user actions in Tkinter loop
    app.model_combo.set("SP-3")
    app.action_model_change(None)
    assert app.canvas["width"] == 800 and app.canvas["height"] == 800

    # Simulate checking 'Virtual SP Simulator'
    app.sim_var.set(True)
    app.toggle_simulator()
    assert app.virtual_sim and app.virtual_sim._running

    # Simulate 0-Film Dry Run click
    app.action_dry_run()
```

---

## 7. macOS Native Swift CoreGraphics Analog FX Engine

In the macOS native Swift desktop applications (`InstaxSquareCore.swift` and `LegacyInstaxCore.swift`), Analog Creative FX are implemented natively using Apple's high-performance `CoreGraphics` and `Accelerate` frameworks:

```swift
// Lens Vignette via CoreGraphics Radial Shading
static func drawLensVignette(in ctx: CGContext, rect: CGRect, intensity: Double) {
    guard intensity > 0.01 else { return }
    let colors = [
        NSColor(white: 0.0, alpha: 0.0).cgColor,
        NSColor(white: 0.0, alpha: CGFloat(intensity * 0.85)).cgColor
    ] as CFArray
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) else { return }
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = hypot(rect.width, rect.height) / 2.0
    ctx.drawRadialGradient(gradient, startCenter: center, startRadius: radius * 0.2,
                           endCenter: center, endRadius: radius, options: .drawsAfterEndLocation)
}

// Optical Light Leaks via Screen Blend Mode
static func drawLightLeakEffect(in ctx: CGContext, rect: CGRect, type: String, placement: String, intensity: Double, seed: Int) {
    guard type != "none" && intensity > 0.01 else { return }
    ctx.saveGState()
    ctx.setBlendMode(.screen)
    ctx.setAlpha(CGFloat(intensity))
    // Render multi-stop axial or radial gradients matching the chosen leak palette (burn, sunburst, sunset, rainbow)
    ctx.restoreGState()
}
```

#### macOS Architectural Highlights:
1. **Hardware-Accelerated Compositing**: CoreGraphics renders directly on macOS Quartz compositor with metal backends, ensuring instantaneous 60 FPS previews even when scrubbing sliders.
2. **Strict Paper Boundary Letterboxing**: When letterboxing rectangular images on square or wide film, all analog effects, wear, grain, and leaks are clipped strictly to the active photo rect (`ctx.clip(to: drawRect)`), keeping pristine white or black film borders completely untouched.
3. **Typography & Glow Simulation**: Date stamps utilize `CTFont` / `NSFont.monospacedDigitSystemFont` with `ctx.setShadow(offset: .zero, blur: 6.0, color: glowColor)` for authentic 1990s LED display reproduction.

---

*Authored by the Instax Offline Printer Open Source Team • Licensed under the MIT License • Published at https://github.com/analogbits/Instax-Offline-Printer*
