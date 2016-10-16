Tasks:clean()

Tasks:require "main" {
	include = {"WebBuild.lua", "json.lua", "download.lua", "vfs.lua"},
	startup = "WebBuild.lua",
	output = "build/WebBuild.lua",
}

Tasks:minify "minify" { input = "build/WebBuild.lua", output = "build/WebBuild.min.lua" }

Tasks:require "boot" {
	include = {"WebBuild.lua", "json.lua", "download.lua", "vfs.lua"},
	startup = "WebBuild.lua",
	output = "build/boot.lua",
	link = true,
}

Tasks:Task "build" { "clean", "minify", "boot" }
Tasks:Default "build"
