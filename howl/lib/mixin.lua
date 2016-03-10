--- Various mixins for the class library
-- @module howl.lib.mixins

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

return mixins
