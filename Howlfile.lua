Sources:File "download.lua"
	:Name "download"
	:Depends "json"
Sources:File "json.lua" :Name "json"
Sources:File "vfs.lua"  :Name "vfs"

Sources:Main "WebBuild.lua"
	:Depends "download"
	:Depends "vfs"

Tasks:Clean("clean", "build")
Tasks:Combine("combine", Sources, "build/WebBuild.lua", {"clean"})
	:Verify()
	:Traceback()
	:LineMapping()

Tasks:Minify("minify", "build/WebBuild.lua", "build/WebBuild.min.lua")

Tasks:Task "build" { "combine", "minify" }
Tasks:Default "build"
