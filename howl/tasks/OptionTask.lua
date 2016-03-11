--- A Task that can store options
-- @classmod howl.tasks.OptionTask

local Task = require "howl.tasks.Task"

local OptionTask = Task:subclass("howl.tasks.OptionTask")

function OptionTask:initialize(name, dependencies, keys, action)
	Task.initialize(self, name, dependencies, action)

	local options = {}
	self.options = options
	for _, key in ipairs(keys) do
		local func = function(value)
			if value == nil then value = true end
			options[key] = value
			return self
		end

		self[key:gsub("^%l", string.upper)] = func
		self[key] = func
	end
end

return OptionTask
