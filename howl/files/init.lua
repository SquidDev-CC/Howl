--- Handles a list of files
-- @classmod howl.files.Files

local Mediator = require "howl.lib.mediator"
local utils = require "howl.lib.utils"
local assert = require "howl.lib.assert"
local class = require "howl.class"
local mixin = require "howl.class.mixin"

--- Handles a list of files
local Files = class("howl.files.Files"):include(mixin.sealed)

--- Include a series of files/folders
-- @tparam string match The match to include
-- @treturn Files The current object (allows chaining)
function Files:Add(match)
	if type(match) == "table" then
		for _, v in ipairs(match) do
			self:Add(v)
		end
	else
		table.insert(self.include, self:_Parse(match))
		self.files = nil
	end
	return self
end

--- Exclude a file
-- @tparam string match The file/wildcard to exclude
-- @treturn Files The current object (allows chaining)
function Files:Remove(match)
	if type(match) == "table" then
		for _, v in ipairs(match) do
			self:Remove(v)
		end
	else
		table.insert(self.exclude, self:_Parse(match))
		self.files = nil
	end

	return self
end

Files.Include = Files.Add
Files.Exclude = Files.Remove

--- Path to the startup file
-- @tparam string file The file to startup with
-- @treturn Files The current object (allows chaining)
function Files:Startup(file)
	self.startup = file
	return self
end

--- Find all files
-- @treturn table List of files, the keys are their names
function Files:Files()
	if not self.files then
		self.files = {}

		for _, match in ipairs(self.include) do
			if match.Type == "Normal" then
				self:_Include(match.Text)
			else
				self:_Include("", match)
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
	elseif not pattern or pattern.Match(path) then
		self.files[path] = true
	end
end

--- Parse a pattern
-- @tparam string match The pattern to parse
-- @treturn howl.lib.utils.Pattern The created pattern
-- @local
function Files:_Parse(match)
	match = utils.parsePattern(match)
	local text = match.Text

	if match.Type == "Normal" then
		function match.Match(toMatch) return text == toMatch end
	else
		function match.Match(toMatch) return toMatch:match(text) end
	end
	return match
end

--- Create a new @{Files|files object}
-- @tparam string path The path
-- @treturn Files The resulting object
function Files:initialize(path)
	assert.type(path, "string", "bad argument #1 for Files expected string, got %s")
	self.path = path
	self.include = {}
	self.exclude = {}
	self.startup = 'startup'

	self:Remove { ".git", ".idea", "Howlfile.lua", "Howlfile", "build" }
end

Mediator:subscribe({ "HowlFile", "env" }, function(env, context)
	env.Files = function(path)
		return Files(path or context.root)
	end
end)

return Files
