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
	local objType = type(object)
	if objType == "table" then
		local id = seen[object]

		if id then
			print(indent .. "--[[ Object@" .. id .. " ]] { }")
		else
			id = seen.length + 1
			seen[object] = id
			seen.length = id
			print(indent .. "--[[ Object@" .. id .. " ]] {")
			for k, v in pairs(object) do

				if type(k) == "table" then
					print(indent .. "\t{")
					InternalDump(k, indent .. "\t\t", seen, meta)
					InternalDump(v, indent .. "\t\t", seen, meta)
					print(indent .. "\t},")
				elseif type(v) == "table" then
					print(indent .. "\t[" .. InternalFormat(k) .. "] = {")
					InternalDump(v, indent .. "\t\t", seen, meta)
					print(indent .. "\t},")
				else
					print(indent .. "\t[" .. InternalFormat(k) .. "] = " .. InternalFormat(v) .. ",")
				end
			end

			if meta then
				local metatable = getmetatable(object)

				if metatable then
					print(indent .. "\tMetatable = {")
					InternalDump(metatable, indent .. "\t\t", seen, meta)
					print(indent .. "\t}")
				end
			end
			print(indent .. "}")
		end
	else
		print(indent .. InternalFormat(object))
	end
end

--- Dumps an object
-- @param object The object to dump
-- @tparam boolean meta Print metatables too
-- @tparam ?|string indent The indent to use
local function Dump(object, meta, indent)
	if meta == nil then meta = true end
	InternalDump(object, indent or "", {length = 0}, meta)
end

--- @export Dump
return Dump