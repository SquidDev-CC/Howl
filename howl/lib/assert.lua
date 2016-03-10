--- Assertion helpers
-- @module howl.lib.assert

local type, error = type, error

local function format(message, args)
	return message:format("%%(%w+)", args)
end

local nativeAssert = assert
local assert = setmetatable(
	{ assert = nativeAssert },
	{ __call = function(self, ...) return nativeAssert(...) end }
)

local function typeError(type, expected, message)
	if message then
		return error(message:format("%s", t))
	else
		return error(expected .. " expected, got " .. t)
	end
end

function assert.type(value, expected, message)
	local t = type(value)
	if t ~= expected then
		return typeError(t, expected, message)
	end
end

function assert.class(value, expected, message)
	local t = type(value)
	if t ~= "table" or not value.isInstanceOf then
		return typeError(t, expected, message)
	elseif not value:isInstanceOf(expected) then
		return typeError(value.class.name, expected, message)
	end
end

return assert
