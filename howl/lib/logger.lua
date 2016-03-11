--- The main logger for Lua
-- @clasmod howl.lib.Logger

local class = require "howl.lib.middleclass"
local mixin = require "howl.lib.mixin"
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

function Logger:verbose(...)
	if self.isVerbose then
		local _, m = pcall(function() error("", 4) end)
		colored.writeColor("gray", m)
		colored.printColor("lightGray", ...)
	end
end

function Logger:dump(...)
	if self.isVerbose then
		local _, m = pcall(function() error("", 4) end)
		colored.writeColor("gray", m)

		local hasPrevious = false
		for _, value in ipairs({ ... }) do
			local t = type(value)
			if t == "table" then
				value = dump(value)
			else
				value = tostring(value)
			end

			if hasPrevious then value = " " .. value end
			hasPrevious = true
			writeColor(colors.lightGray, value)
		end
		print()
	end
end

function Logger:error(...)
	colored.printColor("red", ...)
end

function Logger:success(...)
	colored.printColor("green", ...)
end


return Logger
