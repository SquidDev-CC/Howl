local type, pairs = type, pairs

local Subscriber = {}
function Subscriber:update(options)
	if options then
		self.fn = options.fn or self.fn
		self.options = options.options or self.options
	end
end

local function SubscriberFactory(fn, options)
	return setmetatable({
		options = options or {},
		fn = fn,
		channel = nil,
		id = math.random(1000000000), -- sounds reasonable, rite?
	}, { __index = Subscriber })
end

local Channel = {}
local function ChannelFactory(namespace, parent)
	return setmetatable({
		stopped = false,
		namespace = namespace,
		callbacks = {},
		channels = {},
		parent = parent,
	}, { __index = Channel })
end

function Channel:addSubscriber(fn, options)
	local callback = SubscriberFactory(fn, options)
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
	self.channels[namespace] = ChannelFactory(namespace, self)
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

			if value then result[#result] = value end
			if continue == false then return false, result end
		end
	end

	if parent then
		return parent:publish(result, ...)
	else
		return true, result
	end
end

local channel = ChannelFactory('root')
local function GetChannel(channelNamespace)
	local channel = channel

	if type(channelNamespace) == "string" then
		if channelNamespace:find(":") then
			channelNamespace = { channelNamespace:match((channelNamespace:gsub("[^:]+:?", "([^:]+):?"))) }
		else
			channelNamespace = { channelNamespace }
		end
	end

	for i = 1, #channelNamespace do
		channel = channel:getChannel(channelNamespace[i])
	end

	return channel
end

local function Subscribe(channelNamespace, fn, options)
	return GetChannel(channelNamespace):addSubscriber(fn, options)
end

local function GetSubscriber(id, channelNamespace)
	return GetChannel(channelNamespace):getSubscriber(id)
end

local function RemoveSubscriber(id, channelNamespace)
	return GetChannel(channelNamespace):removeSubscriber(id)
end

local function Publish(channelNamespace, ...)
	return GetChannel(channelNamespace):publish({}, ...)
end

return {
	GetChannel = GetChannel,
	Subscribe = Subscribe,
	GetSubscriber = GetSubscriber,
	RemoveSubscriber = RemoveSubscriber,
	Publish = Publish,
}
