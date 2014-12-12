--- Core script for Howl
-- @module Howl

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
local currentTask = options:Arguments()[1]

options:OnChanged(function(options)
	Utils.SetVerbose(options:Get "verbose")
	tasks.ShowTime = options:Get "time"
	tasks.Traceback = options:Get "trace"

	if options:Get "help" then
		currentTask = "help"
	end
end)

-- Locate the howl file
local howlFile, currentDirectory = HowlFile.FindHowl()
Utils.Verbose("Found HowlFile at " .. fs.combine(currentDirectory, howlFile))

-- SETUP TASKS
-- Basic list tasks
tasks:Task "list" (function()
	tasks:ListTasks()
end):Description "Lists all the tasks"

tasks:Task "help" (function()
	Utils.Print("Howl [options] [task]\nTasks:")
	tasks:ListTasks("  ")

	Utils.Print("\nOptions:")
	options:Help("  ")
end):Description "Print out a detailed usage for Howl"

-- If no other task exists run this
tasks:Default(function()
	Utils.PrintError("No default task exists.")
	Utils.Verbose("Use 'Tasks:Default' to define a default task")
	Utils.Print("Choose from: ")
	tasks:ListTasks("  ")
end)

-- Setup an environment
local environment = HowlFile.SetupEnvironment({
	CurrentDirectory = currentDirectory,
	Tasks = tasks,
	Options = options,
	Dependencies = Depends.Depends,
	Verbose = Utils.Verbose,
	File = function(...) return fs.combine(currentDirectory, ...) end
}, currentDirectory)

-- Load the file
environment.dofile(howlFile)

-- Run the task
tasks:Run(currentTask)