--- The main logger for Lua
-- @clasmod howl.lib.Logger

local class = require "howl.lib.middleclass"
local mixin = require "howl.lib.mixin"
local dump = require "howl.lib.dump"

local Logger = class("howl.lib.Logger"):include(mixin.sealed)

--- Prints a string in a colour if colour is supported
-- @tparam int color The colour to print
-- @param ... Values to print
local function printColor(color, ...)
	local isColor = term.isColor()
	if isColor then term.setTextColor(color) end
	print(...)
	if isColor then term.setTextColor(colors.white) end
end

--- Writes a string in a colour if colour is supported
-- @tparam int color The colour to print
-- @tparam string text Values to print
local function writeColor(color, text)
	local isColor = term.isColor()
	if isColor then term.setTextColor(color) end
	write(text)
	if isColor then term.setTextColor(colors.white) end
end

function Logger:initialize(context)
	self.isVerbose = false
	context.mediator:subscribe({ "ArgParse", "changed" }, function(options)
		self.isVerbose = options:Get "verbose" or false
	end)
end

function Logger:verbose(...)
	if self.isVerbose then
		local _, m = pcall(function() error("", 4) end)
		writeColor(colors.gray, m)
		printColor(colors.lightGray, ...)
	end
end

function Logger:dump(...)
	if self.isVerbose then
		local _, m = pcall(function() error("", 4) end)
		writeColor(colors.gray, m)

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

return Logger
