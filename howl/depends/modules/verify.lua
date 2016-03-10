--- Verify a source file
-- @module howl.depends.modules.verify

local Mediator = require "howl.lib.mediator"
local Depends = require "howl.depends"

local loadstring = loadstring
-- Verify a source file
Mediator:subscribe({ "Combiner", "include" }, function(self, file, contents, options)
	if options.verify and file.verify ~= false then
		local success, err = loadstring(contents)
		if not success then
			local name = file.path
			local msg = "Could not load " .. (name and ("file " .. name) or "string")
			if err ~= "nil" then msg = msg .. ":\n" .. err end
			return false, msg
		end
	end
end)

-- We should explicitly prevent a resource being verified
Mediator:subscribe({ "Dependencies", "create" }, function(depends, file)
	if file.type == "Resource" then
		file:Verify(false)
	end
end)

--- Verify this file on inclusion
-- @tparam ?|boolean verify If this source should be verified. Defaults to true
-- @treturn depends.Depends.File The current file to allow chaining
function Depends.File:Verify(verify)
	if verify == nil then verify = true end
	self.verify = verify
	return self
end
