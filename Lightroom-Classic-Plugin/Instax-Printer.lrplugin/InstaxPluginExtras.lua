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

local function executeWithOutput(cliPath, arguments)
	local outputPath = LrFileUtils.chooseUniqueFileName(
		LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'instax-cli-output.txt')
	)
	local exitPath = outputPath .. ".exit"
	local helperPath = LrPathUtils.child(_PLUGIN.path, "bin/mac/InstaxCLIHelper.app")
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

	local launchExitCode = LrTasks.execute(table.concat(commandParts, " "))
	local output = LrFileUtils.readFile(outputPath) or ""
	local exitText = LrFileUtils.readFile(exitPath) or ""
	local exitCode = tonumber(exitText:match("%d+")) or launchExitCode
	LrFileUtils.delete(outputPath)
	LrFileUtils.delete(exitPath)
	return exitCode, output
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

		local dialogContents = f:column {
			spacing = f:control_spacing(),
			f:static_text {
				title = string.format("Send %d selected photo(s) directly to your Instax printer via Bluetooth:", #targetPhotos),
				font = "<system/bold>",
			},
			f:spacer { height = 8 },
			f:row {
				f:static_text { title = "Target Printer:", width = 120, alignment = 'right' },
				f:popup_menu {
					value = LrView.bind { key = 'printerModel', object = props },
					items = {
						{ title = "⚡ Auto-Detect Connected Printer", value = "auto" },
						{ title = "Instax Link WIDE / WIDE 2 (1260 × 840)", value = "wide" },
						{ title = "Instax SQUARE Link (800 × 800)", value = "square" },
						{ title = "Instax Mini Link 1 / 2 / 3 / Link+ (600 × 800)", value = "mini" },
					},
					width = 290,
				},
			},
			f:row {
				f:static_text { title = "Color Mode:", width = 120, alignment = 'right' },
				f:popup_menu {
					value = LrView.bind { key = 'printMode', object = props },
					items = {
						{ title = "instax-Rich Mode (Vivid & punchy)", value = "rich" },
						{ title = "instax-Natural Mode (Classic soft analog)", value = "natural" },
					},
					width = 290,
				},
			},
			f:row {
				f:static_text { title = "Framing:", width = 120, alignment = 'right' },
				f:popup_menu {
					value = LrView.bind { key = 'fitMode', object = props },
					items = {
						{ title = "Fill / Crop (Full bleed)", value = "crop" },
						{ title = "Fit (Letterbox with border)", value = "fit" },
					},
					width = 290,
				},
			},
			f:spacer { height = 8 },
			f:static_text {
				title = "💡 Tip: Ensure Bluetooth on your phone/tablet is temporarily turned OFF.",
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

		local pluginPath = _PLUGIN.path
		local cliPath = LrPathUtils.child(pluginPath, "bin/mac/instax-square")
		if not LrFileUtils.exists(cliPath) then
			cliPath = "/usr/local/bin/instax-square"
		end

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

		local count = 0
		for _, rendition in exportSession:renditions() do
			local success, pathOrMessage = rendition:waitForRender()
			if success then
				count = count + 1
				local code, output = executeWithOutput(cliPath, {
					"print",
					pathOrMessage,
					"--device", "INSTAX-",
					"--model", props.printerModel,
					"--mode", props.printMode,
					"--fit", props.fitMode,
				})
				LrFileUtils.delete(pathOrMessage)
				if code ~= 0 then
					LrDialogs.showError(string.format(
						"Failed to print photo %d (exit code %d).\n\nPossible causes:\n1. Make sure Bluetooth on your phone/tablet is temporarily OFF.\n2. Ensure the printer is powered on and its battery is charged (>20%%).\n3. Check that film is available and the film door is closed.\n\nCLI details:\n%s",
						count,
						code,
						output ~= "" and output or "The Instax CLI did not provide an error message."
					))
					return
				end
			end
		end

		LrDialogs.showBezel(string.format("🎉 Printed %d photo(s) to Instax!", count))
	end)
end)
