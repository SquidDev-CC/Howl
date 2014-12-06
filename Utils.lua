--- @module Utils

local isVerbose = false

--- Prints a string in a colour if colour is supported
-- @tparam int color The colour to print
-- @param ... Values to print
local function PrintColor(color, ...)
	local isColor = term.isColor()
	if isColor then term.setTextColor(color) end
	print(...)
	if isColor then term.setTextColor(colors.white) end
end

--- Writes a string in a colour if colour is supported
-- @tparam int color The colour to print
-- @tparam string text Values to print
local function WriteColor(color, text)
	local isColor = term.isColor()
	if isColor then term.setTextColor(color) end
	write(text)
	if isColor then term.setTextColor(colors.white) end
end

--- Prints a string in green if colour is supported
-- @param ... Values to print
local function PrintSuccess(...) PrintColor(colors.green, ...) end

--- Sets if verbose is on or not
-- @tparam bool verbose Should we print verbose output
local function SetVerbose(verbose)
	isVerbose = verbose
end

--- Prints a verbose string if verbose is turned on
-- @param ... Values to print
local function Verbose(...)
	if isVerbose then
		local s, m = pcall(function() error("", 4) end)
		WriteColor(colors.gray, m)
		PrintColor(colors.lightGray, ...)
	end
end

local matches = {
	["^"] = "%^";
	["$"] = "%$";
	["("] = "%(";
	[")"] = "%)";
	["%"] = "%%";
	["."] = "%.";
	["["] = "%[";
	["]"] = "%]";
	["*"] = "%*";
	["+"] = "%+";
	["-"] = "%-";
	["?"] = "%?";
	["\0"] = "%z";
}

--- Escape a string for using in a pattern
-- @tparam string pattern The string to escape
-- @treturn string The escaped pattern
local function EscapePattern(pattern)
	return (pattern:gsub(".", matches))
end

return {
	Print = print,
	PrintError = printError,
	PrintSuccess = PrintSuccess,
	PrintColor = PrintColor,
	WriteColor = WriteColor,

	SetVerbose = SetVerbose,
	Verbose = Verbose,

	EscapePattern = EscapePattern,
}