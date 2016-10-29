--- Print coloured strings
-- @module howl.lib.utils

local term = require "howl.platform".term

--- Prints a string in a colour if colour is supported
-- @tparam int color The colour to print
-- @param ... Values to print
local function printColor(color, ...)
	term.setColor(color)
	term.print(...)
	term.resetColor(color)
end

--- Writes a string in a colour if colour is supported
-- @tparam int color The colour to print
-- @tparam string text Values to print
local function writeColor(color, text)
	term.setColor(color)
	term.write(text)
	term.resetColor(color)
end

return {
	printColor = printColor,
	writeColor = writeColor,
}
