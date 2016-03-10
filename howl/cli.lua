--- Core script for Howl
-- @script howl.cli

local ArgParse = require "howl.lib.argparse"
local HowlFile = require "howl.loader"
local Mediator = require "howl.lib.mediator"
local Utils = require "howl.lib.utils"

require "howl.tasks.extensions"
require "howl.depends.bootstrap"
require "howl.depends.combiner"
require "howl.lexer.tasks"
require "howl.external.busted"
require "howl.files.compilr"
require "howl.files.require"

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

-- SETUP TASKS
local taskList = options:Arguments()

-- Locate the howl file
local howlFile, currentDirectory = HowlFile.FindHowl()
if not howlFile then
	if options:Get("help") or (#taskList == 1 and taskList[1] == "help") then
		Utils.PrintColor(colours.yellow, "Howl")
		Utils.PrintColor(colours.lightGrey, "Howl is a simple build system for Lua")
		Utils.PrintColor(colours.grey, "You can read the full documentation online: https://github.com/SquidDev-CC/Howl/wiki/")

		Utils.PrintColor(colours.white, (([[
			The key thing you are missing is a HowlFile. This can be "Howlfile" or "Howlfile.lua".
			Then you need to define some tasks. Maybe something like this:
		]]):gsub("\t", ""):gsub("\n+$", "")))

		Utils.PrintColor(colours.magenta, 'Tasks:Minify("minify", "Result.lua", "Result.min.lua")')

		Utils.PrintColor(colours.white, "Now just run `Howl minify`!")
	end
	error(currentDirectory, 0)
end

Utils.Verbose("Found HowlFile at " .. fs.combine(currentDirectory, howlFile))

Mediator.Subscribe({ "ArgParse", "changed" }, function(options)
	Utils.IsVerbose(options:Get("verbose") or false)
	if options:Get "help" then
		taskList = { "help" }
	end
end)

local tasks, environment = HowlFile.SetupTasks(currentDirectory, howlFile, options)

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

environment.dofile(fs.combine(currentDirectory, howlFile))

-- Run the task
tasks:RunMany(taskList)
