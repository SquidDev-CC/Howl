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

	Options:Option "with-external"
		:Description "Include external tools"
		:Alias "we"

	Options:Option "with-all"
		:Description "Include all libraries"
		:Alias "a"

	-- If `with-all` is true, then include all libraries
	if Options:Get("with-all") then
		for name, _ in pairs(Options.settings) do
			if name:sub(1, 5) =="with-" and name ~= "with-interop" then -- Don't include interop library
				Options:Default(name)
			end
		end
	end
end

Sources:Main "Howl.lua"
	:Depends "ArgParse"
	:Depends "HowlFile"
	:Depends "Mediator"
	:Depends "Runner"

	-- Not needed but we include
	:Depends "Bootstrap"
	:Depends "Combiner"
	:Depends "Task.Extensions"

do -- Core files
	Sources:File "core/ArgParse.lua"
		:Name "ArgParse"
		:Depends "Mediator"
		:Depends "Utils"

	Sources:File "core/Mediator.lua"
		:Name "Mediator"
		:Depends "Utils"

	Sources:File "core/Utils.lua"          :Name "Utils"
		:Depends "Helpers"
	Sources:File "core/HowlFileLoader.lua" :Name "HowlFile"
		:Depends "Helpers"
	Sources:File "core/Dump.lua"           :Name "Dump"
end

do -- Task files
	Sources:File "tasks/Context.lua"
		:Name "Context"
		:Depends "Helpers"
		:Depends "HowlFile"
		:Depends "Utils"

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

do -- Dependencies
	Sources:File "depends/Depends.lua"
		:Name "Depends"
		:Depends "Mediator"

	Sources:File "depends/Combiner.lua"
		:Alias "Combiner"
		:Depends "Depends"
		:Depends "Helpers"
		:Depends "HowlFile"
		:Depends "Runner"
		:Depends "Task"
		:Depends {"Combiner.Verify", "Combiner.Traceback"}

	Sources:File "depends/Bootstrap.lua"
		:Alias "Bootstrap"
		:Depends "Depends"
		:Depends "HowlFile"
		:Depends "Runner"

	Sources:File "depends/modules/Verify.lua"
		:Alias "Combiner.Verify"
		:Depends "Mediator"

	Sources:File "depends/modules/Traceback.lua"
		:Alias "Combiner.Traceback"
		:Depends "Helpers"
		:Depends "Mediator"
end

do -- Minification
	Sources:File "lexer/Parse.lua"
		:Name "Parse"
		:Depends "Constants"
		:Depends "Scope"
		:Depends "TokenList"
		:Depends "Utils"

	Sources:File "lexer/Rebuild.lua"
		:Name "Rebuild"
		:Depends "Constants"
		:Depends "Helpers"
		:Depends "HowlFile"
		:Depends "Parse"

	Sources:File "lexer/Scope.lua"
		:Name "Scope"
		:Depends "Scope"

	Sources:File "lexer/Tasks.lua"
		:Alias "Lexer.Tasks"
		:Depends "Mediator"
		:Depends "Rebuild"

	Sources:File "lexer/TokenList.lua" :Name "TokenList"
	Sources:File "lexer/Constants.lua"
		:Name "Constants"
		:Depends "Utils"
end

do -- Files (Compilr)
	Sources:File "files/Files.lua"
		:Name "Files"
		:Depends "HowlFile"
		:Depends "Mediator"
		:Depends "Utils"

	Sources:File "files/Compilr.lua"
		:Alias "Compilr"
		:Depends "Files"
		:Depends "Helpers"
		:Depends "Rebuild"
		:Depends "Runner"
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

do -- External tools
	Sources:File "external/Busted.lua"
		:Alias "Busted"
		:Depends "Utils"
		:Depends "HowlFile"
end

do -- Options parsing
	if Options:Get("with-dump") then
		Verbose("Including 'Dump'")

		Sources:Depends "Dump"
		Sources:FindFile "Utils"
			:Depends "Dump"
	end

	if Options:Get("with-minify") then
		Verbose("Including Minify")
		Sources:Depends "Lexer.Tasks"
	end

	if Options:Get("with-depends") then
		Verbose("Including Depends")
		Sources:Depends{"Bootstrap", "Combiner"}
	end

	if Options:Get("with-files") then
		Verbose("Including Files")
		Sources:Depends{"Compilr"}
	end

	if Options:Get("with-external") then
		Verbose("Including External")
		Sources
			:Depends{"Busted"}
	end
end

Tasks:Clean("clean", "build")
Tasks:Combine("combine", Sources, "build/Howl.lua", {"clean"})
	:Verify()

Tasks:Minify("minify", "build/Howl.lua", "build/Howl.min.lua")
	:Description("Produces a minified version of the code")

Tasks:CreateBootstrap("boot", Sources, "build/Boot.lua", {"clean"})
	:Traceback()

Tasks:Task "build"{"minify", "boot"}
	:Description "Minify and bootstrap"
