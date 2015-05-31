--- Emulates the terminal API
-- @module interop.term

--[[
	term.write(string text)	nil	Writes text to the screen.
	term.clear()	nil	Clears the entire screen
	term.clearLine()	nil	Clears the line the cursor is on
	term.getCursorPos()	number x, number y	Returns two arguments containing the x and the y position of the cursor.
	term.setCursorPos(number x, number y)	nil	Sets the cursor's position.
	term.setCursorBlink(boolean bool)	nil	Disables the blinking or turns it on.
	term.isColor()	boolean	Returns whether the terminal supports color.
	term.getSize()	number x, number y	Returns two arguments containing the x and the y values stating the size of the screen. (Good for if you're making something to be compatible with both Turtles and Computers.)
	term.scroll(number n)	nil	Scrolls the terminal n lines.
	term.redirect(target)	table previous terminal object	Redirects terminal output to another terminal object (such as a window or wrapped monitor). Available only to the base term object.
	term.current()	table terminal object	Returns the current terminal object. Requires version 1.6 or newer, available only to the base term object.
	term.native()	table terminal object	Returns the original terminal object. Requires version 1.6 or newer, available only to the base term object.
	term.setTextColor(number color)	nil	Sets the text color of the terminal. Limited functionality without an Advanced Computer / Turtle / Monitor.
	term.setBackgroundColor(number color)	nil	Sets the background color of the terminal. Limited functionality without an Advanced Computer / Turtle / Monitor.
]]

local escapeBegin = string.char(27) .. '['

local write, format = io.write, string.format

local function clear() io.write(escapeBegin .. "2J") end
local function clearLine() io.write(escapeBegin .. "2K") end

local function getCursorPos() return 1, 1 end

local function setCursorPos(x, y)
	io.write(format(escapeBegin .. "%d;%dH", x, y))
end

local function setCursorBlink(blink)
	if blink then
		io.write(escapeBegin .. "5m")
	else
		io.write(escapeBegin .. "25m")
	end
end

local function isColor() return true end
local function getSize() return 80, 25 end

local function scroll(n)
	if n > 0 then
		io.write(format(escapeBegin .. '%dS', n))
	elseif n < 0 then
		io.write(format(escapeBegin .. '%dT', -n))
	end
end

local function redirect() error("'redirect' Not implemented", 2) end
local function current() error("'current' Not implemented", 2) end
local function native() error("'native' Not implemented", 2) end

colorMappings = {
	[colors.white]     = 97,
	[colors.orange]    = 33,
	[colors.magenta]   = 95,
	[colors.lightBlue] = 94,
	[colors.yellow]    = 93,
	[colors.lime]      = 92,
	[colors.pink]      = 95, -- No pink
	[colors.gray]      = 90,
	[colors.lightGray] = 37,
	[colors.cyan]      = 96,
	[colors.purple]    = 35, -- Dark magenta
	[colors.blue]      = 36,
	[colors.brown]     = 31,
	[colors.green]     = 32,
	[colors.red]       = 91,
	[colors.black]     = 30,
}

local function setTextColor(color)
	local col = colorMappings[color]
	if not col then error("Cannot find color " .. tostring(color), 2) end
	io.write(escapeBegin .. col .. "m")
end

local function setBackgroundColor(color)
	local col = colorMappings[color]
	if not col then error("Cannot find color " .. tostring(color), 2) end
	io.write(escapeBegin .. (col + 10) .. "m")
end

--- @export
return {
	write          = io.write,
	clear          = clear,
	clearLine      = clearLine,
	getCursorPos   = getCursorPos,
	setCursorPos   = setCursorPos,
	setCursorBlink = setCursorBlink,

	isColor  = isColor,
	isColour = isColour,
	getSize  = getSize,
	scroll   = scroll,
	redirect = redirect,
	current  = current,
	native   = native,

	setTextColor = setTextColor,
	setBackgroundColor = setBackgroundColor,
}
