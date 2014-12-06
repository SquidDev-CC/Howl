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
	local format = (indent or "" ) .. "%-" .. maxLength + 2 .. "s%s"
	for name, description in pairs(taskNames) do
		print(string.format(format, name, description))
	end

	return self
end