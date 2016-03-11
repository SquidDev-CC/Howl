--- Parses command line arguments
-- @module howl.lib.argparse

local colored = require "howl.lib.colored"

--- Simple wrapper for Options
-- @type Option
local Option = {
	__index = function(self, func)
		return function(self, ...)
			local parser = self.parser
			local value = parser[func](parser, self.name, ...)

			if value == parser then return self end -- Allow chaining
			return value
		end
	end
}

--- Parses command line arguments
-- @type Parser
local Parser = {}

--- Returns the value of a option
-- @tparam string name The name of the option
-- @tparam string|boolean default The default value (optional)
-- @treturn string|boolean The value of the option
function Parser:Get(name, default)
	local options = self.options

	local value = options[name]
	if value ~= nil then return value end

	local settings = self.settings[name]
	if settings then
		local aliases = settings.aliases
		if aliases then
			for _, alias in ipairs(aliases) do
				value = options[alias]
				if value ~= nil then return value end
			end
		end

		value = settings.default
		if value ~= nil then return value end
	end


	return default
end

--- Ensure a option exists, throw an error otherwise
-- @tparam string name The name of the option
-- @treturn string|boolean The resulting value
function Parser:Ensure(name)
	local value = self:Get(name)
	if value == nil then
		error(name .. " must be set")
	end
	return value
end

--- Set the default value for an option
-- @tparam string name The name of the options
-- @tparam string|boolean value The default value
-- @treturn Parser The current object
function Parser:Default(name, value)
	if value == nil then value = true end
	self:_SetSetting(name, "default", value)

	self:_Changed()
	return self
end

--- Sets an alias for an option
-- @tparam string name The name of the option
-- @tparam string alias The alias of the option
-- @treturn Parser The current object
function Parser:Alias(name, alias)
	local settings = self.settings
	local currentSettings = settings[name]
	if currentSettings then
		local currentAliases = currentSettings.aliases
		if currentAliases == nil then
			currentSettings.aliases = { alias }
		else
			table.insert(currentAliases, alias)
		end
	else
		settings[name] = { aliases = { alias } }
	end

	self:_Changed()
	return self
end

--- Sets the description, and type for an option
-- @tparam string name The name of the option
-- @tparam string description The description of the option
-- @treturn Parser The current object
function Parser:Description(name, description)
	return self:_SetSetting(name, "description", description)
end

--- Sets if this option takes a value
-- @tparam string name The name of the option
-- @tparam boolean takesValue If the option takes a value
-- @treturn Parser The current object
function Parser:TakesValue(name, takesValue)
	if takesValue == nil then
		takesValue = true
	end
	return self:_SetSetting(name, "takesValue", takesValue)
end

--- Sets a setting for an option
-- @tparam string name The name of the option
-- @tparam string key The key of the setting
-- @tparam boolean|string value The value of the setting
-- @treturn Parser The current object
-- @local
function Parser:_SetSetting(name, key, value)
	local settings = self.settings
	local thisSettings = settings[name]

	if thisSettings then
		thisSettings[key] = value
	else
		settings[name] = { [key] = value }
	end

	return self
end

--- Creates a useful option helper object
-- @tparam string name The name of the option
-- @treturn Option The created option
function Parser:Option(name)
	return setmetatable({
		name = name,
		parser = self
	}, Option)
end

--- Returns a list of arguments
-- @treturn table The argument list
function Parser:Arguments()
	return self.arguments
end

--- Fires the on changed event
-- @local
function Parser:_Changed()
	self.mediator:publish({ "ArgParse", "changed" }, self)
end

--- Generates a help string
-- @tparam string indent The indent to print it at
function Parser:Help(indent)
	for name, settings in pairs(self.settings) do
		local prefix = '-'

		-- If we take a value then we should say so
		if settings.takesValue then
			prefix = "--"
			name = name .. "=value"
		end

		-- If length is more than one then we should set
		-- the prefix to be --
		if #name > 1 then
			prefix = '--'
		end

		colored.writeColor("white", indent .. prefix .. name)

		local aliasStr = ""
		local aliases = settings.aliases
		if aliases and #aliases > 0 then
			local aliasLength = #aliases
			aliasStr = aliasStr .. " ("

			for i = 1, aliasLength do
				local alias = "-" .. aliases[i]

				if #alias > 2 then -- "-" and another character
					alias = "-" .. alias
				end

				if i < aliasLength then
					alias = alias .. ', '
				end

				aliasStr = aliasStr .. alias
			end
			aliasStr = aliasStr .. ")"
		end

		colored.writeColor("brown", aliasStr)
		local description = settings.description
		if description and description ~= "" then
			colored.printColor("lightGray", " " .. description)
		end
	end
end

--- Parse the options
-- @treturn Parser The current object
function Parser:Parse(args)
	local options = self.options
	local arguments = self.arguments
	for _, arg in ipairs(args) do
		if arg:sub(1, 1) == "-" then -- Match `-`
			if arg:sub(2, 2) == "-" then -- Match `--`
				local key, value = arg:match("([%w_%-]+)=([%w_%-]+)", 3) -- Match [a-zA-Z0-9_-] in form key=value
				if key then
					options[key] = value
				else
					-- If it starts with not- or not_ then negate it
					arg = arg:sub(3)
					local beginning = arg:sub(1, 4)
					local value = true
					if beginning == "not-" or beginning == "not_" then
						value = false
						arg = arg:sub(5)
					end
					options[arg] = value
				end
			else -- Handle switches
				for i = 2, #arg do
					options[arg:sub(i, i)] = true
				end
			end
		else
			table.insert(arguments, arg)
		end
	end

	return self
end

--- Create a new options parser
-- @tparam table args The command line arguments passed
-- @treturn Parser The resulting parser
local function Options(mediator, args)
	return setmetatable({
		options = {}, -- The resulting values
		arguments = {}, -- Spare arguments
		mediator = mediator,

		settings = {}, -- Settings for options
	}, { __index = Parser }):Parse(args)
end

--- @export
return {
	Parser = Parser,
	Options = Options,
}
