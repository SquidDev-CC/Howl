--- Verify a source file
-- @module depends.modules.Verify

local loadstring = loadstring
-- Verify a source file
Mediator.Subscribe({"Combiner", "include"}, function(self, file, contents, options)
	if options.verify and file.verify ~= false then
		local success, err = loadstring(contents)
		if not success then
			local name = file.path
			local msg = "Could not load " .. (name and ("file " .. name) or "string")
			if err ~= "nil" then msg = msg  .. ":\n" .. err end
			return false, msg
		end
	end
end)

-- We should explicitly prevent a resource being verified
Mediator.Subscribe({"Dependencies", "create"}, function(depends, file)
	if file.type == "Resource" then
		file:Verify(false)
	end
end)

--- Verify this file on inclusion
function Depends.File:Verify(verify)
	if verify == nil then verify = true end
	self.verify = verify
	return self
end
