do -- Setup options
	-- By default we want to include the minify and depends library
	-- and print a trace on errors
	Options:Default "trace"
	Options:Option "with-interop"
		:Description "Include the interop library"
		:Alias "wi"
		:Default(not shell and not redstone)
end

if Options:Get("with-interop") then
	-- TODO:
	Sources:File "interop/native/Colors.lua"     :Name "colors"
	Sources:File "interop/native/FileSystem.lua" :Name "fs"
	Sources:File "interop/native/Terminal.lua"
		:Name "term"
		:Depends "colors"
	Sources:File "interop/native/Helpers.lua"
		:Name "Helpers"
		:Prerequisite { "colors", "fs", "term" }
end

Tasks:Clean("clean", "build")

local files = Files()
	:Include "wild:howl/*.lua"
	:Startup "howl/cli.lua"

Tasks:AsRequire("develop", files, "build/HowlD.lua"):Link()
	:Description "Generates a bootstrap file for development"

Tasks:AsRequire("main", files, "build/Howl.lua")

Tasks:Minify("minify", "build/Howl.lua", "build/Howl.min.lua")
	:Description("Produces a minified version of the code")

Tasks:Task "build" { "minify" }
	:Description "Minify sources"
