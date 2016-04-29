--- A source location for a series of files.
-- This holds a list of inclusion and exclusion filters.
-- @classmod howl.files.Source

local assert = require "howl.lib.assert"
local matcher = require "howl.files.matcher"
local mixin = require "howl.class.mixin"
local fs = require "howl.platform".fs

local Source = require "howl.files.Source"

local insert = table.insert

local CopySource = Source:subclass("howl.files.CopySource")

function CopySource:initialize(allowEmpty, parent)
	Source.initialize(self, allowEmpty, parent)

	self.renames = {}
	self.modifiers = {}
end

function CopySource:configure(item)
	assert.argType(item, "table", "configure", 1)
	Source.configure(self, item)

	if item.rename ~= nil then self:rename(item.rename) end
	if item.modify ~= nil then self:modify(item.modify) end
end

function CopySource:rename(from, to)
	local tyFrom, tyTo = type(from), type(to)
	if tyFrom == "table" and to == nil then
		for _, v in ipairs(from) do
			self:rename(v)
		end
	elseif tyFrom == "function" and to == nil then
		insert(self.renames, from)
	elseif tyFrom == "string" and tyTo == "string" then
		insert(self.renames, function(file)
			return (file.name:gsub(from, to))
		end)
	else
		error("bad arguments for rename (expected table, function or string, string pair, got " .. tyFrom .. " and " .. tyTo .. ")", 2)
	end
end


function CopySource:modify(modifier)
	local ty = type(modifier)
	if ty == "table" then
		for _, v in ipairs(modifier) do
			self:modify(v)
		end
	elseif ty == "function" then
		insert(self.modifiers, modifier)
	else
		error("bad argument #1 for modify (expected table or function, got " .. ty .. ")", 2)
	end
end

function CopySource:doMutate(file)
	for _, modifier in ipairs(self.modifiers) do
		local contents = modifier(file)
		if contents then file.contents = contents end
	end

	for _, renamer in ipairs(self.renames) do
		local name = renamer(file)
		if name then file.name = name end
	end

	if self.parent then
		return self.parent:doMutate(file)
	else
		return file
	end
end

function CopySource:buildFile(path, relative)
	return self:doMutate {
		path = path,
		relative = relative,
		name = relative,
		contents = fs.read(path),
	}
end

return CopySource
