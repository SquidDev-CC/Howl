--- Various mixins for the class library
-- @module howl.class.mixin

local assert = require "howl.lib.assert"
local mixins = {}

--- Prevent subclassing a class
mixins.sealed = {
	static = {
		subclass = function(self, name)
			assert(type(self) == 'table', "Make sure that you are using 'Class:subclass' instead of 'Class.subclass'")
			assert(type(name) == "string", "You must provide a name(string) for your class")
			error("Cannot subclass '" .. tostring(self) .. "' (attempting to create '" .. name .. "')", 2)
		end,
	}
}

mixins.curry = {
	curry = function(self, name)
		assert.type(self, "table", "Bad argument #1 to class:curry (expected table, got %s)")
		assert.type(name, "string", "Bad argument #2 to class:curry (expected string, got %s)")
		local func = self[name]
		assert.type(func, "function", "No such function " .. name)
		return function(...) return func(self, ...) end
	end,

	__div = function(left, right) return left:curry(right) end,
}

mixins.configurable = {
	configureWith = function(self, arg)
		local t = type(arg)
		if t == "table" then
			self:configure(arg)
			return self
		elseif t == "function" then
			arg(self)
			return self
		else
			error("Expected table or function, got " .. type(arg), 2)
		end

		return self
	end,

	__call = function(self, ...) return self:configureWith(...) end,
}

mixins.filterable = {
	__add = function(self, ...) return self:include(...) end,
	__sub = function(self, ...) return self:exclude(...) end,
	with = function(self, ...) return self:configure(...) end,
}

function mixins.delegate(name, keys)
	local out = {}
	for _, key in ipairs(keys) do
		out[key] = function(self, ...)
			local object = self[name]
			return object[key](object, ...)
		end
	end

	return out
end

return mixins
