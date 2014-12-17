--- Handles a list of files
-- @module files.Files

--- Handles a list of files
-- @type Files
local Files = {}

--- Include a series of files/folders
-- @tparam string match The match to include
-- @treturn Files The current object (allows chaining)
function Files:Add(match)
	table.insert(self.include, self:_Parse(match))
	self.files = nil
	return self
end

--- Exclude a file
-- @tparam string match The file/wildcard to exclude
-- @treturn Files The current object (allows chaining)
function Files:Remove(match)
	table.insert(self.exclude, self:_Parse(match))
	self.files = nil

	return self
end

Files.Include = Files.Add
Files.Exclude = Files.Remove

--- Find all files
-- @treturn table List of files, the keys are their names
function Files:Files()
	if  not self.files then
		self.files = {}

		for _, match in ipairs(self.include) do
			if match.Type == "Normal" then
				self:_Include(match.Text)
			else
				self:_Include("", match.Text)
			end
		end
	end

	return self.files
end

--- Handles the grunt work. Includes recursivly
-- @tparam string path The path to include
-- @tparam string pattern Pattern to match
-- @local
function Files:_Include(path, pattern)
	if path ~= "" then
		for _, pattern in pairs(self.exclude) do
			if pattern.Match(path) then return end
		end
	end

	local realPath = fs.combine(self.path, path)
	assert(fs.exists(realPath), "Cannot find path " .. path)

	if fs.isDir(realPath) then
		for _, file in ipairs(fs.list(realPath)) do
			self:_Include(fs.combine(path, file), pattern)
		end
	elseif not pattern or pattern:match(path) then
		self.files[path] = true
	end
end

--- Parse a pattern
-- @tparam string match The pattern to parse
-- @treturn Utils.Pattern The created pattern
-- @tlocal
function Files:_Parse(match)
	match = Utils.ParsePattern(match)
	local text = match.Text

	if Utils.Type == "Normal" then
		function match.Match(toMatch) return text == toMatch end
	else
		function match.Match(toMatch) return toMatch:match(text) end
	end
	return match
end

--- Create a new @{Files|files object}
-- @tparam ?|string path The path
-- @treturn Files The resulting object
local function Factory(path)
	return setmetatable({
		path = path or HowlFile.CurrentDirectory,
		include = {},
		exclude = {},
		startup = 'startup'
	}, {__index = Files})
end

HowlFile.EnvironmentHook(function(env)
	env.Files = Factory
end)

--- @export
return {
	Files = Files,
	Factory = Factory,
}