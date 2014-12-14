--- A util module that is only ever used in debugging
-- @module Utils.Dump

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
	return InternalDump(object, indent or "", {length = 0}, meta)
end

return Dump