local sources = Dependencies(CurrentDirectory)
sources:Main "Howl.lua"
	:Depends "Combiner"
	:Depends "Depends"
	:Depends "Task"
	:Depends "ArgParse"
	:Depends "HowlFile"

sources:File "Task.lua"
	:Name "Task"
	:Depends "Utils"

sources:File "Combiner.lua"
	:Alias "Combiner"
	:Depends "Depends"
	:Depends "Task"

sources:File "Extensions.lua"
	:Alias "Extensions"
	:Depends "Task"

sources:File "Utils.lua"          :Name "Utils"
sources:File "HowlFileLoader.lua" :Name "HowlFile"
sources:File "ArgParse.lua"       :Name "ArgParse"
sources:File "Depends.lua"        :Name "Depends"

Tasks:Combine("combine", sources, "result.lua")