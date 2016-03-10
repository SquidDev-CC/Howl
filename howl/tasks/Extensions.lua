--- Basic extensions to classes
-- @module howl.tasks.extensions

local Runner = require "howl.tasks.runner"
local Utils = require "howl.lib.utils"

--- Prints all tasks in a TaskRunner
-- Extends the @{Runner.Runner} class
-- @tparam string indent The indent to print at
-- @tparam boolean all Include all tasks (otherwise exclude ones starting with _)
-- @treturn Runner.Runner The current task runner (allows chaining)
function Runner.Runner:ListTasks(indent, all)
	local taskNames = {}
	local maxLength = 0
	for name, task in pairs(self.tasks) do
		local start = name:sub(1, 1)
		if all or (start ~= "_" and start ~= ".") then
			local description = task.description or ""
			local length = #name
			if length > maxLength then
				maxLength = length
			end

			taskNames[name] = description
		end
	end

	maxLength = maxLength + 2
	indent = indent or ""
	for name, description in pairs(taskNames) do
		Utils.WriteColor(colors.white, indent .. name)
		Utils.PrintColor(colors.lightGray, string.rep(" ", maxLength - #name) .. description)
	end

	return self
end

--- A task for cleaning a directory
-- Extends the @{Runner.Runner} class
-- @tparam string name Name of the task
-- @tparam string directory The directory to clean
-- @tparam table taskDepends A list of tasks this task requires
-- @treturn Runner.Runner The task runner (for chaining)
function Runner.Runner:Clean(name, directory, taskDepends)
	return self:AddTask(name, taskDepends, function(task, env)
		Utils.Verbose("Emptying directory '" .. directory .. "'")
		local file = fs.combine(env.CurrentDirectory, directory)
		if fs.isDir(file) then
			for _, sub in pairs(fs.list(file)) do
				fs.delete(fs.combine(file, sub))
			end
		else
			fs.delete(file)
		end
	end):Description("Clean the '" .. directory .. "' directory")
end
