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

--- Check if verbose is true
-- @tparam ?|value If not nil, set verbose to true
-- @treturn boolean Is verbose output on
local function IsVerbose(value)
	if value ~= nil then isVerbose = value end
	return isVerbose
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

--- Pretty prints values if verbose is turned on
-- @param ... Values to print
local function VerboseLog(...)
	if isVerbose then
		local s, m = pcall(function() error("", 4) end)
		WriteColor(colors.gray, m)

		local hasPrevious = false
		for _, value in ipairs({...}) do
			local t = type(value)
			if t == "table" then
				local dmp = Dump or textutils.serialize
				value = dmp(value)
			else
				value = tostring(value)
			end

			if hasPrevious then value = " " .. value end
			hasPrevious = true
			WriteColor(colors.lightGray, value)
		end
		print()
	end
end

local matches = {
	["^"] = "%^",
	["$"] = "%$",
	["("] = "%(",
	[")"] = "%)",
	["%"] = "%%",
	["."] = "%.",
	["["] = "%[",
	["]"] = "%]",
	["*"] = "%*",
	["+"] = "%+",
	["-"] = "%-",
	["?"] = "%?",
	["\0"] = "%z",
}

--- Escape a string for using in a pattern
-- @tparam string pattern The string to escape
-- @treturn string The escaped pattern
local function EscapePattern(pattern)
	return (pattern:gsub(".", matches))
end

local basicMatches = {
	["^"] = "%^",
	["$"] = "%$",
	["("] = "%(",
	[")"] = "%)",
	["%"] = "%%",
	["."] = "%.",
	["["] = "%[",
	["]"] = "%]",
	["+"] = "%+",
	["-"] = "%-",
	["?"] = "%?",
	["\0"] = "%z",
}

--- A resulting pattern
-- @table Pattern
-- @tfield string Type `Pattern` or `Normal`
-- @tfield string Text The resulting pattern

--- Parse a series of patterns
-- @tparam string text Pattern to parse
-- @tparam boolean invert If using a wildcard, invert it
-- @treturn Pattern
local function ParsePattern(text, invert)
	local beginning = text:sub(1, 5)
	if beginning == "ptrn:" or beginning == "wild:" then

		local text = text:sub(6)
		if beginning == "wild:" then
			if invert then
				local counter = 0
				-- Escape the pattern and then replace wildcards with the results of the capture %1, %2, etc...
				text = ((text:gsub(".", basicMatches)):gsub("(%*)", function()
					counter = counter + 1
					return "%" .. counter
				end))
			else
				-- Escape the pattern and replace wildcards with (.*) capture
				text = "^" .. ((text:gsub(".", basicMatches)):gsub("(%*)", "(.*)")) .. "$"
			end
		end

		return {Type = "Pattern", Text = text}
	else
		return {Type = "Normal", Text = text}
	end
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
-- @treturn boolean If they match
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

	IsVerbose = IsVerbose,
	Verbose = Verbose,
	VerboseLog = VerboseLog,

	EscapePattern = EscapePattern,
	ParsePattern = ParsePattern,
	CreateLookup = CreateLookup,
	MatchTables = MatchTables,
}