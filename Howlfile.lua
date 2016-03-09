do -- Setup options
	-- By default we want to include the minify and depends library
	-- and print a trace on errors
	Options:Default "trace"
	Options:Option "with-interop"
		:Description "Include the interop library"
		:Alias "wi"
		:Default(not shell and not redstone)
end

Sources:Main "Howl.lua"
	-- Primiary dependencies
	:Depends { "ArgParse", "HowlFile", "Mediator", "Runner" }
	-- Modules
	:Depends { "Task.Extensions", "Depends.Bootstrap", "Depends.Combiner", "Lexer.Tasks", "Busted", "Compilr", "Require" }

do -- Core files
	Sources:File "core/HowlFileLoader.lua"
		:Name "HowlFile"
		:Depends { "Runner", "Utils", "Mediator", "Helpers" }
end

do -- Task files
	Sources:File "tasks/Context.lua"
		:Name "Context"
		:Depends { "Helpers", "Utils" }
	Sources:File "tasks/Task.lua"
		:Name "Task"
		:Depends "Utils"
	Sources:File "tasks/Runner.lua"
		:Name "Runner"
		:Depends { "Context", "Task", "Utils"}

	Sources:File "tasks/Extensions.lua"
		:Alias "Task.Extensions"
		:Depends { "Runner", "Utils" }
end

do -- Dependencies
	Sources:File "depends/Combiner.lua"
		:Alias "Depends.Combiner"
		:Depends { "Depends", "Helpers", "Runner", "Task", "Combiner.Verify", "Combiner.Traceback"}
end

do -- Files
	Sources:File "files/Files.lua"
		:Name "Files"
		:Depends "Utils"

	Sources:File "files/Compilr.lua"
		:Alias "Compilr"
		:Depends { "Files", "Helpers", "Rebuild", "Runner" }
	Sources:File "files/Require.lua"
		:Alias "Require"
		:Depends { "Files", "Runner" }
end

do -- External tools
	Sources:File "external/Busted.lua"
		:Alias "Busted"
		:Depends "Utils"
end


if Options:Get("with-interop") then
	Sources:File "interop/native/Colors.lua"     :Name "colors"
	Sources:File "interop/native/FileSystem.lua" :Name "fs"
	Sources:File "interop/native/Terminal.lua"
		:Name "term"
		:Depends "colors"
	Sources:File "interop/native/Helpers.lua"
		:Name "Helpers"
		:Prerequisite { "colors", "fs", "term" }
else
	Sources:File "interop/CC.lua" :Name "Helpers"
end

Tasks:Clean("clean", "build")
Tasks:Combine("combine", Sources, "build/Howl.lua", {"clean"})
	:Verify()

Tasks:Minify("minify", "build/Howl.lua", "build/Howl.min.lua")
	:Description("Produces a minified version of the code")

Tasks:CreateBootstrap("boot", Sources, "build/Boot.lua", {"clean"})
	:Traceback()

Tasks:Task "build" { "minify", "boot" }
	:Description "Minify and bootstrap"
