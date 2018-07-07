local preload = type(package) == "table" and type(package.preload) == "table" and package.preload or {}

local require = require
if type(require) ~= "function" then
	local loading = {}
	local loaded = {}
	require = function(name)
		local result = loaded[name]

		if result ~= nil then
			if result == loading then
				error("loop or previous error loading module '" .. name .. "'", 2)
			end

			return result
		end

		loaded[name] = loading
		local contents = preload[name]
		if contents then
			result = contents(name)
		else
			error("cannot load '" .. name .. "'", 2)
		end

		if result == nil then result = true end
		loaded[name] = result
		return result
	end
end
