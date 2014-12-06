--- @module ArgParse

local Parameter = {}
function Parameter:Matches(arg, options, tArgs)
	if arg:sub(1,1) ~= "-" then
		return false
	end
	arg = arg:sub(2)

	if not (arg:find("^"..self.name.."$") or arg:find("^"..self.shortcut.."$")) then
		return false
	end

	local val = table.remove(tArgs, 1)

	if self.isMulti then
		options[self.name] = options[self.name] or {}
		table.insert(options[self.name], val)
	else
		options[self.name] = val
	end

	return true
end

function Parameter:Shortcut(shortcut)
	self.shortcut = shortcut
	return self
end

function Parameter:Multi()
	self.isMulti = true
	return self
end

function Parameter:Default(value)
	self.default = value
	return self
end

local Switch = {}
function Switch:Matches(arg, options, tArgs)
	if arg:sub(1,1) ~= "-" then
		return false
	end
	arg = arg:sub(2)

	if not (arg:find("^"..self.name.."$") or arg:find("^"..self.shortcut.."$")) then
		return false
	end

	options[self.name] = true
	return true
end

function Switch:Shortcut(shortcut)
	self.shortcut = shortcut
	return self
end

function Switch:Default(value)
	self.default = value
	return self
end

local Argument = {}
function Argument:Matches(arg, options, tArgs)
	if self.matched then
		return false
	end

	if self.count == 1 then
		options[self.name] = arg
	else
		local count = self.count
		if count == "*" then
			count = #tArgs
		else
			count = count - 1
		end
		local args = {arg}
		for i=1, count do
			table.insert(args, table.remove(tArgs, 1))
		end
		options[self.name] = args
	end

	self.matched = true
	return true
end

function Argument:Count(count)
	assert(type(count) == "number" or count == "*", "Bad argument to Argument:count. Expected number, got " .. count)
	self.count = count
	return self
end

function Argument:Default(value)
	self.default = value
	return self
end

local Parser = {}
--- Add a parameter (--key=value)
-- @tparam string The name of the parameter
-- @treturn Parameter The created parameter object
function Parser:Parameter(name)
	local param = setmetatable({name=name,shortcut=name}, {__index=Parameter})
	table.insert(self.parameters, param)
	self.changed = true
	return param
end

---Add a switch (-v)
-- @tparam string The name of the switch
-- @treturn Switch The created switch object
function Parser:Switch(name)
	local switch = setmetatable({name=name,shortcut=name}, {__index=Switch})
	table.insert(self.switches, switch)
	self.changed = true
	return switch
end

--- Add an argument (<value>)
-- @tparam string The name of the argument
-- @treturn Argument The created argument object
function Parser:Argument(name)
	local arg = setmetatable({name=name,count=1}, {__index=Argument})
	table.insert(self.arguments, arg)
	self.changed = true
	return arg
end

--- Sets the usage of this parser
-- @tparam string The usage string
-- @treturn Parser the current object
function Parser:Usage(str)
	self.usage = str
	return self
end

function Parser:ParseArg(arg, args)
	for _, v in ipairs(self.parameters) do
		if v:Matches(arg, self.options, args) then
			return true
		end
	end
	for _, v in ipairs(self.switches) do
		if v:Matches(arg, self.options, args) then
			return true
		end
	end
	for _, v in ipairs(self.arguments) do
		if v:Matches(arg, self.options, args) then
			return true
		end
	end
	return false
end

function Parser:Parse()
	local spare = {}
	local args = self.args
	for arg in function() return table.remove(args, 1) end do
		if not self:ParseArg(arg, args) then
			table.insert(spare, arg)
		end
	end
	self.args = spare
	self.changed = false
	return self
end

function Parser:Get(name)
	for _, v in ipairs(self.parameters) do
		if v.name == name then return v end
	end
	for _, v in ipairs(self.switches) do
		if v.name == name then return v end
	end
	for _, v in ipairs(self.arguments) do
		if v.name == name then return v end
	end
end

--- Gets the parser's options, recalculating if needed
-- @treturn table A dictionary of calculated results
function Parser:Options()
	if self.changed then
		self:Parse()
	end

	options = {}
	-- Copy the table incase defaults are changed
	for k, v in pairs(self.options) do
		options[k] = v
	end

	for _, v in ipairs(self.parameters) do
		local default, name = v.default, v.name
		-- If the default value is not nil and there is no current value then set it to the default
		if default ~= nil and options[name] == nil then options[name] = default end
	end
	for _, v in ipairs(self.switches) do
		local default, name = v.default, v.name
		if default ~= nil and options[name] == nil then options[name] = default end
	end
	for _, v in ipairs(self.arguments) do
		local default, name = v.default, v.name
		if default ~= nil and options[name] == nil then options[name] = default end
	end

	for _, v in pairs(self.onChanged) do v(self, options) end

	return options
end

--- Adds an event listener to the options
-- @tparam function callback The function to call
-- @treturn Parser The current object
function Parser:OnChanged(callback)
	table.insert(self.onChanged, callback)
	return self
end

return function(args)
	return setmetatable({
		parameters={},
		switches={},
		arguments={},

		args = args,
		options = {},
		changed = false,
		onChanged = {}
	}, {__index=Parser})
end