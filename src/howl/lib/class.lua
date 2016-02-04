--- A basic method for creating classes
-- @module howl.lib.class

local empty = function() end
local type, setmetatable = type, setmetatable

--- Create a class
-- @tparam table class The class to create
-- @treturn (...)->table A function that can be used to create the table
-- @treturn table The class prototype
return function(class)
	local new
	if type(class) == "function" then
		new = class
		class = {}
	else
		new = class.new or empty
		class.new = nil

		if class.extends then
			setmetatable(class, { __index = class.extends })
			class.extends = nil
		end
	end

	local metatable = { __index = class }

	return function(...)
		local table = setmetatable({}, metatable)
		new(table, ...)
		return table
	end, class
end
