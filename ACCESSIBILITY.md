# Accessibility Statement for Instax Offline Printer Suite

We are committed to ensuring digital accessibility for all users, including photographers and creators with disabilities. We continually improve the user experience across all standalone desktop applications and offline web studios.

---

## 🎨 High-Contrast & Visual Design
- **High-Contrast Dark Theme**: The desktop applications and web studios feature deep dark backgrounds (`#0a0b0e` / `#121318`) with bright foreground text (`#ffffff` / `#e2e8f0`), exceeding WCAG 2.1 AAA contrast ratios (greater than 7:1) for readability.
- **Colorblind-Friendly Indicators**:
  - Telemetry gauges use both distinct color cues and explicit text labels (e.g. `🟢 Battery: 80% (3/4)` and `10/10 Film`).
  - Active tabs use distinct border outlines and background fills, not color alone.
- **Scalable Framing Controls**: All framing, rotation, and letterboxing controls provide both interactive mouse/touch drag-and-drop gestures and high-precision range sliders with real-time numeric readout values.

---

## ⌨️ Keyboard Navigation & Shortcuts

### macOS Native Application
- `⌘ O`: Open image file from disk.
- `⌘ D`: Toggle protocol debug console drawer.
- `⌘ ?`: Open built-in offline help and user guide.
- `Tab` / `Shift+Tab`: Navigate between model selectors, buttons, and framing sliders.
- `Space` / `Return`: Trigger selected buttons (Print, Dry Run, Connect).

### Web Studios & Cross-Platform GUIs
- Standard `Tab` keyboard focus rings on all interactive form inputs, sliders, and buttons.
- Arrow keys allow 1-pixel precision panning and 1% increment zoom adjustments.

---

## 🛠️ Assistive Technologies
- Form controls, dropdowns, and file upload buttons are mapped to standard semantic HTML5 elements (`<input>`, `<select>`, `<button>`) with clear `aria-label` and `title` tags for screen readers (VoiceOver on macOS, NVDA on Windows, Orca on Linux).

---

## 📬 Feedback & Reporting Barriers
If you encounter any accessibility barriers while using the Instax Offline Printer suite, please file an issue on GitHub using the **Bug Report** template or start a discussion. We welcome feedback to make instant photo printing accessible to everyone.
