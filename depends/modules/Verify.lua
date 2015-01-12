--- Verify a source file
-- @module depends.modules.Verify

Mediator.Subscribe({"Combiner", "include"}, function(self, name, contents, options)
	if options.verify then
		local success, err = loadstring(contents)
			if not success then
				local msg = "Could not load " .. (name and ("file " .. name) or "string")
				if err ~= "nil" then msg = msg  .. ":\n" .. err end
				return false, msg
			end
	end
end)
