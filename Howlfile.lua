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
	:Depends { "Task.Extensions", "Depends.Bootstrap", "Depends.Combiner", "Lexer.Tasks", "Busted", "Compilr" }

do -- Core files
	Sources:File "core/ArgParse.lua"
		:Name "ArgParse"
		:Depends { "Mediator", "Utils" }
	Sources:File "core/Mediator.lua"
		:Name "Mediator"
		:Depends "Utils"
	Sources:File "core/Utils.lua"
		:Name "Utils"
		:Depends { "Dump", "Helpers" }
	Sources:File "core/HowlFileLoader.lua"
		:Name "HowlFile"
		:Depends "Helpers"
	Sources:File "core/Dump.lua"
		:Name "Dump"
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
	Sources:File "depends/Depends.lua"
		:Name "Depends"
		:Depends "Mediator"

	Sources:File "depends/Combiner.lua"
		:Alias "Depends.Combiner"
		:Depends { "Depends", "Helpers", "Runner", "Task", "Combiner.Verify", "Combiner.Traceback"}

	Sources:File "depends/modules/Verify.lua"
		:Alias "Combiner.Verify"
		:Depends "Mediator"

	Sources:File "depends/modules/Traceback.lua"
		:Alias "Combiner.Traceback"
		:Depends { "Helpers", "Mediator" }

	Sources:File "depends/Bootstrap.lua"
		:Alias "Depends.Bootstrap"
		:Depends { "Depends", "Runner" }
end

do -- Minification
	Sources:File "lexer/Parse.lua"
		:Name "Parse"
		:Depends { "Constants", "Scope", "TokenList", "Utils" }

	Sources:File "lexer/Rebuild.lua"
		:Name "Rebuild"
		:Depends { "Constants", "Helpers", "Parse" }

	Sources:File "lexer/Scope.lua"
		:Name "Scope"
		:Depends "Scope"

	Sources:File "lexer/Tasks.lua"
		:Alias "Lexer.Tasks"
		:Depends { "Mediator", "Rebuild" }

	Sources:File "lexer/TokenList.lua" :Name "TokenList"
	Sources:File "lexer/Constants.lua"
		:Name "Constants"
		:Depends "Utils"
end

do -- Files (Compilr)
	Sources:File "files/Files.lua"
		:Name "Files"
		:Depends "Utils"

	Sources:File "files/Compilr.lua"
		:Alias "Compilr"
		:Depends { "Files", "Helpers", "Rebuild", "Runner" }
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
