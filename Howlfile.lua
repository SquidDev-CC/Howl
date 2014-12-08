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

Tasks:Clean("clean", fs.combine(CurrentDirectory, "build"))
Tasks:Combine("combine", sources, "build/Howl.lua", {"clean"})