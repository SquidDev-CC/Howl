--- Basic extensions to classes
-- @module Task.Extensions

--- Prints all tasks in a TaskRunner
-- Extends the @{Task.TaskRunner} class
-- @tparam string indent The indent to print at
-- @treturn Task.TaskRunner The current task runner (allows chaining)
function Task.TaskRunner:ListTasks(indent)
	local taskNames = {}
	local maxLength = 0
	for name, task in pairs(self.tasks) do
		local description =  task.description or ""
		local length = #name
		if length > maxLength then
			maxLength = length
		end

		taskNames[name] = description
	end

	maxLength = maxLength + 2
	indent = indent or ""
	for name, description in pairs(taskNames) do
		Utils.Print(indent .. name .. string.rep(" ", maxLength - #name) .. description)
	end

	return self
end

--- A task for cleaning a directory
-- Extends the @{Task.TaskRunner} class
-- @tparam string name Name of the task
-- @tparam string directory The directory to clean
-- @tparam table taskDepends A list of tasks this task requires
-- @treturn Task.TaskRunner The task runner (for chaining)
function Task.TaskRunner:Clean(name, directory, taskDepends)
	return self:AddTask(name, taskDepends, function()
		Utils.Verbose("Emptying directory '" .. directory .. "'")
		fs.delete(directory)
	end):Description("Clean the '" .. directory .. "' directory")
end