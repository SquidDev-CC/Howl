--- @module Howl
local parser = ArgParse({...})
parser
	:Switch "verbose"
	:Shortcut "v"
parser
	:Switch "time"
	:Shortcut "t"
parser
	:Switch "trace"
parser
	:Argument "task"

-- Setup listener for verbosity
parser:OnChanged(function(self, options)
	Utils.SetVerbose(options.verbose)
end)

local tasks = Task.Tasks()
-- Setup listener for time
parser:OnChanged(function(self, options)
	tasks.ShowTime = options.time
	tasks.Traceback = options.trace
end)

parser:Options() -- Setup options

-- Locate the howl file
local howlFile, currentDirectory = HowlFile.FindHowl()
Utils.Verbose("Found HowlFile at " .. fs.combine(currentDirectory, howlFile))

-- Basic list tasks
tasks:Task "list" (function()
	tasks:ListTasks()
end):Description "Lists all the tasks"

tasks:Task "help" (function()
	Utils.Print("Howl [-v] [-t] <task>\nAvaliable tasks: ")
	tasks:ListTasks("  ")

	Utils.Print([[Options:
  -v/-verbose  Verbose output
  -t/-time     Show time taken for tasks

Use -not-{name} or -n{short} to switch an option off
]])

end)

-- If no other task exists run this
tasks:Default(function()
	Utils.PrintError("No default task exists.")
	Utils.Verbose("Use 'Tasks:Default' to define a default task")
	Utils.Print("Choose from: ")
	tasks:ListTasks(" - ")
end)

-- Setup an environment
local environment = HowlFile.SetupEnvironment({
	CurrentDirectory = currentDirectory,
	Tasks = tasks,
	Options = parser,
	Dependencies = Depends.Depends,
	Verbose = Utils.Verbose,
	File = function(...) return fs.combine(currentDirectory, ...) end
}, currentDirectory)

-- Load the file
environment.dofile(howlFile)

-- Run the task
tasks:Run(parser:Options().task)