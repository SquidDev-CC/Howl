--- A util module that is only ever used in debugging
-- @module howl.lib.dump

--- Format an object
-- @param object The object to foramt
-- @treturn string The object
local function InternalFormat(object)
	if type(object) == "string" then
		return string.format("%q", object)
	else
		return tostring(object)
	end
end

--- Core dumping of object
-- @param object The object to dump
-- @tparam ?|string indent The indent to use
-- @tparam table seen A list of seen objects
-- @tparam boolean meta Print metatables too
local function InternalDump(object, indent, seen, meta)
	local result = ""
	local objType = type(object)
	if objType == "table" then
		local id = seen[object]

		if id then
			result = result .. (indent .. "--[[ Object@" .. id .. " ]] { }") .. "\n"
		else
			id = seen.length + 1
			seen[object] = id
			seen.length = id
			result = result .. (indent .. "--[[ Object@" .. id .. " ]] {") .. "\n"
			for k, v in pairs(object) do

				if type(k) == "table" then
					result = result .. (indent .. "\t{") .. "\n"
					result = result .. InternalDump(k, indent .. "\t\t", seen, meta)
					result = result .. InternalDump(v, indent .. "\t\t", seen, meta)
					result = result .. (indent .. "\t},") .. "\n"
				elseif type(v) == "table" then
					result = result .. (indent .. "\t[" .. InternalFormat(k) .. "] = {") .. "\n"
					result = result .. InternalDump(v, indent .. "\t\t", seen, meta)
					result = result .. (indent .. "\t},") .. "\n"
				else
					result = result .. (indent .. "\t[" .. InternalFormat(k) .. "] = " .. InternalFormat(v) .. ",") .. "\n"
				end
			end

			if meta then
				local metatable = getmetatable(object)

				if metatable then
					result = result .. (indent .. "\tMetatable = {") .. "\n"
					result = result .. InternalDump(metatable, indent .. "\t\t", seen, meta)
					result = result .. (indent .. "\t}") .. "\n"
				end
			end
			result = result .. (indent .. "}") .. "\n"
		end
	else
		result = result .. (indent .. InternalFormat(object)) .. "\n"
	end

	return result
end

--- Dumps an object
-- @param object The object to dump
-- @tparam boolean meta Print metatables too
-- @tparam ?|string indent The indent to use
local function Dump(object, meta, indent)
	if meta == nil then meta = true end
	return InternalDump(object, indent or "", { length = 0 }, meta)
end

local keywords = {
	["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
	["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
	["function"] = true, ["if"] = true, ["in"] = true, ["local"] = true,
	["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true,
	["return"] = true, ["then"] = true, ["true"] = true, ["until"] = true,
	["while"] = true,
}

local function serializeImpl(t, tTracking, sIndent)
	local sType = type(t)
	if sType == "table" then
		if tTracking[t] ~= nil then
			error("Cannot serialize table with recursive entries", 0)
		end
		tTracking[t] = true

		if next(t) == nil then
			-- Empty tables are simple
			return "{}"
		else
			-- Other tables take more work
			local sResult = "{\n"
			local sSubIndent = sIndent .. "  "
			local tSeen = {}
			for k, v in ipairs(t) do
				tSeen[k] = true
				sResult = sResult .. sSubIndent .. serializeImpl(v, tTracking, sSubIndent) .. ",\n"
			end
			for k, v in pairs(t) do
				if not tSeen[k] then
					local sEntry
					if type(k) == "string" and not keywords[k] and string.match(k, "^[%a_][%a%d_]*$") then
						sEntry = k .. " = " .. serializeImpl(v, tTracking, sSubIndent) .. ",\n"
					else
						sEntry = "[ " .. serializeImpl(k, tTracking, sSubIndent) .. " ] = " .. serializeImpl(v, tTracking, sSubIndent) .. ",\n"
					end
					sResult = sResult .. sSubIndent .. sEntry
				end
			end
			sResult = sResult .. sIndent .. "}"
			return sResult
		end

	elseif sType == "string" then
		return string.format("%q", t)

	elseif sType == "number" or sType == "boolean" or sType == "nil" then
		return tostring(t)

	else
		error("Cannot serialize type " .. sType, 0)
	end
end

local function serialize(t)
	return serializeImpl(t, {}, "")
end

return {
	dump = dump,
	serialize = serialize,
}
