--- Lists all tasks on a runner.
-- @module howl.modules.list

local assert = require "howl.lib.assert"
local colored = require "howl.lib.colored"

local Runner = require "howl.tasks.Runner"

local ListTasksExtensions = { }

function ListTasksExtensions:listTasks(indent, all)
	local taskNames = {}
	local maxLength = 0
	for name, task in pairs(self.tasks) do
		local start = name:sub(1, 1)
		if all or (start ~= "_" and start ~= ".") then
			local description = task.options.description or ""
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
		colored.writeColor("white", indent .. name)
		colored.printColor("lightGray", string.rep(" ", maxLength - #name) .. description)
	end

	return self
end

local function apply()
	Runner:include(ListTasksExtensions)
end

return {
	name = "list",
	description = "List all tasks on a runner.",
	apply = apply,
}
