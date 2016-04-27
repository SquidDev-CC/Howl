--- A source location for a series of files.
-- This holds a list of inclusion and exclusion filters.
-- @classmod howl.files.Source

local assert = require "howl.lib.assert"
local class = require "howl.class"
local matcher = require "howl.files.matcher"
local mixin = require "howl.class.mixin"
local fs = require "howl.platform".fs

local insert = table.insert

local Source = class("howl.files.Source")
	:include(mixin.configurable)
	:include(mixin.filterable)

local function extractPattern(item)
	local t = type(item)
	if t == "function" or t == "string" then
		return matcher.createMatcher(item)
	elseif t == "table" and item.tag and item.predicate then
		return item
	else
		return nil
	end
end

local function append(destination, source, func, i)
	local extracted = extractPattern(source)
	local t = type(source)
	if extracted then
		insert(destination, extracted)
	elseif t == "table" then
		for i, item in ipairs(source) do
			local extracted = extractPattern(item)
			if extracted then
				insert(destination, extracted)
			else
				error("bad item #" .. i .. " for " .. func .. " (expected pattern, got " .. type(item) .. ")")
			end
		end
	else
		error("bad argument #" .. i .. " for " .. func .. " (expected pattern, got " .. t .. ")")
	end
end

local function matches(items, text)
	for _, pattern in pairs(items) do
		if pattern:match(text) then
			return true
		end
	end

	return false
end

function Source:initialize(allowEmpty, parent)
	if allowEmpty == nil then allowEmpty = true end

	self.parent = parent
	self.children = {}

	self.includes = {}
	self.excludes = {}
	self.allowEmpty = allowEmpty
end

function Source:from(path, configure)
	assert.argType(path, "string", "from", 1)
	path = fs.normalise(path)

	local source = self.children[path]
	if not source then
		source = self.class(true)
		self.children[path] = source
		self.allowEmpty = false
	end

	if configure ~= nil then
		return source:configureWith(configure)
	else
		return source
	end
end

function Source:include(...)
	local n = select('#', ...)
	local args = {...}
	for i = 1, n do
		append(self.includes, args[i], "include", i)
	end

	return self
end

function Source:exclude(...)
	local n = select('#', ...)
	local args = {...}
	for i = 1, n do
		append(self.excludes, args[i], "exclude", i)
	end

	return self
end

function Source:excluded(text)
	if matches(self.excludes, text) then
		return true
	elseif self.parent then
		-- FIXME: Combine this path
		return self.parent:excluded(text)
	else
		return false
	end
end

function Source:included(text)
	if #self.includes == 0 then
		return self.allowEmpty
	else
		return matches(self.includes, text)
	end
end

function Source:configure(item)
	assert.argType(item, "table", "configure", 1)
	-- TODO: Ensure other keys aren't passed
	-- TODO: Fix passing other source instances

	if item.include ~= nil then self:include(item.include) end
	if item.exclude ~= nil then self:exclude(item.exclude) end

	if item.with ~= nil then
		assert.type(item.with, "table", "expected table for with, got %s")
		for _, v in ipairs(item.with) do
			self:with(v)
		end
	end
end

function Source:matches(text)
	return self:included(text) and not self:excluded(text)
end

function Source:gatherFiles(root, includeDirectories, outList)
	if not outList then outList = {} end

	for dir, source in pairs(self.children) do
		local path = fs.combine(root, dir)
		source:gatherFiles(path, includeDirectories, outList)
	end

	if self.allowEmpty or #self.includes > 0 then
		-- I lied. Its a stack
		local queue, queueN = { root }, 1

		local n = #outList
		while queueN > 0 do
			local path = queue[queueN]
			local relative = path:sub(#root + 2)
			queueN = queueN - 1

			if fs.isDir(path) then
				if not self:excluded(relative) then
					if dirs and dir ~= relative and self:included(relative) then
						n = n + 1
						outList[n] = self:buildFile(path, relative)
					end

					for _, v in ipairs(fs.list(path)) do
						queueN = queueN + 1
						queue[queueN] = fs.combine(path, v)
					end
				end
			elseif self:included(relative) and not self:excluded(relative) then
				n = n + 1
				outList[n] = self:buildFile(path, relative)
			end
		end
	end

	return outList
end

function Source:buildFile(path, relative)
	return {
		path = path,
		relative = relative,
		name = relative,
	}
end

return Source
