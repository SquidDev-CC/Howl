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

return mixins
