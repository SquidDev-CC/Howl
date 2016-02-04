--- An optimised class for appending strings
-- @classmod howl.lib.Buffer
-- @pragma nostrip

local Buffer = {}

local class = require("howl.lib.class")
local setmetatable, concat = setmetatable, table.concat

--- Create a new buffer
-- @treturn Buffer The buffer
-- @function Buffer
function Buffer:new()
	self.n = 0
end

--- Append to this buffer
-- @tparam string text
-- @treturn Buffer The current buffer to allow chaining
function Buffer:append(text)
	local n = self.n + 1
	self[n + 1] = text
	self.n = n
end

--- Convert this buffer to a string
-- @treturn string String representation of the buffer
function Buffer:toString()
	return concat(self)
end

return class(Buffer)
