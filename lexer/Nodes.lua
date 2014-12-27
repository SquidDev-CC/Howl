--- Basic nodes
-- @module lexer.Nodes

local pcall = pcall

local nodeMappings = {}

local Node = {}
local NodeMeta = { __index = Node }

local function Subclass(object)
	nodeMappings[object.AstType] = object
	local newMeta = {}
	for k, v in pairs(NodeMeta) do
		newMeta[k] = v
	end
	newMeta.__index = object
	return setmetatable(object, newMeta)
end

local function Simplify(object, fields)
	for _, param in ipairs(fields) do
		local obj = object[param]
		if obj.Simplify then
			object[param] = object:Simplify()
		elseif #obj > 0 then
			for i, val in ipairs(obj) do
				obj[i] = val:Simplify()
			end
		end
	end
	return self
end

local binOpMappings, unOpMappings = {}, {}
do -- Handle Operations
	local binOp = {
		['+']   = {function(a, b) return a + b end,   '_add', 'Add'},
		['-']   = {function(a, b) return a - b end,   '_sub', 'Subtract'},
		['%']   = {function(a, b) return a % b end,   '_mod', 'Modulus'},
		['/']   = {function(a, b) return a / b end,   '_div', 'Divide'},
		['*']   = {function(a, b) return a * b end,   '_mul', 'Multiply'},
		['^']   = {function(a, b) return a ^ b end,   '_pow', 'Power'},
		['..']  = {function(a, b) return a .. b end,  '__concat', 'Concatinate'},
		['==']  = {function(a, b) return a == b end,  '_eq', 'Equals'},
		['<']   = {function(a, b) return a < b end,   '_lt', 'LessThan'},
		['<=']  = {function(a, b) return a <= b end,  '_le', 'LessThanEqual'},
		['~=']  = {function(a, b) return a ~= b end,  '', 'NotEqual'},
		['>']   = {function(a, b) return a > b end,   '', 'GreaterThan'},
		['>=']  = {function(a, b) return a >= b end,  '', 'GreaterThanEqual'},
		['and'] = {function(a, b) return a and b end, '', 'And'},
		['or']  = {function(a, b) return a or b end,  '', 'Or'},
	}

	local unOp = {
		['-']   = {function(a) return -a end,    '_unm', 'Minus'},
		['not'] = {function(a) return not a end, '', 'Not'},
		['#']   = {function(a) return #a end,    '_len', 'Length'},
	}

	for operation, actions in pairs(binOp) do
		local func, meta, name = unpack(actions)
		if meta ~= '' then
			NodeMeta[meta] = function(a, b) return a[name](a, b) end
		end

		Node[name] = function(a, b) return Node.Create(func(a:Extract(), b:Extract())) end
		binOpMappings[operation] = name
	end

	for operation, actions in pairs(unOp) do
		local func, meta, name = unpack(actions)
		if meta ~= '' then
			NodeMeta[meta] = function(a) return a[name](a) end
		end

		Node[name] = function(a) return Node.Create(func(a:Extract())) end
		unOpMappings[operation] = name
	end
end

function Node.Create(value)
	local nodeType = type(value)
	local node = nodeMappings[nodeType]
	if node then return node:New(value) end

	error("Cannot create node from type " .. nodeType)
end

function Node.Factory(name, params)
	return setmetatable(nodeMappings[name] or Node, getmetatable(self))
end

function Node:New(...)
	local object = setmetatable({}, getmetatable(self))
	return object:Init(...) or object
end

--- Convert the value to a lua value
function Node:Extract() error("Cannot extract node", 2) end

--- Is an expression true, false or neither
-- @treturn number 0 for false, 1 for true, -1 for unknown
function Node:ToBool() return -1 end

--- Simplify the vale
function Node:Simplify()
	local fields = self.Fields
	if fields then return Simplify(self, fields) end
	return self
end

-- REGION Expressions
	local Number = Subclass({AstType = 'NumberExpr'})
	nodeMappings.number = Number

	function Number:Extract() return self.Value.Data end
	function Number:ToBool() return 1 end
	function Number:Init(value)
		local token = {
			Type = 'Number',
			Data = value,
		}
		self.Value = token
		self.Tokens = {token}
	end

	local String = Subclass({AstType = 'StringExpr'})
	nodeMappings.string = String

	function String:Extract() return self.Value.Data end
	function String:ToBool() return 1 end
	function String:Init(value)
		local token = {
			Type = 'String',
			Data = value,
		}
		self.Value = token
		self.Tokens = {token}
	end

	local Boolean = Subclass({AstType = 'BooleanExpr'})
	nodeMappings.boolean = Boolean

	function Boolean:Extract() return self.Value end
	function Boolean:ToBool() return self.Value and 1 or 0 end
	function Boolean:Init(value)
		self.Value = value
		self.Tokens = {{
			Type = 'boolean',
			Value = value and 'true' or 'false',
		}}
	end

	local Nil = Subclass({AstType = 'NilExpr'})
	nodeMappings.nil = Nil

	function Nil:Extract() return nil end
	function Nil:ToBool() return 0 end
	function Nil:Init()
		self.Tokens = {{Type = 'Keyword', Data = 'nil'}}
	end

	local BinOp = Subclass({AstType = 'BinopExpr'})
	function BinOp:Simplify()
		local sucess, result = pcall(self[binOpMappings[self.Op]], self.Lhs:Simplify(), self.Rhs:Simplify())
		if sucess then return result end
		return self
	end

	local Unop = Subclass({AstType = 'UnopExpr'})
	function Unop:Simplify()
		local sucess, result = pcall(self[unOpMappings[self.Op]], self.Rhs:Simplify())
		if sucess then return result end
		return self
	end

	local Parentheses = Subclass({AstType = 'Parentheses'})
	function Parentheses:Simplify() return self.Inner:Simplify() end

	local CallExpr = Subclass({AstType = 'CallExpr', Fields = {'Base', 'Arguments'}})
	local TableCallExpr = Subclass({AstType = 'TableCallExpr', Fields = {'Base', 'Arguments'}})

	local IndexExpr = Subclass({AstType = 'IndexExpr', Fields = {'Base', 'Index'}})
	local MemberExpr = Subclass({AstType = 'MemberExpr', Fields = {'Base', 'Indexer'}}) -- Check

	local Function = Subclass({AstType = 'Function', Fields = {'Body'}})

	local ConstructorExpr = Subclass({AstType = 'ConstructorExpr'})
	function ConstructorExpr:ToBool() return 1 end
	function ConstructorExpr:Simplify()
		local entries
		for i, entry in ipairs(entries) do
			entry.Key = entry.Key:Simplify()
			entry.Value = entry.Value:Simplify()
		end
	end
-- ENDREGION

-- REGION Statements
	-- Include LHS for things like a[23+34]
	local AssignmentStatement = Subclass({AstType = 'AssignmentStatement', Fields = {'Lhs', 'Rhs'}})
	local CallStatement = Subclass({AstType = 'CallStatement', Fields = {'Expression'}})
	local LocalStatement = Subclass({AstType = 'LocalStatement', Fields = {'InitList'}})

	local IfStatement = Subclass({AstType = 'IfStatement'})
	function IfStatement:Simplify()
		local condition = self.Clauses[1].Condition:Simplify()
		local result = condition:ToBool()

		if result == 1 then
			local body = self.Clauses[1].Body:Simplify()

			-- If empty body then return nil
			if #body.Body == 0 then return end
			return Node.Factory("DoStatement", {Body = body})
		end
		self.Clauses[1].Condition = condition
		--- @todo Add other clauses

		return self
	end

	local WhileStatement = Subclass({AstType = 'WhileStatement'})
	function WhileStatement:Simplify()
		local condition = self.Condition:Simplify()
		local result = condition:ToBool()

		if result == 0 then
			return
		end
		-- We can't remove a `while true end` loop, even if empty
		self.Body = self.Body:Simplify()
		self.Condition = condition
		return self
	end

	local DoStatement = Subclass({AstType = 'DoStatement', Fields = {'Body'}})
	local ReturnStatement = Subclass({AstType = 'ReturnStatement', Fields = {'Arguments'}})

	local RepeatStatement = Subclass({AstType = 'RepeatStatement'})
	function RepeatStatement:Simplify()
		local condition = self.Condition:Simplify()
		local result = condition:ToBool()

		local body = SimplifyStatementList(node.Body)
		if result == 0 then
			if #body.Body == 0 then return end
			return Node.Factory('DoStatement', {Body = body})
		end
		-- We can't remove a `while true end` loop, even if empty
		self.Body = body
		self.Condition = condition
		return self
	end

	local Function = Subclass({AstType = 'Function', Fields = {'Body'}})
	local GenericForStatement = Subclass({AstType = 'GenericForStatement', Fields = {'Body', 'Generators'}})

	local NumericForStatement = Subclass({AstType = 'NumericForStatement'})
	function NumericForStatement:Simplify()
		self.Start = self.Start:Simplify()
		self.End = self.End:Simplify()

		local step = self.Step
		if step then
			step = step:Simplify()
			self.Step = step
			if step.AstType == "NumberExpr" then
				numStep = step:Extract()
				if numStep == 1 then self.Step = nil end
			else
				numStep = nil
			end
		end

		local body = self.Body:Simplify()
		if #body.Body == 0 then return end

		self.Body = body
		return self
	end

	local Statlist = Subclass({AstType = 'Statlist', Fields = {'Body'}})
-- ENDREGION