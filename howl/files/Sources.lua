--- A source location for a series of files.
-- This holds a list of inclusion and exclusion filters.
-- @classmod howl.files.Source

local assert = require "howl.lib.assert"
local class = require "howl.class"
local fs = require "howl.platform".fs
local matcher = require "howl.files.matcher"
local mixin = require "howl.class.mixin"

local Source = require "howl.files.Source"

local insert = table.insert

local Sources = class("howl.files.Sources"):include(mixin.configurable)

function Sources:initialize(root)
	assert.argType(root, "string", "Sources", 1)
	self.root = root
	self.rootSource = Source(false)
	self.sources = { [''] = self.rootSource }
end

function Sources:from(path, configure)
	assert.argType(path, "string", "from", 1)
	path = fs.normalise(path)

	local source = self.sources[path]
	if not source then
		source = Source(path)
		self.sources[path] = source
	end

	if configure ~= nil then
		return source:configureWith(configure)
	else
		return source
	end
end

function Sources:include(...)
	self.rootSource:include(...)
	return self
end

function Sources:exclude(...)
	self.rootSource:exclude(...)
	return self
end

function Sources:configure(item)
	self.rootSource:configure(item)
	return self
end

function Sources:configureWith(item)
	self.rootSource:configureWith(item)
	return self
end

function Sources:getFiles()
	local outList, n = {}, 0

	local root = self.rootSource
	for dir, source in pairs(self.sources) do
		if source.allowEmpty or #source.includes > 0 then
			local whole = fs.combine(self.root, dir)

			-- I lied. Its a stack
			local queue, queueN = { whole }, 1

			while queueN > 0 do
				local top = queue[queueN]
				local relative = top:sub(#whole + 2)
				queueN = queueN - 1

				if fs.isDir(top) then
					if not source:excluded(relative) and (root == source or not root:excluded(relative)) then
						for _, v in ipairs(fs.list(top)) do
							queueN = queueN + 1
							queue[queueN] = fs.combine(top, v)
						end
					end
				elseif source:included(relative) and not source:excluded(relative) and (root == source or not root:excluded(relative)) then
					n = n + 1
					outList[n] = { top, relative }
				end
			end
		end
	end

	return outList
end

return Sources
