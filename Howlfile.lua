Options:Default "trace"

Tasks:clean()

Tasks:minify "minify" {
	input = "build/Howl.lua",
	output = "build/Howl.min.lua",
}

Tasks:require "main" {
	include = "howl/*.lua",
	startup = "howl/cli.lua",
	output = "build/Howl.lua",
	api = true,
}

Tasks:require "develop" {
	include = "howl/*.lua",
	startup = "howl/cli.lua",
	output = "build/HowlD.lua",
	link = true,
	api = true,
}

Tasks:Task "build" { "clean", "minify" } :Description "Main build task"

Tasks:gist "upload" (function(spec)
	spec:summary "A build system for Lua (http://www.computercraft.info/forums2/index.php?/topic/21254- and https://github.com/SquidDev-CC/Howl)"
	spec:gist "703e2f46ce68c2ca158673ff0ec4208c"
	spec:from "build" {
		include = { "Howl.lua", "Howl.min.lua" }
	}
end) :Requires { "build/Howl.lua", "build/Howl.min.lua" }

Tasks:compilr "compilr" {
	include = "howl/class/*",
	startup = "howl/class/mixin.lua",
	output = "build/compilr.lua",
	minify = true,
}
