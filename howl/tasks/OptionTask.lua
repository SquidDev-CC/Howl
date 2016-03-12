--- A Task that can store options
-- @classmod howl.tasks.OptionTask

local assert = require "howl.lib.assert"
local mixin = require "howl.class.mixin"

local Task = require "howl.tasks.Task"

local OptionTask = Task:subclass("howl.tasks.OptionTask")
	:include(mixin.configurable)

function OptionTask:initialize(name, dependencies, keys, action)
	Task.initialize(self, name, dependencies, action)

	self.options = {}
	self.optionKeys = {}
	for _, key in ipairs(keys or {}) do
		self:addOption(key)
	end
end

function OptionTask:addOption(key)
	local options = self.options
	local func = function(value)
		if value == nil then value = true end
		options[key] = value
		return self
	end

	self.optionKeys[key] = true
	self[key:gsub("^%l", string.upper)] = func
	self[key] = func
end

function OptionTask:configure(item)
	assert.argType(item, "table", "configure", 1)

	for k, v in pairs(item) do
		if self.optionKeys[k] then
			self.options[k] = v
		else
			-- TODO: Configure filtering
			-- error("Unknown option " .. tostring(k), 2)
		end
	end
end

return OptionTask
