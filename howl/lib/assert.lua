--- Assertion helpers
-- @module howl.lib.assert

local type, error, floor, select = type, error, select, math.floor

local nativeAssert = assert
local assert = setmetatable(
	{ assert = nativeAssert },
	{ __call = function(self, ...) return nativeAssert(...) end }
)

local function typeError(type, expected, message)
	if message then
		return error(message:format(type))
	else
		return error(expected .. " expected, got " .. type)
	end
end

function assert.type(value, expected, message)
	local t = type(value)
	if t ~= expected then
		return typeError(t, expected, message)
	end
end

local function argError(type, expected, func, index)
	return error("bad argument #" .. index .. " for " .. func .. " (expected " .. expected .. ", got " .. type .. ")")
end

function assert.argType(value, expected, func, index)
	local t = type(value)
	if t ~= expected then
		return argError(t, expected, func, index)
	end
end

function assert.args(func, ...)
	local len = select('#', ...)
	local args = {...}

	for k = 1, len, 2 do
		local t = type(args[i])
		local expected = args[i + 1]
		if t ~= expected then
			return argError(t, expected, func, math.floor(k / 2))
		end
	end
end

assert.typeError = typeError
assert.argError = argError

function assert.class(value, expected, message)
	local t = type(value)
	if t ~= "table" or not value.isInstanceOf then
		return typeError(t, expected, message)
	elseif not value:isInstanceOf(expected) then
		return typeError(value.class.name, expected, message)
	end
end

return assert
