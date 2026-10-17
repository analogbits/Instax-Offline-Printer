local LrApplication = import 'LrApplication'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrColor = import 'LrColor'
local LrExportSession = import 'LrExportSession'

local function shellQuote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function isLegacySPModel(model)
	return model == "sp1" or model == "sp2" or model == "sp3"
end

local function getCliPath(model)
	local pluginPath = _PLUGIN.path
	if isLegacySPModel(model) then
		local bundledLegacy = LrPathUtils.child(pluginPath, "bin/mac/legacy-instax")
		if LrFileUtils.exists(bundledLegacy) then
			return bundledLegacy
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

	local launchExitCode
	if LrFileUtils.exists(helperPath) then
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
	else
		local directParts = { string.format('"%s"', cliPath) }
		for _, argument in ipairs(arguments) do
			table.insert(directParts, string.format('"%s"', tostring(argument)))
		end
		launchExitCode = LrTasks.execute(table.concat(directParts, " ") .. string.format(' > "%s" 2>&1', outputPath))
	end

	local output = LrFileUtils.readFile(outputPath) or ""
	local exitText = LrFileUtils.readFile(exitPath) or ""
	local exitCode = tonumber(exitText:match("%d+")) or launchExitCode
	LrFileUtils.delete(outputPath)
	LrFileUtils.delete(exitPath)
	return exitCode, output
end

local function buildPrintArguments(model, imagePaths, props)
	if isLegacySPModel(model) then
		local args = {
			"--model", model,
		}
		if props.customDevice and props.customDevice ~= "" then
			table.insert(args, "--ip")
			table.insert(args, props.customDevice)
		end
		if props.dryRun then
			table.insert(args, "--dry-run")
		end
		if props.fitMode == "fit" then
			table.insert(args, "--fit")
		end
		if props.captionText and props.captionText ~= "" then
			table.insert(args, "--caption")
			table.insert(args, props.captionText)
		end
		if props.qrContent and props.qrContent ~= "" then
			table.insert(args, "--qr")
			table.insert(args, props.qrContent)
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
	table.insert(cmdArgs, props.printMode or "rich")
	table.insert(cmdArgs, "--fit")
	table.insert(cmdArgs, props.fitMode or "crop")
	table.insert(cmdArgs, "--bg")
	table.insert(cmdArgs, props.bgColor or "#FFFFFF")
	table.insert(cmdArgs, "--device")
	table.insert(
		cmdArgs,
		props.customDevice and props.customDevice ~= "" and props.customDevice or "INSTAX-"
	)

	if props.dryRun then
		table.insert(cmdArgs, "--dry-run")
	end
	if props.collageLayout and props.collageLayout ~= "" and props.collageLayout ~= "single" then
		table.insert(cmdArgs, "--collage")
		table.insert(cmdArgs, props.collageLayout)
		table.insert(cmdArgs, "--collage-spacing")
		table.insert(cmdArgs, "16")
	end
	if props.qrContent and props.qrContent ~= "" then
		table.insert(cmdArgs, "--qr")
		table.insert(cmdArgs, props.qrContent)
	end
	if props.captionText and props.captionText ~= "" then
		table.insert(cmdArgs, "--caption")
		table.insert(cmdArgs, props.captionText)
	end
	return cmdArgs
end

LrTasks.startAsyncTask(function()
	local catalog = LrApplication.activeCatalog()
	local targetPhotos = catalog:getTargetPhotos()

	if #targetPhotos == 0 then
		LrDialogs.message("Instax Offline Printer", "Please select one or more photos in Lightroom before choosing Print to Instax.", "info")
		return
	end

	LrFunctionContext.callWithContext("instaxQuickPrint", function(context)
		local f = LrView.osFactory()
		local props = LrBinding.makePropertyTable(context)
		props.printerModel = "auto"
		props.printMode = "rich"
		props.fitMode = "crop"
		props.bgColor = "#FFFFFF"
		props.collageLayout = (#targetPhotos == 2 and "split2V") or (#targetPhotos == 4 and "grid4") or "single"
		props.qrContent = ""
		props.captionText = ""
		props.customDevice = ""
		props.dryRun = false

		local dialogContents = f:column {
			spacing = f:control_spacing(),
			f:static_text {
				title = string.format("Send %d selected photo(s) directly to your Instax printer:", #targetPhotos),
				font = "<system/bold>",
			},
			f:spacer { height = 6 },
			f:row {
				f:static_text { title = "Target Printer:", width = 130, alignment = 'right' },
				f:popup_menu {
					value = LrView.bind { key = 'printerModel', object = props },
					items = {
						{ title = "⚡ Auto-Detect BLE Printer (Mini / SQUARE / WIDE)", value = "auto" },
						{ title = "Instax Link WIDE / WIDE 2 (1260 × 840 BLE)", value = "wide" },
						{ title = "Instax SQUARE Link (800 × 800 BLE)", value = "square" },
						{ title = "Instax Mini Link 1 / 2 / 3 / Link+ (600 × 800 BLE)", value = "mini" },
						{ title = "Legacy Instax SHARE SP-1 (600 × 800 Wi-Fi Direct)", value = "sp1" },
						{ title = "Legacy Instax SHARE SP-2 (600 × 800 Wi-Fi Direct)", value = "sp2" },
						{ title = "Legacy Instax SHARE SP-3 SQUARE (800 × 800 Wi-Fi Direct)", value = "sp3" },
					},
					width = 330,
				},
			},
			f:row {
				f:static_text { title = "Color Mode:", width = 130, alignment = 'right' },
				f:popup_menu {
					value = LrView.bind { key = 'printMode', object = props },
					items = {
						{ title = "instax-Rich Mode (Vivid & punchy)", value = "rich" },
						{ title = "instax-Natural Mode (Classic soft analog)", value = "natural" },
					},
					width = 330,
				},
			},
			f:row {
				f:static_text { title = "Framing:", width = 130, alignment = 'right' },
				f:popup_menu {
					value = LrView.bind { key = 'fitMode', object = props },
					items = {
						{ title = "Fill / Crop (Full bleed)", value = "crop" },
						{ title = "Fit (Letterbox with matte border)", value = "fit" },
						{ title = "Stretch to fill", value = "stretch" },
					},
					width = 330,
				},
			},
			f:row {
				f:static_text { title = "Matte Color:", width = 130, alignment = 'right' },
				f:popup_menu {
					value = LrView.bind { key = 'bgColor', object = props },
					items = {
						{ title = "White (#FFFFFF)", value = "#FFFFFF" },
						{ title = "Black (#000000)", value = "#000000" },
						{ title = "Neutral Gray (#808080)", value = "#808080" },
						{ title = "Warm Cream (#FFFDD0)", value = "#FFFDD0" },
					},
					width = 330,
				},
			},
			f:row {
				f:static_text { title = "Collage Layout:", width = 130, alignment = 'right' },
				f:popup_menu {
					value = LrView.bind { key = 'collageLayout', object = props },
					items = {
						{ title = "Single Photo (Print each selected photo separately)", value = "single" },
						{ title = "2-Split (Left / Right)", value = "split2V" },
						{ title = "2-Split (Top / Bottom)", value = "split2H" },
						{ title = "3-Split (Hero Left + 2 Stacked)", value = "split3Hero" },
						{ title = "3-Stripes (Vertical WIDE)", value = "split3V" },
						{ title = "4-Grid (2 × 2 Grid)", value = "grid4" },
						{ title = "4-Stripes (Photo Booth Strip)", value = "strips4V" },
						{ title = "6-Grid (3 × 2 Contact Sheet)", value = "grid6" },
						{ title = "9-Grid (3 × 3 Grid)", value = "grid9" },
					},
					width = 330,
				},
			},
			f:row {
				f:static_text { title = "QR Code (URL/Text):", width = 130, alignment = 'right' },
				f:edit_field {
					value = LrView.bind { key = 'qrContent', object = props },
					width = 330,
					immediate = true,
				},
			},
			f:row {
				f:static_text { title = "Bottom Caption:", width = 130, alignment = 'right' },
				f:edit_field {
					value = LrView.bind { key = 'captionText', object = props },
					width = 330,
					immediate = true,
				},
			},
			f:row {
				f:static_text { title = "Device / IP:", width = 130, alignment = 'right' },
				f:edit_field {
					value = LrView.bind { key = 'customDevice', object = props },
					width = 160,
					immediate = true,
				},
				f:static_text {
					title = "Blank = auto-discover INSTAX-",
					font = "<system/small>",
					text_color = LrColor(0.5, 0.5, 0.5),
				},
			},
			f:row {
				f:static_text { title = "Test Mode:", width = 130, alignment = 'right' },
				f:checkbox {
					title = "🧪 Dry Run (0-Film Test — verify full transfer without using film)",
					value = LrView.bind { key = 'dryRun', object = props },
				},
			},
			f:spacer { height = 6 },
			f:static_text {
				title = "💡 Tip: Ensure Bluetooth on your phone/tablet is temporarily turned OFF (or join INSTAX Wi-Fi for SP-1/2/3).",
				font = "<system/small>",
				text_color = LrColor(0.5, 0.5, 0.5),
			},
		}

		local result = LrDialogs.presentModalDialog {
			title = "Print to Instax",
			contents = dialogContents,
			actionVerb = "Print Now",
		}

		if result ~= "ok" then return end

		local model = props.printerModel or "auto"
		local cliPath = getCliPath(model)

		local exportFolder = LrPathUtils.child(
			LrPathUtils.getStandardFilePath('temp'),
			'instax-lightroom'
		)
		local directoryCreated, directoryError = LrFileUtils.createAllDirectories(exportFolder)
		if not directoryCreated then
			LrDialogs.showError("Could not create the temporary export folder: " .. tostring(directoryError))
			return
		end

		local exportSession = LrExportSession {
			photosToExport = targetPhotos,
			exportSettings = {
				LR_format = 'JPEG',
				LR_jpeg_quality = 1.0,
				LR_export_colorSpace = 'sRGB',
				LR_export_destinationType = 'specificFolder',
				LR_export_destinationPathPrefix = exportFolder,
				LR_collisionHandling = 'rename',
			},
		}
		exportSession:doExportOnCurrentTask()

		local useCollage = (not isLegacySPModel(model))
			and props.collageLayout
			and props.collageLayout ~= "single"
			and #targetPhotos > 1

		local renderedPaths = {}
		for _, rendition in exportSession:renditions() do
			local success, pathOrMessage = rendition:waitForRender()
			if success then
				table.insert(renderedPaths, pathOrMessage)
			else
				LrDialogs.showError("Lightroom rendering failed: " .. tostring(pathOrMessage))
				for _, p in ipairs(renderedPaths) do LrFileUtils.delete(p) end
				return
			end
		end

		if useCollage and #renderedPaths > 1 then
			local cmdArgs = buildPrintArguments(model, renderedPaths, props)
			local code, output = executeWithOutput(cliPath, cmdArgs)
			for _, p in ipairs(renderedPaths) do
				LrFileUtils.delete(p)
			end
			if code ~= 0 then
				LrDialogs.showError(string.format(
					"Failed to print %d-photo collage (exit code %d).\n\nPossible causes:\n1. Make sure Bluetooth on your phone/tablet is temporarily OFF.\n2. Ensure the printer is powered on and its battery is charged (>20%%).\n3. Check that film is available and the film door is closed.\n\nCLI details:\n%s",
					#renderedPaths,
					code,
					output ~= "" and output or "The Instax CLI did not provide an error message."
				))
				return
			end
			if props.dryRun then
				LrDialogs.showBezel("🧪 Collage Dry Run Verified (0 Film Used)!")
			else
				LrDialogs.showBezel(string.format("🎉 Printed %d-photo Collage to Instax!", #renderedPaths))
			end
			return
		end

		local count = 0
		for idx, renderedPath in ipairs(renderedPaths) do
			count = count + 1
			local cmdArgs = buildPrintArguments(model, { renderedPath }, props)
			local code, output = executeWithOutput(cliPath, cmdArgs)
			LrFileUtils.delete(renderedPath)
			if code ~= 0 then
				for rem = idx + 1, #renderedPaths do
					LrFileUtils.delete(renderedPaths[rem])
				end
				LrDialogs.showError(string.format(
					"Failed to print photo %d (exit code %d).\n\nPossible causes:\n1. Make sure Bluetooth on your phone/tablet is temporarily OFF (or join INSTAX-XXXXXXXX Wi-Fi for SP-1/2/3).\n2. Ensure the printer is powered on and its battery is charged (>20%%).\n3. Check that film is available and the film door is closed.\n\nCLI details:\n%s",
					count,
					code,
					output ~= "" and output or "The Instax CLI did not provide an error message."
				))
				return
			end
		end

		if props.dryRun then
			LrDialogs.showBezel(string.format("🧪 Dry Run Verified %d photo(s) (0 Film Used)!", count))
		else
			LrDialogs.showBezel(string.format("🎉 Printed %d photo(s) to Instax!", count))
		end
	end)
end)
