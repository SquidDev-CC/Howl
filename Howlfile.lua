Options:Default "trace"

Tasks:Clean("clean", "build")

local files = Files()
	:Include "wild:howl/*.lua"
	:Startup "howl/cli.lua"

Tasks:AsRequire("develop", files, "build/HowlD.lua"):Link()
	:Description "Generates a bootstrap file for development"

Tasks:AsRequire("main", files, "build/Howl.lua")

Tasks:Minify("minify", "build/Howl.lua", "build/Howl.min.lua")
	:Description("Produces a minified version of the code")

Tasks:asRequire "foobar" {
	include = "howl/*.lua",
	startup = "howl/cli.lua",
	output = "build/howl.lua",
	link = true,
}

Tasks:Task "build" { "minify" }
	:Description "Minify sources"

Tasks:gist "upload" (function(spec)
	spec:description "A build system for Lua"
	spec:gist "703e2f46ce68c2ca158673ff0ec4208c"
	spec:from "build" {
		include = { "Howl.lua", "Howl.min.lua" }
	}
end) :Depends { "build" }
