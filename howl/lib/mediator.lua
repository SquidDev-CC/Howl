--- Mediator pattern implementation for pub-sub management
--
-- [Adapted from Olivine Labs' Mediator](http://olivinelabs.com/mediator_lua/)
-- @module howl.lib.mediator

local class = require "howl.class"
local mixin = require "howl.class.mixin"

local function getUniqueId()
	return tonumber(tostring({}):match(':%s*[0xX]*(%x+)'), 16)
end

--- A subscriber to a channel
-- @type Subscriber
local Subscriber = class("howl.lib.mediator.Subscriber"):include(mixin.sealed)

--- Create a new subscriber
-- @tparam function fn The function to execute
-- @tparam table options Options to use
-- @constructor
function Subscriber:initialize(fn, options)
	self.id = getUniqueId()
	self.options = options or {}
	self.fn = fn
end

--- Update the subscriber with new options
-- @tparam table options Options to use
function Subscriber:update(options)
	self.fn = options.fn or self.fn
	self.options = options.options or self.options
end


--- Channel class and functions
-- @type Channel
local Channel = class("howl.lib.mediator.Channel"):include(mixin.sealed)

function Channel:initialize(namespace, parent)
	self.stopped = false
	self.namespace = namespace
	self.callbacks = {}
	self.channels = {}
	self.parent = parent
end

function Channel:addSubscriber(fn, options)
	local callback = Subscriber(fn, options)
	local priority = (#self.callbacks + 1)

	options = options or {}

	if options.priority and
		options.priority >= 0 and
		options.priority < priority
	then
		priority = options.priority
	end

	table.insert(self.callbacks, priority, callback)

	return callback
end

function Channel:getSubscriber(id)
	for i = 1, #self.callbacks do
		local callback = self.callbacks[i]
		if callback.id == id then return { index = i, value = callback } end
	end
	local sub
	for _, channel in pairs(self.channels) do
		sub = channel:getSubscriber(id)
		if sub then break end
	end
	return sub
end

function Channel:setPriority(id, priority)
	local callback = self:getSubscriber(id)

	if callback.value then
		table.remove(self.callbacks, callback.index)
		table.insert(self.callbacks, priority, callback.value)
	end
end

function Channel:addChannel(namespace)
	self.channels[namespace] = Channel(namespace, self)
	return self.channels[namespace]
end

function Channel:hasChannel(namespace)
	return namespace and self.channels[namespace] and true
end

function Channel:getChannel(namespace)
	return self.channels[namespace] or self:addChannel(namespace)
end

function Channel:removeSubscriber(id)
	local callback = self:getSubscriber(id)

	if callback and callback.value then
		for _, channel in pairs(self.channels) do
			channel:removeSubscriber(id)
		end

		return table.remove(self.callbacks, callback.index)
	end
end

function Channel:publish(result, ...)
	for i = 1, #self.callbacks do
		local callback = self.callbacks[i]

		-- if it doesn't have a predicate, or it does and it's true then run it
		if not callback.options.predicate or callback.options.predicate(...) then
			-- just take the first result and insert it into the result table
			local continue, value = callback.fn(...)

			if value ~= nil then table.insert(result, value) end
			if continue == false then return false, result end
		end
	end

	if self.parent then
		return self.parent:publish(result, ...)
	else
		return true, result
	end
end

--- Mediator class and functions
local Mediator = setmetatable(
	{
		Channel = Channel,
		Subscriber = Subscriber
	},
	{
		__call = function(fn, options)
			return {
				channel = Channel('root'),

				getChannel = function(self, channelNamespace)
					local channel = self.channel

					for i=1, #channelNamespace do
						channel = channel:getChannel(channelNamespace[i])
					end

					return channel
				end,

				subscribe = function(self, channelNamespace, fn, options)
					return self:getChannel(channelNamespace):addSubscriber(fn, options)
				end,

				getSubscriber = function(self, id, channelNamespace)
					return self:getChannel(channelNamespace):getSubscriber(id)
				end,

				removeSubscriber = function(self, id, channelNamespace)
					return self:getChannel(channelNamespace):removeSubscriber(id)
				end,

				publish = function(self, channelNamespace, ...)
					return self:getChannel(channelNamespace):publish({}, ...)
				end
			}
		end
	}
)
return Mediator()
