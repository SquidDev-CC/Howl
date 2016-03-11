--- An optimised class for appending strings
-- @classmod howl.lib.Buffer

local concat = table.concat

--- Append to this buffer
-- @tparam string text
-- @treturn Buffer The current buffer to allow chaining
local function append(text)
	local n = self.n + 1
	self[n + 1] = text
	self.n = n
end

--- Convert this buffer to a string
-- @treturn string String representation of the buffer
local function toString()
	return concat(self)
end

--- Create a new buffer
-- @treturn Buffer The buffer
return function()
	return {
		n = 0, append = append, toString = toString
	}
end
