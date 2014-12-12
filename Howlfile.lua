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
	:Depends "Depends"

-- Task files
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

sources:File "depends/Combiner.lua"
	:Alias "Combiner"
	:Depends "Depends"
	:Depends "Runner"

sources:File "tasks/Extensions.lua"
	:Alias "Task.Extensions"
	:Depends "Runner"
	:Depends "Utils"

sources:File "core/Utils.lua"          :Name "Utils"
sources:File "core/HowlFileLoader.lua" :Name "HowlFile"
sources:File "core/ArgParse.lua"       :Name "ArgParse"
sources:File "depends/Depends.lua"     :Name "Depends"

if Options:Get("with-dump") then
	sources:File "core/Dump.lua"       :Name "Dump"
	sources.mainFiles[1]:Depends "Dump" -- Hacky fix to require the file
end

if Options:Get("with-minify") then
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

	sources.mainFiles[1]
		:Depends "Minify"
end

Tasks:Clean("clean", File "build")
Tasks:Combine("combine", sources, File "build/Howl.lua", {"clean"})

Tasks:MinifyAll()

Tasks:AddTask "minify"
	:Requires(File "build/Howl.min.lua")
	:Description("Produces a minified version of the code")
