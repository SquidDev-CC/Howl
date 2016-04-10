--- An optimised class for appending strings
-- @classmod howl.lib.Buffer

local concat = table.concat

--- Append to this buffer
-- @tparam string text
-- @treturn Buffer The current buffer to allow chaining
local function append(self, text)
	local n = self.n + 1
	self[n] = text
	self.n = n
	return self
end

--- Convert this buffer to a string
-- @treturn string String representation of the buffer
local function toString(self)
	return concat(self)
end

--- Create a new buffer
-- @treturn Buffer The buffer
return function()
	return {
		n = 0, append = append, toString = toString
	}
end
