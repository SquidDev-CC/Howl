--- Allows formatting tables for logging and storing
-- @module howl.lib.dump

local Buffer = require("howl.lib.Buffer")
local createLookup = require("howl.lib.utils").createLookup

local type, tostring, format = type, tostring, string.format
local getmetatable, error = getmetatable, error

-- TODO: Switch to LuaCP's pprint
local function dumpImpl(t, tracking, indent)
	local objType = type(t)
	if objType == "table" and not tracking[t] then
		tracking[t] = true

		if next(t) == nil then
			return "{}"
		else
			local shouldNewLine = false
			local length = #t

			local builder = 0
			for k,v in pairs(t) do
				if type(k) == "table" or type(v) == "table" then
					shouldNewLine = true
					break
				elseif type(k) == "number" and k >= 1 and k <= length and k % 1 == 0 then
					builder = builder + #tostring(v) + 2
				else
					builder = builder + #tostring(v) + #tostring(k) + 2
				end

				if builder > 40 then
					shouldNewLine = true
					break
				end
			end

			local newLine, nextNewLine, subIndent = "", ", ", " "
			if shouldNewLine then
				newLine = "\n"
				nextNewLine = ",\n"
				subIndent = indent .. " "
			end

			local result, n = {(tupleLength and "(" or "{") .. newLine}, 1

			local seen = {}
			local first = true
			for k = 1, length do
				seen[k] = true
				n = n + 1
				local entry = subIndent .. dumpImpl(t[k], tracking, subIndent)

				if not first then
					entry = nextNewLine .. entry
				else
					first = false
				end

				result[n] = entry
			end

			for k,v in pairs(t) do
				if not seen[k] then
					local entry
					if type(k) == "string" and string.match( k, "^[%a_][%a%d_]*$" ) then
						entry = k .. " = " .. dumpImpl(v, tracking, subIndent)
					else
						entry = "[" .. dumpImpl(k, tracking, subIndent) .. "] = " .. dumpImpl(v, tracking, subIndent)
					end

					entry = subIndent .. entry

					if not first then
						entry = nextNewLine .. entry
					else
						first = false
					end

					n = n + 1
					result[n] = entry
				end
			end

			n = n + 1
			result[n] = newLine .. indent .. (tupleLength and ")" or "}")
			return table.concat(result)
		end

	elseif objType == "string" then
		return (string.format("%q", t):gsub("\\\n", "\\n"))
	else
		return tostring(t)
	end
end

local function dump(t, n)
	return dumpImpl(t, {}, "")
end

local keywords = createLookup {
	"and", "break", "do", "else", "elseif", "end", "false",
	"for", "function", "if", "in", "local", "nil", "not", "or",
	"repeat", "return", "then", "true", "until", "while",
}

--- Internal serialiser
-- @param object The object being serialised
-- @tparam table tracking List of items being tracked
-- @tparam Buffer buffer Buffer to append to
-- @treturn Buffer The buffer passed
local function internalSerialise(object, tracking, buffer)
	local sType = type(object)
	if sType == "table" then
		if tracking[object] then
			error("Cannot serialise table with recursive entries", 1)
		end
		tracking[object] = true

		if next(object) == nil then
			buffer:append("{}")
		else
			-- Other tables take more work
			buffer:append("{")

			local seen = {}
			-- Attempt array only method
			for k, v in ipairs(object) do
				seen[k] = true
				internalSerialise(v, tracking, buffer)
				buffer:append(",")
			end
			for k, v in pairs(object) do
				if not seen[k] then
					if type(k) == "string" and not keywords[k] and k:match("^[%a_][%a%d_]*$") then
						buffer:append(k .. "=")
					else
						buffer:append("[")
						internalSerialise(k, tracking, buffer)
						buffer:append("]=")
					end

					internalSerialise(v, tracking, buffer)
					buffer:append(",")
				end
			end
			buffer:append("}")
		end
	elseif sType == "string" then
		buffer:append(format("%q", object))
	elseif sType == "number" or sType == "boolean" or sType == "nil" then
		buffer:append(tostring(object))
	else
		error("Cannot serialise type " .. sType)
	end

	return buffer
end

--- Used for serialising a data structure.
--
-- This does not handle recursive structures or functions.
-- @param object The object to dump
-- @treturn string The serialised string
local function serialise(object)
	return internalSerialise(object, {}, Buffer()):toString()
end

--- @export
return {
	serialise = serialise,
	dump = dump,
}
