--- The main logger for Lua
-- @classmod howl.lib.Logger

local class = require "howl.class"
local mixin = require "howl.class.mixin"
local dump = require "howl.lib.dump"
local colored = require "howl.lib.colored"

local Logger = class("howl.lib.Logger")
	:include(mixin.sealed)
	:include(mixin.curry)

function Logger:initialize(context)
	self.isVerbose = false
	context.mediator:subscribe({ "ArgParse", "changed" }, function(options)
		self.isVerbose = options:Get "verbose" or false
	end)
end

--- Print a series of objects if verbose mode is enabled
function Logger:verbose(...)
	if self.isVerbose then
		local _, m = pcall(function() error("", 4) end)
		colored.writeColor("gray", m)
		colored.printColor("lightGray", ...)
	end
end

--- Dump a series of objects if verbose mode is enabled
function Logger:dump(...)
	if self.isVerbose then
		local _, m = pcall(function() error("", 4) end)
		colored.writeColor("gray", m)

		local len = select('#', ...)
		local args = {...}
		for i = 1, len do
			local value = args[i]
			local t = type(value)
			if t == "table" then
				value = dump(value)
			else
				value = tostring(value)
			end

			if i > 1 then value = " " .. value end
			writeColor("lightGray", value)
		end
		print()
	end
end

--- Print a series of objects in red
function Logger:error(...)
	colored.printColor("red", ...)
end

--- Print a series of objects in green
function Logger:success(...)
	colored.printColor("green", ...)
end


return Logger
