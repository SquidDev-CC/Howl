--- Used to create matchers for particular patterns
-- @module howl.files.matcher

local utils = require "howl.lib.utils"

-- Matches with * and ?  removed
local basicMatches = {
	["^"] = "%^", ["$"] = "%$", ["("] = "%(", [")"] = "%)",
	["%"] = "%%", ["."] = "%.", ["["] = "%[", ["]"] = "%]",
	["+"] = "%+", ["-"] = "%-", ["\0"] = "%z",
}

local wildMatches = {
	-- ["*"] = "([^\\]+)",
	-- ["?"] = "([^\\])",
	["*"] = "(.*)"
}
for k,v in pairs(basicMatches) do wildMatches[k] = v end

--- A resulting pattern
-- @table Pattern
-- @tfield string tag `pattern` or `normal`
-- @tfield (Pattern, string)->boolean match Predicate to check if this is a valid item

local function patternAction(self, text) return text:match(self.text) end
local function textAction(self, text)
	return self.text == "" or self.text == text or text:sub(1, #self.text + 1) == self.text .. "/"
end
local function funcAction(self, text) return self.func(text) end

--- Create a matcher
-- @tparam string|function pattern Pattern to check against
-- @treturn Pattern
local function createMatcher(pattern)
	local t = type(pattern)
	if t == "string" then
		local remainder = utils.startsWith(pattern, "pattern:") or utils.startsWith(pattern, "ptrn:")
		if remainder then
			return { tag = "pattern", text = remainder, match = patternAction }
		end

		if pattern:find("%*") then
			local pattern = "^" .. pattern:gsub(".", wildMatches) .. "$"
			return { tag = "pattern", text = pattern, match = patternAction }
		end

		return { tag = "text", text = pattern, match = textAction}
	elseif t == "function" or (t == "table" and (getmetatable(pattern) or {}).__call) then
		return { tag = "function", func = pattern, match = funcAction }
	else
		error("Expected string or function")
	end
end


return {
	createMatcher = createMatcher,
}
