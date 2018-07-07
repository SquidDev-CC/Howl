--- The main logger for Lua
-- @classmod howl.lib.Logger

local class = require "howl.class"
local mixin = require "howl.class.mixin"
local dump = require "howl.lib.dump".dump
local colored = require "howl.lib.colored"
local platformLog = require "howl.platform".log

local select, tostring = select, tostring
local function concat(...)
	local buffer = {}
	for i = 1, select('#', ...) do
		buffer[i] = tostring(select(i, ...))
	end
	return table.concat(buffer, " ")
end

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
		platformLog("verbose", m .. concat(...))
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
			-- TODO: use platformLog too.
			colored.writeColor("lightGray", value)
		end
		print()
	end
end

local types = {
	{ "success", "ok", "green" },
	{ "error", "error", "red" },
	{ "info", "info", "cyan" },
	{ "warning", "warn", "yellow" },
}

local max = 0
for _, v in ipairs(types) do
	max = math.max(max, #v[2])
end

for _, v in ipairs(types) do
	local color = v[3]
	local format = '[' .. v[2] .. ']' .. (' '):rep(max - #v[2] + 1)
	local field = "has" .. v[2]:gsub("^%l", string.upper)
	local name = v[1]

	Logger[name] = function(self, fmt, ...)
		self[field] = true
		colored.writeColor(color, format)

		local text
		if type(fmt) == "string" then
			text = fmt:format(...)
		end

		colored.printColor(color, text)
		platformLog(name, text)
	end
end

return Logger
