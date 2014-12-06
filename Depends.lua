--- @module Depends

local File = {}

--- Define the name of this file
-- @tparam string name The name of this file
-- @treturn File The current object (allows chaining)
function File:Name(name)
	self.name = name
	self:Alias(name)
	return self
end

--- Define the alias of this file
-- An alias is used in Howlfiles to refer to the file, but has
-- no effect on the variable name
-- @tparam string name The alias of this file
-- @treturn File The current object (allows chaining)
function File:Alias(name)
	self.alias = name
	return self
end

--- Define what this file depends on
-- @tparam string/table Name/list of dependencies
-- @treturn File The current object (allows chaining)
function File:Depends(name)
	if type(name) == "table" then
		for _, file in ipairs(name) do
			self:Depends(name)
		end
	else
		table.insert(self.dependencies, name)
	end

	return self
end

--- Should this file be set as a global. This has no effect if the module does not have an name
-- @tparam bool Boolean value setting if it should be exported or not
-- @return File The current object (allows chaining)
function File:Export(shouldExport)
	if shouldExport == nil then shouldExport = true end
	self.shouldExport = shouldExport
	return self
end

local Dependencies = {}
--- Add a file to the dependency list
-- @tparam string path The path of the file relative to the PPI file
-- @treturn File The created file object
function Dependencies:File(path)
	local file = setmetatable({
		dependencies = {},
		name = nil, alias = nil,
		path = path,
		shouldExport = true, __isMain = false
	}, {__index = File})

	self.files[path] = file
	return file
end

--- Add a 'main' file to the dependency list. This is a file that will be executed (added to the end of a script)
-- Nothing should depend on it.
-- @tparam string path The path of the file relative to the PPI file
-- @treturn File The created file object
function Dependencies:Main(path)
	local file = self:File(path)
	file.__isMain = true
	table.insert(self.mainFiles, file)
	return file
end

--- Attempts to find a file based on its name or path
-- @tparam string name Name/Path of the file
-- @treturn ?|file The file or nil on failure
function Dependencies:FindFile(name)
	local files = self.files
	local file = files[name] -- Attempt loading file through path
	if file then return file end

	file = files[name .. ".lua"] -- Common case with name being file minus '.lua'
	if file then return file end

	for _, file in pairs(files) do
		if file.alias == name then
			return file
		end
	end

	return nil
end

--- Iterate through each file, yielding each dependency before the file itself
-- @treturn function A coroutine which is used to loop through items
function Dependencies:Iterate()
	local done = {}

	-- Hacky little function which uses co-routines to loop
	local function internalLoop(fileObject)
		if done[fileObject.path] then return end
		done[fileObject.path] = true

		for _, depName in ipairs(fileObject.dependencies) do
			local dep = self:FindFile(depName)
			if not dep then error("Cannot find file " .. depName) end
			internalLoop(dep)
		end
		coroutine.yield(fileObject)
	end

	return coroutine.wrap(function() for _, file in ipairs(self.mainFiles) do internalLoop(file) end end)
end

--- Return a table of exported values
-- @tparam bool shouldExport Should globals be exported
-- @treturn Depencencies The current object (allows chaining)
function Dependencies:Export(shouldExport)
	self.shouldExport = shouldExport
	return self
end

return {
	File = File,
	Dependencies = Dependencies,
	Depends = function(path)
		return setmetatable({mainFiles = {}, files = {}, path = path, shouldExport = false}, {__index=Dependencies})
	end,
}