--- Useful little helpers for things
-- @module howl.lib.utils

local ipairs = ipairs

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
-- @tfield string tag `pattern` or `normal`
-- @tfield string text The resulting pattern

--- Parse a series of patterns
-- @tparam string text Pattern to parse
-- @tparam[opt=false] bool invert If using a wildcard, invert it
-- @treturn Pattern The produced pattern
-- @usage local pattern = parsePattern("foo.lua")
-- @usage local pattern = parsePattern("wild:*.lua")
-- @usage local pattern = parsePattern("ptrn:%a%.lua")
local function parsePattern(text, invert)
	local beginning = text:sub(1, 5)
	if beginning == "ptrn:" or beginning == "wild:" then

		local text = text:sub(6)
		if beginning == "wild:" then
			if invert then
				local counter = 0
				-- Escape the pattern and then replace wildcards with the results of the capture %1, %2, etc...
				text = text:gsub(".", basicMatches):gsub("(%*)", function()
					counter = counter + 1
					return "%" .. counter
				end)
			else
				-- Escape the pattern and replace wildcards with (.*) capture
				text = "^" .. text:gsub(".", basicMatches):gsub("(%*)", "(.*)") .. "$"
			end
		end

		return { tag = "pattern", text = text }
	else
		return { type = "Normal", text = text }
	end
end

--- Create a lookup table from a list of values
-- @tparam table tbl The table of values
-- @treturn table The same table, with lookups as well
local function createLookup(tbl)
	for _, v in ipairs(tbl) do
		tbl[v] = true
	end
	return tbl
end

--- @export
return {
	escapePattern = escapePattern,
	parsePattern = parsePattern,
	createLookup = createLookup,
}
