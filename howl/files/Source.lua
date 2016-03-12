--- A source location for a series of files.
-- This holds a list of inclusion and exclusion filters.
-- @classmod howl.files.Source

local assert = require "howl.lib.assert"
local class = require "howl.class"
local matcher = require "howl.files.matcher"
local mixin = require "howl.class.mixin"

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

function Source:initialize(allowEmpty)
	if allowEmpty == nil then allowEmpty = true end

	self.includes = {}
	self.excludes = {}
	self.allowEmpty = allowEmpty
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
	return matches(self.excludes, text)
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
		assert.type(item.with, "table", "expected table for with1, got %s")
		for _, v in ipairs(item.with) do
			self:with(v)
		end
	end
end

function Source:matches(text)
	return self:included(text) and not self:excluded(text)
end

return Source
