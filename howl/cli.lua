--- Core script for Howl
-- @script howl.cli

local loader = require "howl.loader"
local colored = require "howl.lib.colored"
local fs = require "howl.platform".fs

local howlFile, currentDirectory = loader.FindHowl()
-- TODO: Don't pass the error message as the current directory: construct mediator/arg parser another time.
local context = require "howl.context"(currentDirectory or shell.dir(), {...})

local function include(module)
	context.logger:verbose("Including " .. module.name .. ": " .. module.description)
	module.apply()
	if module.setup then module.setup(context) end
end

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

require "howl.depends.bootstrap"
require "howl.depends.combiner"
require "howl.external.busted"

include(require "howl.modules.dependencies.FileDependency")
include(require "howl.modules.dependencies.TaskDependency")
include(require "howl.modules.list")
include(require "howl.modules.tasks.clean")
include(require "howl.modules.tasks.gist")
include(require "howl.modules.tasks.minify")
include(require "howl.modules.tasks.pack")
include(require "howl.modules.tasks.require")

-- SETUP TASKS
local taskList = options:Arguments()
local function setHelp()
	if options:Get "help" then
		taskList = { "help" }
	end
end
context.mediator:subscribe({ "ArgParse", "changed" }, setHelp)
setHelp()

-- Locate the howl file
if not howlFile then
	if #taskList == 1 and taskList[1] == "help" then
		colored.writeColor("yellow", "Howl")
		colored.printColor("lightGrey", " is a simple build system for Lua")
		colored.printColor("grey", "You can read the full documentation online: https://github.com/SquidDev-CC/Howl/wiki/")

		colored.printColor("white", (([[
			The key thing you are missing is a HowlFile. This can be "Howlfile" or "Howlfile.lua".
			Then you need to define some tasks. Maybe something like this:
		]]):gsub("\t", ""):gsub("\n+$", "")))

		colored.printColor("magenta", 'Tasks:minify("minify", "file.lua", "file.min.lua")')

		colored.printColor("white", "Now just run '" .. shell.getRunningProgram() .. " minify'!")

		colored.printColor("orange", "\nOptions:")
		options:Help("  ")
	elseif #taskList == 0 then
		error(currentDirectory .. " Use " .. shell.getRunningProgram() .. " --help to dislay usage.", 0)
	else
		error(currentDirectory, 0)
	end

	return
end

context.logger:verbose("Found HowlFile at " .. fs.combine(currentDirectory, howlFile))

local tasks, environment = loader.SetupTasks(context, howlFile)

-- Basic list tasks
tasks:Task "list" (function()
	tasks:listTasks()
end):description "Lists all the tasks"

tasks:Task "help" (function()
	print("Howl [options] [task]")
	colored.printColor("orange", "Tasks:")
	tasks:listTasks("  ")

	colored.printColor("orange", "\nOptions:")
	options:Help("  ")
end):description "Print out a detailed usage for Howl"

-- If no other task exists run this
tasks:Default(function()
	context.logger:error("No default task exists.")
	context.logger:verbose("Use 'Tasks:Default' to define a default task")
	colored.printColor("orange", "Choose from: ")
	tasks:listTasks("  ")
end)

environment.dofile(fs.combine(currentDirectory, howlFile))

if not tasks:setup() then
	error("Error setting up tasks", 0)
end

-- Run the task
if not tasks:RunMany(taskList) then
	error("Error running tasks", 0)
end
