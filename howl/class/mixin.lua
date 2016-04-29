--- Various mixins for the class library
-- @module howl.class.mixin

local assert = require "howl.lib.assert"
local rawset = rawset

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

	__div = function(self, name) return self:curry(name) end,
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

mixins.optionGroup = {
	static = {
		addOption = function(self, key)
			local func = function(self, value)
				if value == nil then value = true end
				self.options[key] = value
				return self
			end

			self[key:gsub("^%l", string.upper)] = func
			self[key] = func

			if not rawget(self.static, "options") then
				local options = {}
				self.static.options = options
				local parent = self.super and self.super.static.options

				-- TODO: Copy instead. Also propagate to children below
				if parent then setmetatable(options, { __index = parent } ) end
			end

			self.static.options[key] = true

			return self
		end,
		addOptions = function(self, names)
			for i = 1, #names do
				self:addOption(names[i])
			end

			return self
		end,
	},

	configure = function(self, item)
		assert.argType(item, "table", "configure", 1)

		for k, v in pairs(item) do
			if self.class.options[k] then
				self[k](self, v)
			end
		end
	end,

	__newindex = function(self, key, value)
		if keys[key] then
			self[key](self, value)
		else
			rawset(self, key, value)
		end
	end
}

return mixins
