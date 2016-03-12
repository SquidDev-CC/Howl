--- Useful little helpers for things
-- @module howl.lib.utils

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
local function escapePattern(pattern)
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
local function parsePattern(text, invert)
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

		return { Type = "Pattern", Text = text }
	else
		return { Type = "Normal", Text = text }
	end
end

--- Create a lookup table from a list of values
-- @tparam table tbl The table of values
-- @treturn The same table, with lookups as well
local function createLookup(tbl)
	for _, v in ipairs(tbl) do
		tbl[v] = true
	end
	return tbl
end

--- Checks if two tables are equal
-- @tparam table a
-- @tparam table b
-- @treturn boolean If they match
local function matchTables(a, b)
	local length = #a
	if length ~= #b then return false end

	for i = 1, length do
		if a[i] ~= b[i] then return false end
	end
	return true
end

local function startsWith(string, text)
	if string:sub(1, #text) == text then
		return string:sub(#text + 1)
	else
		return false
	end
end

--- @export
return {
	escapePattern = escapePattern,
	parsePattern = parsePattern,
	createLookup = createLookup,
	matchTables = matchTables,
	startsWith = startsWith,
}
