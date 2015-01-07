--- Specify multiple dependencies
-- @module depends.Depends

--- Stores a file and the dependencies of the file
-- @type File
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
-- @tparam string|table name Name/list of dependencies
-- @treturn File The current object (allows chaining)
function File:Depends(name)
	if type(name) == "table" then
		for _, file in ipairs(name) do
			self:Depends(file)
		end
	else
		table.insert(self.dependencies, name)
	end

	return self
end

--- Define what this file really really needs
-- @tparam string|table name Name/list of dependencies
-- @treturn File The current object (allows chaining)
function File:Prerequisite(name)
	if type(name) == "table" then
		for _, file in ipairs(name) do
			self:Prerequisite(file)
		end
	else
		table.insert(self.dependencies, 1, name)
	end

	return self
end

--- Should this file be set as a global. This has no effect if the module does not have an name
-- @tparam boolean shouldExport Boolean value setting if it should be exported or not
-- @treturn File The current object (allows chaining)
function File:Export(shouldExport)
	if shouldExport == nil then shouldExport = true end
	self.shouldExport = shouldExport
	return self
end

--- Prevent this file be wrapped in a custom environment or a do...end block
-- @tparam boolean noWrap `true` to prevent the module being wrapped
-- @treturn File The current object (allows chaining)
function File:NoWrap(noWrap)
	if noWrap == nil then noWrap = true end
	self.noWrap = noWrap
	return self
end

--- Stores an entire list of dependencies and handles resolving them
-- @type Dependencies
local Dependencies = {}

--- Create a new Dependencies object
-- @tparam string path The base path of the dependencies
-- @treturn Dependencies The new Dependencies object
local function Factory(path, parent)
	return setmetatable({
		mainFiles = {},
		files = {},
		path = path or HowlFile.CurrentDirectory,
		namespaces = {},
		shouldExport = false,
		parent = parent,
	}, {__index=Dependencies})
end

--- Add a file to the dependency list
-- @tparam string path The path of the file relative to the Dependencies' root
-- @treturn File The created file object
function Dependencies:File(path)
	local file = self:_File(path)
	self.files[path] = file
	return file
end

--- Create a file
-- @tparam string path The path of the file relative to the Dependencies' root
-- @treturn File The created file object
function Dependencies:_File(path)
	return setmetatable({
		dependencies = {},
		name = nil, alias = nil,
		path = path,
		shouldExport = true,
		noWrap = false,
		__isMain = false,
		parent = self,
	}, {__index = File})
end

--- Add a 'main' file to the dependency list. This is a file that will be executed (added to the end of a script)
-- Nothing should depend on it.
-- @tparam string path The path of the file relative to the Dependencies' root
-- @treturn File The created file object
function Dependencies:Main(path)
	local file = self:FindFile(path) or self:_File(path)
	file.__isMain = true
	table.insert(self.mainFiles, file)
	return file
end

--- Basic 'hack' to enable you to add a dependency to the build
-- @tparam string|table name Name/list of dependencies
-- @treturn Dependencies The current object (allows chaining)
function Dependencies:Depends(name)
	local main = self.mainFiles[1]
	assert(main, "Cannot find a main file")
	main:Depends(name)
	return self
end

--- Basic 'hack' to enable you to add a very important dependency to the build
-- @tparam string|table name Name/list of dependencies
-- @treturn Dependencies The current object (allows chaining)
function Dependencies:Prerequisite(name)
	local main = self.mainFiles[1]
	assert(main, "Cannot find a main file")
	main:Prerequisite(name)
	return self
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

	-- If we have no dependencies
	local mainFiles = self.mainFiles
	if #mainFiles == 0 then mainFiles = self.files end
	return coroutine.wrap(function()
		for _, file in ipairs(mainFiles) do
			internalLoop(file)
		end
	end)
end

--- Return a table of exported values
-- @tparam boolean shouldExport Should globals be exported
-- @treturn Depencencies The current object (allows chaining)
function Dependencies:Export(shouldExport)
	self.shouldExport = shouldExport
	return self
end

--- Generate a submodule
-- @tparam string name The name of the namespace
-- @tparam string path The sub path of the namespace
-- @tparam function generator Function used to add dependencies
-- @treturn Dependencies The resulting namespace
function Dependencies:Namespace(name, path, generator)
	local namespace = Factory(fs.combine(self.path, path or ""), self)
	self.namespaces[name] = namespace
	generator(namespace)
	return namespace
end

--- Clone dependencies, whilst ignoring the main file
-- @tparam boolean deep Deep clone dependencies
-- @tparam Dependencies The cloned dependencies object
function Dependencies:CloneDependencies(deep)
	local result = setmetatable({ }, {__index=Dependencies})

	for k, v in pairs(self) do
		result[k] = v
	end

	result.mainFiles = {}
	return result
end

-- Setup a HowlFile hook
HowlFile.EnvironmentHook(function(env)
	env.Dependencies = Factory
	env.Sources = Factory()
end)

--- @export
return {
	File = File,
	Dependencies = Dependencies,
	Factory = Factory,
}