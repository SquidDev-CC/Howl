--- Holds variables for one scope
-- This implementation is inefficient. Instead of using hashes,
-- a linear search is used instead to look up variables
-- @module howl.lexer.Scope

local keywords = require "howl.lexer.constants".Keywords

--- Holds the data for one variable
-- @table Variable
-- @tfield Scope Scope The parent scope
-- @tfield string Name The name of the variable
-- @tfield boolean IsGlobal Is the variable global
-- @tfield boolean CanRename If the variable can be renamed
-- @tfield int References Number of references

--- Holds variables for one scope
-- @type Scope
-- @tfield ?|Scope Parent The parent scope
-- @tfield table Locals A list of locals variables
-- @tfield table Globals A list of global variables
-- @tfield table Children A list of children @{Scope|scopes}

local Scope = {}

--- Add a local to this scope
-- @tparam Variable variable The local object
function Scope:AddLocal(name, variable)
	table.insert(self.Locals, variable)
	self.LocalMap[name] = variable
end

--- Create a @{Variable} and add it to the scope
-- @tparam string name The name of the local
-- @treturn Variable The created local
function Scope:CreateLocal(name)
	local variable = self:GetLocal(name)
	if variable then return variable end

	variable = {
		Scope = self,
		Name = name,
		IsGlobal = false,
		CanRename = true,
		References = 1,
	}

	self:AddLocal(name, variable)
	return variable
end

--- Get a local variable
-- @tparam string name The name of the local
-- @treturn ?|Variable The variable
function Scope:GetLocal(name)
	repeat
		local var = self.LocalMap[name]
		if var then return var end


		self = self.Parent
	until not self
end

--- Find an local variable by its old name
-- @tparam string name The old name of the local
-- @treturn ?|Variable The local variable
function Scope:GetOldLocal(name)
	if self.oldLocalNamesMap[name] then
		return self.oldLocalNamesMap[name]
	end
	return self:GetLocal(name)
end

--- Rename a local variable
-- @tparam string|Variable oldName The old variable name
-- @tparam string newName The new variable name
function Scope:RenameLocal(oldName, newName)
	oldName = type(oldName) == 'string' and oldName or oldName.Name

	repeat
		local var = self.LocalMap[oldName]
		if var then
			var.Name = newName
			self.oldLocalNamesMap[oldName] = var
			self.LocalMap[oldName] = nil
			self.LocalMap[newName] = var
			break
		end

		self = self.Parent
	until not self
end

--- Add a global to this scope
-- @tparam Variable name The name of the global
function Scope:AddGlobal(name, variable)
	table.insert(self.Globals, variable)
	self.GlobalMap[name] = variable
end

--- Create a @{Variable} and add it to the scope
-- @tparam string name The name of the global
-- @treturn Variable The created global
function Scope:CreateGlobal(name)
	local variable = self:GetGlobal(name)
	if variable then return variable end

	variable = {
		Scope = self,
		Name = name,
		IsGlobal = true,
		CanRename = true,
		References = 1,
	}

	self:AddGlobal(name, variable)
	return variable
end

--- Get a global variable
-- @tparam string name The name of the global
-- @treturn ?|Variable The variable
function Scope:GetGlobal(name)
	repeat
		local var = self.GlobalMap[name]
		if var then return var end


		self = self.Parent
	until not self
end

--- Get a variable by name
-- @tparam string name The name of the variable
-- @treturn ?|Variable The found variable
-- @fixme This is a very inefficient implementation, as with @{Scope:GetLocal} and @{Scope:GetGlocal}
function Scope:GetVariable(name)
	return self:GetLocal(name) or self:GetGlobal(name)
end

--- Get all variables in the scope
-- @treturn table A list of @{Variable|variables}
function Scope:GetAllVariables()
	return self:getVars(true, self:getVars(true))
end

--- Get all variables
-- @tparam boolean top If this values is the 'top' of the function stack
-- @tparam table ret Table to fill with return values (optional)
-- @treturn table The variables
-- @local
function Scope:getVars(top, ret)
	local ret = ret or {}
	if top then
		for _, v in pairs(self.Children) do
			v:getVars(true, ret)
		end
	else
		for _, v in pairs(self.Locals) do
			table.insert(ret, v)
		end
		for _, v in pairs(self.Globals) do
			table.insert(ret, v)
		end
		if self.Parent then
			self.Parent:getVars(false, ret)
		end
	end
	return ret
end

--- Rename all locals to smaller values
-- @tparam string validNameChars All characters that can be used to make a variable name
-- @fixme Some of the string generation happens a lot, this could be looked at
function Scope:ObfuscateLocals(validNameChars)
	-- Use values sorted for letter frequency instead
	local startChars = validNameChars or "etaoinshrdlucmfwypvbgkqjxz_ETAOINSHRDLUCMFWYPVBGKQJXZ"
	local otherChars = validNameChars or "etaoinshrdlucmfwypvbgkqjxz_0123456789ETAOINSHRDLUCMFWYPVBGKQJXZ"

	local startCharsLength, otherCharsLength = #startChars, #otherChars
	local index = 0
	local floor = math.floor
	for _, var in pairs(self.Locals) do
		local name

		repeat
			if index < startCharsLength then
				index = index + 1
				name = startChars:sub(index, index)
			else
				if index < startCharsLength then
					index = index + 1
					name = startChars:sub(index, index)
				else
					local varIndex = floor(index / startCharsLength)
					local offset = index % startCharsLength
					name = startChars:sub(offset, offset)

					while varIndex > 0 do
						offset = varIndex % otherCharsLength
						name = otherChars:sub(offset, offset) .. name
						varIndex = floor(varIndex / otherCharsLength)
					end
					index = index + 1
				end
			end
		until not (keywords[name] or self:GetVariable(name))
		self:RenameLocal(var.Name, name)
	end
end

--- Converts the scope to a string
-- No, it actually just returns '&lt;scope&gt;'
-- @treturn string '&lt;scope&gt;'
function Scope:ToString()
	return '<Scope>'
end

--- Create a new scope
-- @tparam Scope parent The parent scope
-- @treturn Scope The created scope
local function NewScope(parent)
	local scope = setmetatable({
		Parent = parent,
		Locals = {},
		LocalMap = {},
		Globals = {},
		GlobalMap = {},
		oldLocalNamesMap = {},
		Children = {},
	}, { __index = Scope })

	if parent then
		table.insert(parent.Children, scope)
	end

	return scope
end

return NewScope
