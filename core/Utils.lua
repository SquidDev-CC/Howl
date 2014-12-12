--- Useful little helpers for things
-- @module Utils

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

--- Create a lookup table from a list of values
-- @tparam table tbl The table of values
-- @treturn The same table, with lookups as well
local function CreateLookup(tbl)
	for _, v in ipairs(tbl) do
		tbl[v] = true
	end
	return tbl
end

--- Checks if two tables are equal
-- @tparam table a
-- @tparam table b
-- @tparam boolean If they match
local function MatchTables(a, b)
	local length = #a
	if length ~= #b then return false end

	for i=1, length do
		if a[i] ~= b[i] then return false end
	end
	return true
end

-- Hacky docs for objects

--- Print messages
local Print = print
--- Print error messages
local PrintError = printError

--- @export
return {
	Print = Print,
	PrintError = PrintError,
	PrintSuccess = PrintSuccess,
	PrintColor = PrintColor,
	WriteColor = WriteColor,

	SetVerbose = SetVerbose,
	Verbose = Verbose,

	EscapePattern = EscapePattern,
	CreateLookup = CreateLookup,
	MatchTables = MatchTables,
}