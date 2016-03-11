--- Allows formatting tables for logging and storing
-- @module howl.lib.dump

local Buffer = require("howl.lib.buffer")
-- local utils = require("howl.lib.utils")

local type, tostring, format = type, tostring, string.format
local getmetatable, error = getmetatable, error

--- Create a lookup table from a list of values
-- @tparam table tbl The table of values
-- @treturn The same table, with lookups as well
local function createLookup(tbl)
	for _, v in ipairs(tbl) do
		tbl[v] = true
	end
	return tbl
end

--- Format an object
-- @param object The object to foramt
-- @treturn string The object
local function internalFormat(object)
	if type(object) == "string" then
		return format("%q", object)
	else
		return tostring(object)
	end
end

--- Core dumping of object
-- @param object The object to dump
-- @tparam string indent The indent to use
-- @tparam table seen A list of seen objects
-- @tparam bool meta Print metatables too
-- @tparam Buffer buffer Buffer to append to
-- @treturn Buffer The buffer passed
local function internalDump(object, indent, seen, meta, buffer)
	local objType = type(object)
	if objType == "table" then
		local id = seen[object]

		if id then
			buffer:append(indent .. "--[[ Object@" .. id .. " ]] { }" .. "\n")
		else
			id = seen.length + 1
			seen[object] = id
			seen.length = id
			buffer:append(indent .. "--[[ Object@" .. id .. " ]] {" .. "\n")
			for k, v in pairs(object) do

				if type(k) == "table" then
					buffer:append(indent .. "  {" .. "\n")
					internalDump(k, indent .. "    ", seen, meta, buffer)
					internalDump(v, indent .. "    ", seen, meta, buffer)
					buffer:append(indent .. "  }," .. "\n")
				elseif type(v) == "table" then
					buffer:append(indent .. "  [" .. internalFormat(k) .. "] = {" .. "\n")
					internalDump(v, indent .. "    ", seen, meta, buffer)
					buffer:append(indent .. "  },".. "\n")
				else
					buffer:append(indent .. "  [" .. internalFormat(k) .. "] = " .. internalFormat(v) .. "," .. "\n")
				end
			end

			if meta then
				local metatable = getmetatable(object)

				if metatable then
					buffer:append(indent .. "  Metatable = {" .. "\n")
					internalDump(metatable, indent .. "    ", seen, meta, buffer)
					buffer:append(indent .. "  }".. "\n")
				end
			end
			buffer:append(indent .. "}" .. "\n")
		end
	else
		buffer:append(indent .. internalFormat(object) .. "\n")
	end

	return buffer
end

--- Dumps an object
-- @param object The object to dump
-- @tparam[opt=true] boolean meta Print metatables too
-- @tparam[opt=""] string indent Starting indent level
-- @treturn string The dumped string
local function dump(object, meta, indent)
	if meta == nil then meta = true end
	return internalDump(object, indent or "", { length = 0 }, meta, buffer()):toString()
end

local keywords = createLookup {
	"and", "break", "do", "else", "elseif", "end", "false",
	"for", "function", "if", "in", "local", "nil", "not", "or",
	"repeat", "return", "then", "true", "until", "while",
}

--- Internal serialiser
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
						serialiseImpl(k, tracking, buffer)
						buffer:append("]=")
					end

					internalSerialise(v, tracking, buffer)
					buffer:append(",")
				end
			end
			buffer:append("}")
		end
	elseif type == "string" then
		buffer:append(format("%q", object))
	elseif type == "number" or type == "boolean" or type == "nil" then
		buffer:append(tostring(object))
	else
		error("Cannot serialise type " .. type)
	end

	return buffer
end

--- Used for serialising a data structure.
--
-- This does not handle recursive structures or functions.
-- @param object The object to dump
-- @treturn string The serialised string
local function serialise(object)
	return serialiseImpl(object, {}, Buffer()):toString()
end

--- @export
return {
	serialise = serialise,
	dump = dump,
}
