local LrView = import 'LrView'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrColor = import 'LrColor'

local exportServiceProvider = {}

local function executeWithOutput(command)
	local outputPath = LrFileUtils.chooseUniqueFileName(
		LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'instax-cli-output.txt')
	)
	local exitCode = LrTasks.execute(command .. string.format(' > "%s" 2>&1', outputPath))
	local output = LrFileUtils.readFile(outputPath) or ""
	LrFileUtils.delete(outputPath)
	return exitCode, output
end

-- Hide non-relevant sections from Lightroom's Export Dialog
exportServiceProvider.hideSections = { 'exportLocation', 'fileNaming', 'video' }
exportServiceProvider.allowFileFormats = { 'JPEG' }
exportServiceProvider.allowColorSpaces = { 'sRGB' }
exportServiceProvider.canExportVideo = false

exportServiceProvider.exportPresetFields = {
	{ key = 'printerModel', default = 'auto' },
	{ key = 'printMode',    default = 'rich' },
	{ key = 'fitMode',      default = 'crop' },
	{ key = 'bgColor',      default = '#FFFFFF' },
	{ key = 'customDevice', default = '' },
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
							{ title = "⚡ Auto-Detect Connected Printer", value = "auto" },
							{ title = "Instax Link WIDE / WIDE 2 (1260 × 840)", value = "wide" },
							{ title = "Instax SQUARE Link (800 × 800)", value = "square" },
							{ title = "Instax Mini Link 1 / 2 / 3 / Link+ (600 × 800)", value = "mini" },
						},
						width = 320,
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
							{ title = "instax-Rich Mode (Vivid & saturated)", value = "rich" },
							{ title = "instax-Natural Mode (Classic analog soft tone)", value = "natural" },
						},
						width = 320,
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
						width = 320,
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
						width = 320,
					},
				},

				f:row {
					f:static_text {
						title = "Target Device (Optional):",
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
						title = "Leave empty to auto-connect nearby printer",
						font = "<system/small>",
						text_color = LrColor(0.5, 0.5, 0.5),
					},
				},
			},
		},
	}
end

local function getCliPath()
	local pluginPath = _PLUGIN.path
	local bundledCli = LrPathUtils.child(pluginPath, "bin/mac/instax-square")
	if LrFileUtils.exists(bundledCli) then
		return bundledCli
	end
	if LrFileUtils.exists("/usr/local/bin/instax-square") then
		return "/usr/local/bin/instax-square"
	end
	return "instax-square"
end

function exportServiceProvider.processRenderedPhotos( functionContext, exportContext )
	local exportSession = exportContext.exportSession
	local exportParams = exportContext.propertyTable

	local nPhotos = exportSession:countRenditions()
	local progressScope = exportContext:configureProgress {
		title = nPhotos > 1 and string.format("Printing %d photos to Instax...", nPhotos) or "Printing to Instax...",
	}

	local cliPath = getCliPath()
	local printFailed = false

	for i, rendition in exportContext:renditions { stopIfCanceled = true } do
		progressScope:setPortionComplete(i - 1, nPhotos)

		local success, pathOrMessage = rendition:waitForRender()
		if progressScope:isCanceled() then break end

		if success then
			local renderedPath = pathOrMessage
			progressScope:setCaption(string.format("Transmitting photo %d of %d to Instax...", i, nPhotos))

			local cmdArgs = {
				string.format('"%s"', cliPath),
				"print",
				string.format('"%s"', renderedPath),
				"--model", exportParams.printerModel or "auto",
				"--mode", exportParams.printMode or "rich",
				"--fit", exportParams.fitMode or "crop",
				"--bg", string.format('"%s"', exportParams.bgColor or "#FFFFFF"),
			}

			table.insert(cmdArgs, "--device")
			table.insert(cmdArgs, string.format(
				'"%s"',
				exportParams.customDevice and exportParams.customDevice ~= "" and exportParams.customDevice or "INSTAX-"
			))

			local fullCmd = table.concat(cmdArgs, " ")
			local exitCode, output = executeWithOutput(fullCmd)

			-- Clean up temp exported JPEG
			LrFileUtils.delete(renderedPath)

			if exitCode ~= 0 then
				LrDialogs.showError(string.format(
					"Print failed for photo %d (exit code %d).\n\nPossible causes:\n1. Make sure Bluetooth on your phone/tablet is temporarily OFF.\n2. Ensure the printer is powered on and its battery is charged (>20%%).\n3. Check that film is available and the film door is closed.\n\nCLI details:\n%s",
					i,
					exitCode,
					output ~= "" and output or "The Instax CLI did not provide an error message."
				))
				printFailed = true
				break
			end
		else
			LrDialogs.showError("Lightroom rendering failed: " .. tostring(pathOrMessage))
		end

		progressScope:setPortionComplete(i, nPhotos)
	end

	progressScope:done()
	if not printFailed and not progressScope:isCanceled() then
		LrDialogs.showBezel("🎉 Sent to Instax Printer!")
	end
end

return exportServiceProvider
