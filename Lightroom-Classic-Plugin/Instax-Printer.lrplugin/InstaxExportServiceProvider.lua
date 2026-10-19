local LrView = import 'LrView'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrColor = import 'LrColor'

local exportServiceProvider = {}

local function shellQuote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function winQuote(value)
	return '"' .. tostring(value):gsub('"', '\\"') .. '"'
end

local function isLegacySPModel(model)
	return model == "sp1" or model == "sp2" or model == "sp3"
end

local function getCliPath(model)
	local pluginPath = _PLUGIN.path
	local isWin = (WIN_ENV == true)

	if isWin then
		if isLegacySPModel(model) then
			return LrPathUtils.child(pluginPath, "bin/win/legacy-instax.bat")
		end
		return LrPathUtils.child(pluginPath, "bin/win/instax-square.bat")
	end

	if isLegacySPModel(model) then
		local bundledLegacy = LrPathUtils.child(pluginPath, "bin/mac/legacy-instax")
		if LrFileUtils.exists(bundledLegacy) then
			return bundledLegacy
		end
		local linuxLegacy = LrPathUtils.child(pluginPath, "bin/linux/legacy-instax")
		if LrFileUtils.exists(linuxLegacy) then
			return linuxLegacy
		end
		if LrFileUtils.exists("/usr/local/bin/legacy-instax") then
			return "/usr/local/bin/legacy-instax"
		end
		return "legacy-instax"
	end

	local bundledCli = LrPathUtils.child(pluginPath, "bin/mac/instax-square")
	if LrFileUtils.exists(bundledCli) then
		return bundledCli
	end
	local linuxCli = LrPathUtils.child(pluginPath, "bin/linux/instax-square")
	if LrFileUtils.exists(linuxCli) then
		return linuxCli
	end
	if LrFileUtils.exists("/usr/local/bin/instax-square") then
		return "/usr/local/bin/instax-square"
	end
	return "instax-square"
end

local function executeWithOutput(cliPath, arguments)
	local outputPath = LrFileUtils.chooseUniqueFileName(
		LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'instax-cli-output.txt')
	)
	local exitPath = outputPath .. ".exit"
	local helperPath = LrPathUtils.child(_PLUGIN.path, "bin/mac/InstaxCLIHelper.app")
	local isWin = (WIN_ENV == true)

	local launchExitCode
	if (not isWin) and LrFileUtils.exists(helperPath) then
		local commandParts = {
			"/usr/bin/open",
			"-W",
			"-n",
			shellQuote(helperPath),
			"--args",
			shellQuote(outputPath),
			shellQuote(cliPath),
		}
		for _, argument in ipairs(arguments) do
			table.insert(commandParts, shellQuote(argument))
		end
		launchExitCode = LrTasks.execute(table.concat(commandParts, " "))
	elseif isWin then
		local winParts = { winQuote(cliPath) }
		for _, argument in ipairs(arguments) do
			table.insert(winParts, winQuote(argument))
		end
		local cmdLine = string.format('cmd.exe /C "%s > %s 2>&1"', table.concat(winParts, " "), winQuote(outputPath))
		launchExitCode = LrTasks.execute(cmdLine)
	else
		local directParts = { shellQuote(cliPath) }
		for _, argument in ipairs(arguments) do
			table.insert(directParts, shellQuote(argument))
		end
		launchExitCode = LrTasks.execute(table.concat(directParts, " ") .. string.format(' > %s 2>&1', shellQuote(outputPath)))
	end

	local output = LrFileUtils.readFile(outputPath) or ""
	local exitText = LrFileUtils.readFile(exitPath) or ""
	local exitCode = tonumber(exitText:match("%d+")) or launchExitCode
	LrFileUtils.delete(outputPath)
	LrFileUtils.delete(exitPath)
	return exitCode, output
end

-- Hide non-relevant sections from Lightroom's Export Dialog
exportServiceProvider.hideSections = { 'exportLocation', 'fileNaming', 'video' }
exportServiceProvider.allowFileFormats = { 'JPEG' }
exportServiceProvider.allowColorSpaces = { 'sRGB' }
exportServiceProvider.canExportVideo = false

exportServiceProvider.exportPresetFields = {
	{ key = 'printerModel',   default = 'auto' },
	{ key = 'printMode',      default = 'none' },
	{ key = 'fitMode',        default = 'crop' },
	{ key = 'bgColor',        default = '#FFFFFF' },
	{ key = 'collageLayout',  default = 'single' },
	{ key = 'collageSpacing', default = 16 },
	{ key = 'qrContent',      default = '' },
	{ key = 'captionText',    default = '' },
	{ key = 'customDevice',   default = '' },
	{ key = 'dryRun',         default = false },
}

function exportServiceProvider.sectionsForTopOfDialog( f, propertyTable )
	local bind = LrView.bind

	return {
		{
			title = "Instax Printer Settings",
			synopsis = bind 'printerModel',

			f:column {
				spacing = f:control_spacing(),

				f:row {
					f:static_text {
						title = "Printer Model:",
						alignment = 'right',
						width = LrView.share 'label_width',
					},
					f:popup_menu {
						value = bind 'printerModel',
						items = {
							{ title = "⚡ Auto-Detect BLE Printer (Mini / SQUARE / WIDE)", value = "auto" },
							{ title = "Instax Link WIDE / WIDE 2 (1260 × 840 BLE)", value = "wide" },
							{ title = "Instax SQUARE Link (800 × 800 BLE)", value = "square" },
							{ title = "Instax Mini Link 1 / 2 / 3 / Link+ (600 × 800 BLE)", value = "mini" },
							{ title = "Legacy Instax SHARE SP-1 (600 × 800 Wi-Fi Direct)", value = "sp1" },
							{ title = "Legacy Instax SHARE SP-2 (600 × 800 Wi-Fi Direct)", value = "sp2" },
							{ title = "Legacy Instax SHARE SP-3 SQUARE (800 × 800 Wi-Fi Direct)", value = "sp3" },
						},
						width = 340,
					},
				},

				f:row {
					f:static_text {
						title = "Color Mode:",
						alignment = 'right',
						width = LrView.share 'label_width',
					},
					f:popup_menu {
						value = bind 'printMode',
						items = {
							{ title = "Standard / Neutral (No Profile - Clean Raw)", value = "none" },
							{ title = "instax-Rich Mode (Vivid pop & saturated)", value = "rich" },
							{ title = "instax-Natural Mode (Classic analog 3D-LUT tone)", value = "natural" },
						},
						width = 340,
					},
				},

				f:row {
					f:static_text {
						title = "Framing / Fit Style:",
						alignment = 'right',
						width = LrView.share 'label_width',
					},
					f:popup_menu {
						value = bind 'fitMode',
						items = {
							{ title = "Fill / Crop (Full bleed without borders)", value = "crop" },
							{ title = "Fit Entire Image (Letterbox matte border)", value = "fit" },
							{ title = "Stretch to fill", value = "stretch" },
						},
						width = 340,
					},
				},

				f:row {
					f:static_text {
						title = "Matte Border Color:",
						alignment = 'right',
						width = LrView.share 'label_width',
					},
					f:popup_menu {
						value = bind 'bgColor',
						items = {
							{ title = "White (#FFFFFF)", value = "#FFFFFF" },
							{ title = "Black (#000000)", value = "#000000" },
							{ title = "Neutral Gray (#808080)", value = "#808080" },
							{ title = "Warm Cream (#FFFDD0)", value = "#FFFDD0" },
						},
						width = 340,
					},
				},

				f:row {
					f:static_text {
						title = "Multi-Photo Collage:",
						alignment = 'right',
						width = LrView.share 'label_width',
					},
					f:popup_menu {
						value = bind 'collageLayout',
						items = {
							{ title = "Single Photo (Print each selected photo separately)", value = "single" },
							{ title = "2-Split (Left / Right — combines 2 selected photos)", value = "split2V" },
							{ title = "2-Split (Top / Bottom — combines 2 selected photos)", value = "split2H" },
							{ title = "3-Split (Hero Left + 2 Stacked)", value = "split3Hero" },
							{ title = "3-Stripes (Vertical WIDE)", value = "split3V" },
							{ title = "4-Grid (2 × 2 Grid)", value = "grid4" },
							{ title = "4-Stripes (Photo Booth Strip)", value = "strips4V" },
							{ title = "6-Grid (3 × 2 Contact Sheet)", value = "grid6" },
							{ title = "9-Grid (3 × 3 Grid)", value = "grid9" },
						},
						width = 340,
					},
				},

				f:row {
					f:static_text {
						title = "QR Code URL / Text:",
						alignment = 'right',
						width = LrView.share 'label_width',
					},
					f:edit_field {
						value = bind 'qrContent',
						truncation = 'middle',
						immediate = true,
						width = 240,
					},
					f:static_text {
						title = "Optional scannable QR overlay",
						font = "<system/small>",
						text_color = LrColor(0.5, 0.5, 0.5),
					},
				},

				f:row {
					f:static_text {
						title = "Bottom Caption:",
						alignment = 'right',
						width = LrView.share 'label_width',
					},
					f:edit_field {
						value = bind 'captionText',
						truncation = 'middle',
						immediate = true,
						width = 240,
					},
					f:static_text {
						title = "Optional print caption",
						font = "<system/small>",
						text_color = LrColor(0.5, 0.5, 0.5),
					},
				},

				f:row {
					f:static_text {
						title = "Target Device / IP:",
						alignment = 'right',
						width = LrView.share 'label_width',
					},
					f:edit_field {
						value = bind 'customDevice',
						truncation = 'middle',
						immediate = true,
						width = 180,
					},
					f:static_text {
						title = "Leave empty for auto (INSTAX- or 192.168.0.251)",
						font = "<system/small>",
						text_color = LrColor(0.5, 0.5, 0.5),
					},
				},

				f:row {
					f:static_text {
						title = "Test Mode:",
						alignment = 'right',
						width = LrView.share 'label_width',
					},
					f:checkbox {
						title = "🧪 Dry Run (0-Film Test — verify full transfer to printer RAM without using film)",
						value = bind 'dryRun',
					},
				},
			},
		},
	}
end

local function buildPrintArguments(model, imagePaths, params)
	if isLegacySPModel(model) then
		local args = {
			"--model", model,
		}
		if params.customDevice and params.customDevice ~= "" then
			table.insert(args, "--ip")
			table.insert(args, params.customDevice)
		end
		if params.dryRun then
			table.insert(args, "--dry-run")
		end
		if params.fitMode == "fit" then
			table.insert(args, "--fit")
		end
		if params.captionText and params.captionText ~= "" then
			table.insert(args, "--caption")
			table.insert(args, params.captionText)
		end
		if params.qrContent and params.qrContent ~= "" then
			table.insert(args, "--qr")
			table.insert(args, params.qrContent)
		end
		for _, p in ipairs(imagePaths) do
			table.insert(args, p)
		end
		return args
	end

	local cmdArgs = { "print" }
	for _, p in ipairs(imagePaths) do
		table.insert(cmdArgs, p)
	end
	table.insert(cmdArgs, "--model")
	table.insert(cmdArgs, model or "auto")
	table.insert(cmdArgs, "--mode")
	table.insert(cmdArgs, params.printMode or "none")
	table.insert(cmdArgs, "--fit")
	table.insert(cmdArgs, params.fitMode or "crop")
	table.insert(cmdArgs, "--bg")
	table.insert(cmdArgs, params.bgColor or "#FFFFFF")
	table.insert(cmdArgs, "--device")
	table.insert(
		cmdArgs,
		params.customDevice and params.customDevice ~= "" and params.customDevice or "INSTAX-"
	)

	if params.dryRun then
		table.insert(cmdArgs, "--dry-run")
	end
	if params.collageLayout and params.collageLayout ~= "" and params.collageLayout ~= "single" then
		table.insert(cmdArgs, "--collage")
		table.insert(cmdArgs, params.collageLayout)
		table.insert(cmdArgs, "--collage-spacing")
		table.insert(cmdArgs, tostring(params.collageSpacing or 16))
	end
	if params.qrContent and params.qrContent ~= "" then
		table.insert(cmdArgs, "--qr")
		table.insert(cmdArgs, params.qrContent)
	end
	if params.captionText and params.captionText ~= "" then
		table.insert(cmdArgs, "--caption")
		table.insert(cmdArgs, params.captionText)
	end
	return cmdArgs
end

function exportServiceProvider.processRenderedPhotos( functionContext, exportContext )
	local exportSession = exportContext.exportSession
	local exportParams = exportContext.propertyTable
	local model = exportParams.printerModel or "auto"

	local nPhotos = exportSession:countRenditions()
	local progressScope = exportContext:configureProgress {
		title = nPhotos > 1 and string.format("Printing %d photos to Instax...", nPhotos) or "Printing to Instax...",
	}

	local cliPath = getCliPath(model)
	local printFailed = false
	local useCollage = (not isLegacySPModel(model))
		and exportParams.collageLayout
		and exportParams.collageLayout ~= "single"
		and nPhotos > 1

	local collagePaths = {}

	for i, rendition in exportContext:renditions { stopIfCanceled = true } do
		progressScope:setPortionComplete(i - 1, nPhotos)

		local success, pathOrMessage = rendition:waitForRender()
		if progressScope:isCanceled() then break end

		if success then
			local renderedPath = pathOrMessage
			if useCollage then
				table.insert(collagePaths, renderedPath)
			else
				progressScope:setCaption(string.format("Transmitting photo %d of %d to Instax...", i, nPhotos))
				local cmdArgs = buildPrintArguments(model, { renderedPath }, exportParams)
				local exitCode, output = executeWithOutput(cliPath, cmdArgs)

				LrFileUtils.delete(renderedPath)

				if exitCode ~= 0 then
					LrDialogs.showError(string.format(
						"Print failed for photo %d (exit code %d).\n\nPossible causes:\n1. Make sure Bluetooth on your phone/tablet is temporarily OFF (or join INSTAX-XXXXXXXX Wi-Fi for SP-1/2/3).\n2. Ensure the printer is powered on and its battery is charged (>20%%).\n3. Check that film is available and the film door is closed.\n\nCLI details:\n%s",
						i,
						exitCode,
						output ~= "" and output or "The Instax CLI did not provide an error message."
					))
					printFailed = true
					break
				end
			end
		else
			LrDialogs.showError("Lightroom rendering failed: " .. tostring(pathOrMessage))
			printFailed = true
			break
		end

		progressScope:setPortionComplete(i, nPhotos)
	end

	if useCollage and not printFailed and not progressScope:isCanceled() and #collagePaths > 0 then
		progressScope:setCaption(string.format("Compositing & transmitting %d-photo collage to Instax...", #collagePaths))
		local cmdArgs = buildPrintArguments(model, collagePaths, exportParams)
		local exitCode, output = executeWithOutput(cliPath, cmdArgs)
		for _, p in ipairs(collagePaths) do
			LrFileUtils.delete(p)
		end
		if exitCode ~= 0 then
			LrDialogs.showError(string.format(
				"Collage print failed (exit code %d).\n\nPossible causes:\n1. Make sure Bluetooth on your phone/tablet is temporarily OFF.\n2. Ensure the printer is powered on and its battery is charged (>20%%).\n3. Check that film is available and the film door is closed.\n\nCLI details:\n%s",
				exitCode,
				output ~= "" and output or "The Instax CLI did not provide an error message."
			))
			printFailed = true
		end
	else
		for _, p in ipairs(collagePaths) do
			LrFileUtils.delete(p)
		end
	end

	progressScope:done()
	if not printFailed and not progressScope:isCanceled() then
		if exportParams.dryRun then
			LrDialogs.showBezel("🧪 Instax Dry Run Verified (0 Film Used)!")
		else
			LrDialogs.showBezel("🎉 Sent to Instax Printer!")
		end
	end
end

return exportServiceProvider
