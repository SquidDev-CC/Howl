--- Useful little helpers for things
-- @module howl.lib.utils

local assert = require "howl.lib.assert"

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

--- Format a template string with data.
-- Anything of the form `${var}` will be replaced with the appropriate variable in the table.
-- @tparam string template The template to format
-- @tparam table data The data to replace with
-- @treturn string The formatted template
local function formatTemplate(template, data)
	return (template:gsub("${([^}]+)}", function(str)
		local res = data[str]
		if res == nil then
			return "${" .. str .. "}"
		else
			return tostring(res)
		end
	end))
end

--- Mark a function as deprecated
-- @tparam string name The name of the function
-- @tparam function function The function to delegate to
-- @tparam string|nil msg Additional message to print
local function deprecated(name, func, msg)
	assert.argType(name, "string", "deprecated", 1)
	assert.argType(func, "function", "deprecated", 2)

	if msg ~= nil then
		assert.argType(msg, "string", "msg", 4)
		msg = " " .. msg
	else
		msg = ""
	end

	local doneDeprc = false
	return function(...)
		if not doneDeprc then
			local _, callee = pcall(error, "", 3)
			callee = callee:gsub(":%s*$", "")
			print(name .. " is deprecated (called at " .. callee .. ")." .. msg)
			doneDeprc = true
		end

		return func(...)
	end
end

--- @export
return {
	escapePattern = escapePattern,
	parsePattern = parsePattern,
	createLookup = createLookup,
	matchTables = matchTables,
	startsWith = startsWith,
	formatTemplate = formatTemplate,
	deprecated = deprecated,
}
