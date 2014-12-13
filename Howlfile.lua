Options:Default("trace")
Options:Default("with-minify")

local sources = Dependencies(CurrentDirectory)
sources:Main "Howl.lua"
	:Depends "Runner"
	:Depends "ArgParse"
	:Depends "HowlFile"

	-- Not needed but we include
	:Depends "Task.Extensions"
	:Depends "Combiner"
	:Depends "Bootstrap"
	:Depends "Depends"

do -- Core files
	sources:File "core/Utils.lua"          :Name "Utils"
	sources:File "core/HowlFileLoader.lua" :Name "HowlFile"
	sources:File "core/ArgParse.lua"       :Name "ArgParse"
	sources:File "core/Dump.lua"           :Name "Dump"
end

do -- Task files
	sources:File "tasks/Context.lua"
		:Name "Context"
		:Depends "Utils"

	sources:File "tasks/Task.lua"
		:Name "Task"
		:Depends "Utils"

	sources:File "tasks/Runner.lua"
		:Name "Runner"
		:Depends "Utils"
		:Depends "Task"
		:Depends "Context"

	sources:File "tasks/Extensions.lua"
		:Alias "Task.Extensions"
		:Depends "Runner"
		:Depends "Utils"
end

do -- Dependencies
	sources:File "depends/Depends.lua"
		:Name "Depends"

	sources:File "depends/Combiner.lua"
		:Alias "Combiner"
		:Depends "Depends"
		:Depends "Runner"

	sources:File "depends/Bootstrap.lua"
		:Alias "Bootstrap"
		:Depends "Depends"
		:Depends "Runner"
end

do -- Minification
	sources:File "lexer/Parse.lua"
		:Name "Parse"
		:Depends "Constants"
		:Depends "Scope"
		:Depends "TokenList"

	sources:File "lexer/Rebuild.lua"
		:Name "Rebuild"
		:Depends "Constants"

	sources:File "lexer/Scope.lua"
		:Name "Scope"
		:Depends "Scope"

	sources:File "lexer/TokenList.lua" :Name "TokenList"
	sources:File "lexer/Constants.lua" :Name "Constants"

	sources:File "lexer/Tasks.lua"
		:Alias "Minify"
		:Depends "Parse"
		:Depends "Rebuild"
end

if Options:Get("with-dump") then
	sources.mainFiles[1]:Depends "Dump" -- Hacky fix to require the file
end

if Options:Get("with-minify") then
	sources.mainFiles[1]:Depends "Minify"
end

Tasks:Clean("clean", File "build")
Tasks:Combine("combine", sources, File "build/Howl.lua", {"clean"})

Tasks:Minify("minify", File "build/Howl.lua", File "build/Howl.min.lua")
	:Description("Produces a minified version of the code")

Tasks:CreateBootstrap("boot", sources, File "build/Boot.lua", {"clean"})
