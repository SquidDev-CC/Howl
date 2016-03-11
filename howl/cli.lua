--- Core script for Howl
-- @script howl.cli

local ArgParse = require "howl.lib.argparse"
local HowlFile = require "howl.loader"
local Mediator = require "howl.lib.mediator"
local Utils = require "howl.lib.utils"
local colored = require "howl.lib.colored"
local fs = require "howl.platform".fs

require "howl.tasks.extensions"
require "howl.depends.bootstrap"
require "howl.depends.combiner"
require "howl.lexer.tasks"
require "howl.external.busted"
require "howl.files.compilr"
require "howl.files.require"

local howlFile, currentDirectory = HowlFile.FindHowl()
local context = require "howl.context"(currentDirectory or shell.dir(), {... })
local options = context.arguments

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
if not howlFile then
	if options:Get("help") or (#taskList == 1 and taskList[1] == "help") then
		colored.printColor("yellow", "Howl")
		colored.printColor("lightGrey", "Howl is a simple build system for Lua")
		colored.printColor("grey", "You can read the full documentation online: https://github.com/SquidDev-CC/Howl/wiki/")

		colored.printColor("white", (([[
			The key thing you are missing is a HowlFile. This can be "Howlfile" or "Howlfile.lua".
			Then you need to define some tasks. Maybe something like this:
		]]):gsub("\t", ""):gsub("\n+$", "")))

		colored.printColor("magenta", 'Tasks:Minify("minify", "Result.lua", "Result.min.lua")')

		colored.printColor("white", "Now just run `Howl minify`!")
	end
	error("Cannot find Howlfile", 0)
end

context.logger:verbose("Found HowlFile at " .. fs.combine(currentDirectory, howlFile))

context.mediator:subscribe({ "ArgParse", "changed" }, function(options)
	if options:Get "help" then
		taskList = { "help" }
	end
end)

local tasks, environment = HowlFile.SetupTasks(context, howlFile)

-- Basic list tasks
tasks:Task "list" (function()
	tasks:ListTasks()
end):Description "Lists all the tasks"

tasks:Task "help" (function()
	print("Howl [options] [task]")
	colored.printColor("orange", "Tasks:")
	tasks:ListTasks("  ")

	colored.printColor("orange", "\nOptions:")
	options:Help("  ")
end):Description "Print out a detailed usage for Howl"

-- If no other task exists run this
tasks:Default(function()
	context.logger:error("No default task exists.")
	context.logger:verbose("Use 'Tasks:Default' to define a default task")
	colored.printColor("orange", "Choose from: ")
	tasks:ListTasks("  ")
end)

environment.dofile(fs.combine(currentDirectory, howlFile))

-- Run the task
tasks:RunMany(taskList)
