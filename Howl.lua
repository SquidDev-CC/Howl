--- Core script for Howl
-- @script Howl

local options = ArgParse.Options({ ... })

options
	:Option "verbose"
	:Alias "v"
	:Description "Print verbose output"
options
	:Option "time"
	:Alias "t"
	:Description "Display the time taken for tasks"
options
	:Option "trace"
	:Description "Print a stack trace on errors"
options
	:Option "help"
	:Alias "?"
	:Alias "h"
	:Description "Print this help"

-- Locate the howl file
local howlFile, currentDirectory = HowlFile.FindHowl()
if not howlFile then
	if options:Get("help") or (#taskList == 1 and taskList[1] == "help") then
		Utils.PrintColor(colors.yellow, "Howl")
		Utils.PrintColor(colors.lightGrey, "Howl is a simple build system for Lua")
		Utils.PrintColor(colors.grey, "You can read the full documentation online: https://github.com/SquidDev-CC/Howl/wiki/")

		Utils.PrintColor(colors.white, (([[
			The key thing you are missing is a HowlFile. This can be "Howlfile" or "Howlfile.lua".
			Then you need to define some tasks. Maybe something like this:
		]]):gsub("\t", "")))

		Utils.PrintColor(colors.pink, 'Tasks:Minify("minify", "Result.lua", "Result.min.lua")')

		Utils.PrintColor(colors.white, "Now just run `Howl minify`!")
	end
	error(currentDirectory, 0)
end

Utils.Verbose("Found HowlFile at " .. fs.combine(currentDirectory, howlFile))

-- SETUP TASKS
local tasks = Runner.Factory({ CurrentDirectory = currentDirectory })
local taskList = options:Arguments()

Mediator.Subscribe({ "ArgParse", "changed" }, function(options)
	Utils.IsVerbose(options:Get("verbose") or false)
	tasks.ShowTime = options:Get "time"
	tasks.Traceback = options:Get "trace"

	if options:Get "help" then
		taskList = { "help" }
	end
end)

-- Basic list tasks
tasks:Task "list" (function()
	tasks:ListTasks()
end):Description "Lists all the tasks"

tasks:Task "help" (function()
	Utils.Print("Howl [options] [task]")
	Utils.PrintColor(colors.orange, "Tasks:")
	tasks:ListTasks("  ")

	Utils.PrintColor(colors.orange, "\nOptions:")
	options:Help("  ")
end):Description "Print out a detailed usage for Howl"

-- If no other task exists run this
tasks:Default(function()
	Utils.PrintError("No default task exists.")
	Utils.Verbose("Use 'Tasks:Default' to define a default task")
	Utils.PrintColor(colors.orange, "Choose from: ")
	tasks:ListTasks("  ")
end)

-- Setup an environment
local environment = HowlFile.SetupEnvironment({
	-- Core globals
	CurrentDirectory = currentDirectory,
	Tasks = tasks,
	Options = options,
	-- Helper functions
	Verbose = Utils.Verbose,
	Log = Utils.VerboseLog,
	File = function(...) return fs.combine(currentDirectory, ...) end,
})

-- Load the file
environment.dofile(fs.combine(currentDirectory, howlFile))

-- Run the task
tasks:RunMany(taskList)
