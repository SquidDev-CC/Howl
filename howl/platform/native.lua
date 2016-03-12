--- Platform implementation for vanilla Lua
-- @module howl.platform.native

local escapeBegin = string.char(27) .. '['
local colorMappings = {
	white     = 97,
	orange    = 33,
	magenta   = 95,
	lightBlue = 94,
	yellow    = 93,
	lime      = 92,
	pink      = 95, -- No pink
	gray      = 90, grey = 90,
	lightGray = 37, lightGrey = 37,
	cyan      = 96,
	purple    = 35, -- Dark magenta
	blue      = 36,
	brown     = 31,
	green     = 32,
	red       = 91,
	black     = 30,
}

return {
	fs = setmetatable({

	}, { __index = function(self, name) error(tostring(name) .. " is not implemented", 2) end }),

	term = {
		setColor = function(color)
			local col = colorMappings[color]
			if not col then error("Cannot find color " .. tostring(color), 2) end
			io.write(escapeBegin .. col .. "m")
			io.flush()
		end,
		resetColor = function()
			io.write(escapeBegin .. "0m")
			io.flush()
		end
	},
	refreshYield = function() end
}
