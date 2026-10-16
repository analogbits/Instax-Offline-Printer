return {
	LrSdkVersion = 9.0,
	LrToolkitVersion = 9.0,
	LrToolkitIdentifier = "com.analogbits.instax-offline-printer",

	LrPluginName = "Instax Offline Printer",
	LrPluginInfoUrl = "https://github.com/analogbits/Instax-Offline-Printer",

	-- Export Service Provider (integrates with File -> Export)
	LrExportServiceProvider = {
		title = "Instax Offline Printer",
		file = "InstaxExportServiceProvider.lua",
	},

	-- Menu item under File -> Plug-in Extras
	LrPluginExtras = {
		{
			title = "Print to Instax...",
			file = "InstaxPluginExtras.lua",
		},
	},

	VERSION = { major = 1, minor = 2, revision = 0, build = 1 },
}
