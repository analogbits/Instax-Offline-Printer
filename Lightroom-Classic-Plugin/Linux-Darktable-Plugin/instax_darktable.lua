--[[
  Instax Offline Printer — Darktable Lua Export Plugin (Linux, Windows, macOS)
  ============================================================================
  Adds "Instax Offline Printer (BLE & Wi-Fi Direct)" directly into Darktable's
  Export module ("target storage" dropdown).

  Installation on Linux / macOS:
    1. Copy this file to ~/.config/darktable/lua/contrib/instax_darktable.lua
    2. Add `require "contrib/instax_darktable"` to ~/.config/darktable/luarc
]]

local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("7.0.0", "instax_darktable")

local model_widget = dt.new_widget("combobox") {
  label = "Printer Model",
  tooltip = "Select your Fujifilm Instax BLE Link or Wi-Fi Direct SHARE printer",
  value = 1,
  "Auto-Detect BLE (Mini / SQUARE / WIDE)",
  "Instax Link WIDE / WIDE 2 (1260x840)",
  "Instax SQUARE Link (800x800)",
  "Instax Mini Link 1 / 2 / 3 (600x800)",
  "Legacy Instax SHARE SP-1 (Wi-Fi Direct)",
  "Legacy Instax SHARE SP-2 (Wi-Fi Direct)",
  "Legacy Instax SHARE SP-3 SQUARE (Wi-Fi Direct)",
}

local mode_widget = dt.new_widget("combobox") {
  label = "Color Mode",
  value = 1,
  "Standard / Neutral (No Profile)",
  "instax-Rich (Vivid)",
  "instax-Natural (Classic)",
}

local fit_widget = dt.new_widget("combobox") {
  label = "Framing",
  value = 1,
  "crop",
  "fit",
  "stretch",
}

local qr_widget = dt.new_widget("entry") {
  text = "",
  placeholder = "Optional QR URL or text...",
  tooltip = "Embed scannable QR code badge on print",
}

local caption_widget = dt.new_widget("entry") {
  text = "",
  placeholder = "Optional bottom caption...",
  tooltip = "Print text caption at bottom of frame",
}

local dry_run_widget = dt.new_widget("check_button") {
  label = "Dry Run (0-Film Test)",
  value = false,
  tooltip = "Test full data transfer to printer RAM without using film",
}

local container_widget = dt.new_widget("box") {
  orientation = "vertical",
  model_widget,
  mode_widget,
  fit_widget,
  qr_widget,
  caption_widget,
  dry_run_widget,
}

local function resolve_model_code(val)
  if val == "Instax Link WIDE / WIDE 2 (1260x840)" then return "wide", false end
  if val == "Instax SQUARE Link (800x800)" then return "square", false end
  if val == "Instax Mini Link 1 / 2 / 3 (600x800)" then return "mini", false end
  if val == "Legacy Instax SHARE SP-1 (Wi-Fi Direct)" then return "SP-1", true end
  if val == "Legacy Instax SHARE SP-2 (Wi-Fi Direct)" then return "SP-2", true end
  if val == "Legacy Instax SHARE SP-3 SQUARE (Wi-Fi Direct)" then return "SP-3", true end
  return "auto", false
end

dt.register_storage(
  "module_instax_offline_printer",
  "Instax Offline Printer (BLE & Wi-Fi Direct)",
  function(storage, image, format, filename, number, total, high_quality, extra_data)
    dt.print(string.format("Rendering %d/%d for Instax Printer...", number, total))
  end,
  function(storage, image_table, extra_data)
    local model_code, is_legacy = resolve_model_code(model_widget.value)
    local color_mode = "none"
    if mode_widget.value == "instax-Natural (Classic)" then
      color_mode = "natural"
    elseif mode_widget.value == "instax-Rich (Vivid)" then
      color_mode = "rich"
    end
    local fit_mode = fit_widget.value or "crop"
    local qr_val = qr_widget.text or ""
    local cap_val = caption_widget.text or ""
    local dry_run = dry_run_widget.value

    for _, exported_path in pairs(image_table) do
      local cmd
      if is_legacy then
        cmd = string.format('python3 -m legacy_instax_printer --model "%s" %s %s %s "%s"',
          model_code,
          dry_run and "--dry-run" or "",
          qr_val ~= "" and string.format('--qr "%s"', qr_val) or "",
          cap_val ~= "" and string.format('--caption "%s"', cap_val) or "",
          exported_path
        )
      else
        cmd = string.format('python3 -m instax_printer print "%s" --device "INSTAX-" --model "%s" --mode "%s" --fit "%s" %s %s %s',
          exported_path,
          model_code,
          color_mode,
          fit_mode,
          dry_run and "--dry-run" or "",
          qr_val ~= "" and string.format('--qr "%s"', qr_val) or "",
          cap_val ~= "" and string.format('--caption "%s"', cap_val) or ""
        )
      end
      local res = os.execute(cmd)
      os.remove(exported_path)
      if res ~= 0 and res ~= true then
        dt.print("Instax print failed — check printer power, Bluetooth/Wi-Fi, and battery.")
        return
      end
    end
    dt.print(dry_run and "Instax Dry Run Verified (0 Film Used)!" or "Printed to Instax!")
  end,
  nil,
  nil,
  container_widget
)
