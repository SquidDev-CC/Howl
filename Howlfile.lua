do -- Setup options
	-- By default we want to include the minify and depends library
	-- and print a trace on errors
	Options:Default "trace"
	Options:Option "with-minify"
		:Description "Include the minify library"
		:Alias "wm"
		:Default()

	Options:Option "with-depends"
		:Description "Include the dependencies library"
		:Alias "wd"
		:Default()

	Options:Option "with-dump"
		:Description "Include the dumper"

	Options:Option "with-files"
		:Description "Include the files library"
		:Alias "wf"

	Options:Option "with-interop"
		:Description "Include the interop library"
		:Alias "wi"
end

Sources:Main "Howl.lua"
	:Depends "Runner"
	:Depends "ArgParse"
	:Depends "HowlFile"

	-- Not needed but we include
	:Depends "Task.Extensions"
	:Depends "Combiner"
	:Depends "Bootstrap"

do -- Core files
	Sources:File "core/ArgParse.lua"
		:Name "ArgParse"
		:Depends "Utils"

	Sources:File "core/Utils.lua"          :Name "Utils"
	Sources:File "core/HowlFileLoader.lua" :Name "HowlFile"
	Sources:File "core/Dump.lua"           :Name "Dump"
end

do -- Task files
	Sources:File "tasks/Context.lua"
		:Name "Context"
		:Depends "Utils"
		:Depends "HowlFile"

	Sources:File "tasks/Task.lua"
		:Name "Task"
		:Depends "Utils"

	Sources:File "tasks/Runner.lua"
		:Name "Runner"
		:Depends "Context"
		:Depends "Task"
		:Depends "Utils"

	Sources:File "tasks/Extensions.lua"
		:Alias "Task.Extensions"
		:Depends "HowlFile"
		:Depends "Runner"
		:Depends "Utils"
end

do
	Sources:File "depends/Depends.lua"
		:Name "Depends"

	Sources:File "depends/Combiner.lua"
		:Alias "Combiner"
		:Depends "Depends"
		:Depends "HowlFile"
		:Depends "Runner"

	Sources:File "depends/Bootstrap.lua"
		:Alias "Bootstrap"
		:Depends "Depends"
		:Depends "HowlFile"
		:Depends "Runner"
end

do -- Minification
	Sources:File "lexer/Parse.lua"
		:Name "Parse"
		:Depends "Constants"
		:Depends "Scope"
		:Depends "TokenList"

	Sources:File "lexer/Rebuild.lua"
		:Name "Rebuild"
		:Depends "Constants"

	Sources:File "lexer/Scope.lua"
		:Name "Scope"
		:Depends "Scope"

	Sources:File "lexer/TokenList.lua" :Name "TokenList"
	Sources:File "lexer/Constants.lua" :Name "Constants"

	Sources:File "lexer/Tasks.lua"
		:Alias "Lexer.Tasks"
		:Depends "HowlFile"
		:Depends "Parse"
		:Depends "Rebuild"
end

do -- Minification
	Sources:File "files/Files.lua"
		:Name "Files"
		:Depends "Utils"
		:Depends "HowlFile"

	Sources:File "files/Compilr.lua"
		:Alias "Compilr"
		:Depends "Files"
		:Depends "Runner"
		:Depends "Parse"
		:Depends "Rebuild"
end

do -- Interop
	Sources:File "interop/Colors.lua"     :Name "colors"
	Sources:File "interop/FileSystem.lua" :Name "fs"
	Sources:File "interop/Shell.lua"      :Name "shell"

	Sources:File "interop/Terminal.lua"
		:Name "term"
		:Depends "colors"

	Sources:File "interop/Globals.lua"
		:Alias "InteropGlobals"
		:Depends "term"
		:Depends "colors"
end

if Options:Get("with-dump") then
	Sources:Depends "Dump"
end

if Options:Get("with-minify") then
	Sources:Depends "Lexer.Tasks"
end

if Options:Get("with-depends") then
	Sources:Depends{"Bootstrap", "Combiner"}
end

if Options:Get("with-files") then
	Sources:Depends{"Compilr"}
end

if Options:Get("with-interop") then
	Sources
		:Prerequisite "InteropGlobals"
		:Prerequisite "shell"
		:Prerequisite "fs"
		:Prerequisite "term"
end

Tasks:Clean("clean", "build")
Tasks:Combine("combine", Sources, "build/Howl.lua", {"clean"})

Tasks:Minify("minify", "build/Howl.lua", "build/Howl.min.lua")
	:Description("Produces a minified version of the code")

Tasks:CreateBootstrap("boot", Sources, "build/Boot.lua", {"clean"})

Tasks:Task "build"{"minify", "boot"}
	:Description "Minify and bootstrap"