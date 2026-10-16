local LrApplication = import 'LrApplication'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrColor = import 'LrColor'

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

		local exportSession = catalog:batchExport {
			photos = targetPhotos,
			exportSettings = {
				LR_format = 'JPEG',
				LR_jpeg_quality = 1.0,
				LR_export_colorSpace = 'sRGB',
				LR_export_destinationType = 'tempFolderPath',
				LR_collisionHandling = 'rename',
			},
		}

		local count = 0
		for _, rendition in exportSession:renditions() do
			local success, pathOrMessage = rendition:waitForRender()
			if success then
				count = count + 1
				local cmd = string.format('"%s" print "%s" --model %s --mode %s --fit %s',
					cliPath, pathOrMessage, props.printerModel, props.printMode, props.fitMode)
				local code = LrTasks.execute(cmd)
				LrFileUtils.delete(pathOrMessage)
				if code ~= 0 then
					LrDialogs.showError(string.format("Failed to print photo %d. Check that printer is on, battery is charged (>20%%), and phone Bluetooth is off.", count))
					return
				end
			end
		end

		LrDialogs.showBezel(string.format("🎉 Printed %d photo(s) to Instax!", count))
	end)
end)
