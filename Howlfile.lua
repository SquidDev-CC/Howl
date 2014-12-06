local sources = Dependencies(CurrentDirectory)
sources:Main "Howl.lua"
	:Depends "Task"
	:Depends "ArgParse"
	:Depends "HowlFile"

	-- Not needed but we include
	:Depends "TaskExtensions"
	:Depends "Combiner"
	:Depends "Depends"

sources:File "Task.lua"
	:Name "Task"
	:Depends "Utils"

sources:File "Combiner.lua"
	:Alias "Combiner"
	:Depends "Depends"
	:Depends "Task"

sources:File "TaskExtensions.lua"
	:Alias "TaskExtensions"
	:Depends "Task"
	:Depends "Utils"

sources:File "Utils.lua"          :Name "Utils"
sources:File "HowlFileLoader.lua" :Name "HowlFile"
sources:File "ArgParse.lua"       :Name "ArgParse"
sources:File "Depends.lua"        :Name "Depends"

Tasks:Clean("clean", fs.combine(CurrentDirectory, "build"))
Tasks:Combine("combine", sources, "build/Howl.lua", {"clean"})