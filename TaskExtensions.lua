--- @module Extensions

--- Prints all tasks in a TaskRunner
-- @treturn TaskRunner The current task runner (allows chaining)
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
-- @tparam string Name of the task
-- @tparam string directory The directory to clean
-- @tparam table A list of tasks this task requires
-- @treturn TaskRunner The task runner (for chaining)
function Task.TaskRunner:Clean(name, directory, taskDepends)
	return self:AddTask(name, taskDepends, function()
		Utils.Verbose("Emptying directory '" .. directory .. "'")
		fs.delete(directory)
	end):Description("Clean the '" .. directory .. "' directory")
end