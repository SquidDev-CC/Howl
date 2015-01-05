--- Core script for Howl
-- @script Howl

local options = ArgParse.Options({...})
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

local tasks = Runner.Factory()
local taskList = options:Arguments()

options:OnChanged(function(options)
	Utils.SetVerbose(options:Get "verbose")
	tasks.ShowTime = options:Get "time"
	tasks.Traceback = options:Get "trace"

	if options:Get "help" then
		taskList = {"help"}
	end
end)

-- Locate the howl file
local howlFile, currentDirectory = HowlFile.FindHowl()
HowlFile.CurrentDirectory = currentDirectory
Utils.Verbose("Found HowlFile at " .. fs.combine(currentDirectory, howlFile))

-- SETUP TASKS
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
if #taskList == 0 then
	tasks:Run()
else
	tasks:RunMany(taskList)
end