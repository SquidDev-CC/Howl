local sources = Dependencies(CurrentDirectory)
sources:Main "Howl.lua"
	:Depends "Task"
	:Depends "ArgParse"
	:Depends "HowlFile"

	-- Not needed but we include
	:Depends "Task.Extensions"
	:Depends "Combiner"
	:Depends "Depends"

sources:File "tasks/Task.lua"
	:Name "Task"
	:Depends "Utils"

sources:File "depends/Combiner.lua"
	:Alias "Combiner"
	:Depends "Depends"
	:Depends "Task"

sources:File "tasks/Extensions.lua"
	:Alias "Task.Extensions"
	:Depends "Task"
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

Tasks:Clean("clean", fs.combine(CurrentDirectory, "build"))
Tasks:Combine("combine", sources, "build/Howl.lua", {"clean"})
Tasks:Minify("minify", File "build/Howl.lua", File "build/Howl.min.lua", {"combine"})
