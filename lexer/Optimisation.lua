--- Optimises some elements out
-- @module lexer.Optimisation

local createLookup = Utils.CreateLookup
local extractable = createLookup {

}

local binOp = {
	['+']   = function(a, b) return a + b end,
	['-']   = function(a, b) return a - b end,
	['%']   = function(a, b) return a % b end,
	['/']   = function(a, b) return a / b end,
	['*']   = function(a, b) return a * b end,
	['^']   = function(a, b) return a ^ b end,
	['..']  = function(a, b) return a .. b end,
	['==']  = function(a, b) return a == b end,
	['<']   = function(a, b) return a < b end,
	['<=']  = function(a, b) return a <= b end,
	['~=']  = function(a, b) return a ~= b end,
	['>']   = function(a, b) return a > b end,
	['>=']  = function(a, b) return a >= b end,
	['and'] = function(a, b) return a and b end,
	['or']  = function(a, b) return a or b end,
}

local unOp = {
	['-']   = function(a) return -a end,
	['not'] = function(a) return not a end,
	['#']   = function(a) return #a end,
}

local RebuildNode(value)
	local resType = type(result)
	if resType == "nil" then
		return {
			AstType = 'NilExpr',
			Tokens  = {{Type = 'Keyword', Data = 'nil'}},
		}
	elseif resType == "string" or resType == "number" then
		resType = (resType:gsub("^%l", string.upper))
		local token = {
			Type = resType,
			Data = result,
		}
		return {
			AstType = resType .. "Expr",
			Value   = token,
			Tokens  = {token},
		}
	elseif resType == "boolean" then
		return {
			AstType = 'BooleanExpr',
			Value = result,
			Tokens = {
				Type = 'Boolean',
				Value = result,
			},
		}
	else
		error("Cannot get the value of this node")
	end
end

local function ExtractExpression(node)
	local nodeType = node.AstType

	if nodeType == 'NumberExpr' or nodeType == 'StringExpr' then
		return node.Value.Data
	elseif nodeType == 	'BooleanExpr' then
		return node.Value
	elseif nodeType == "BinopExpr" then
		return binOp[node.Op](ExtractExpression(node.Lhs), ExtractExpression(node.Rhs))
	elseif nodeType == "UnopExpr" then
		return unOps[node.Op](ExtractExpression(node.Rhs))
	elseif nodeType == "Parentheses" then
		return ExtractExpression(node.Inner)
	elseif nodeType == "NilExpr" then
		return nil
	else
		error("Cannot get the value of " .. nodeType)
	end
end

local function

local SimplifyExpression
function SimplifyExpression(node)
	local nodeType = node.AstType

	if nodeType == 'NumberExpr' or nodeType == 'StringExpr' then
		return node.Value.Data
	elseif nodeType == 	'BooleanExpr' then
		return node.Value
	elseif nodeType == "BinopExpr" then
		return binOp[node.Op](SimplifyExpression(node.Lhs), SimplifyExpression(node.Rhs))
	elseif nodeType == "UnopExpr" then
		return unOps[node.Op](SimplifyExpression(node.Rhs))
	elseif nodeType == "Parentheses" then
		return SimplifyExpression(node.Inner)
	elseif nodeType == "NilExpr" then
		return nil
	elseif nodeType == 'CallExpr' then
		node.Base = TrySimplifyExpression(node.Base)
		for i = 1, #node.Arguments do
			node.Arguments[i] = TrySimplifyExpression(node.Arguments[i])
		end
	elseif nodeType == 'TableCallExpr' then
		node.Base = TrySimplifyExpression(node.Base)
		node.Arguments[1] = TrySimplifyExpression(node.Arguments[1])
	elseif nodeType == 'StringCallExpr' then
		node.Base = TrySimplifyExpression(node.Base)
		node.Arguments[1].Data = TrySimplifyExpression(node.Arguments[1].Data)
	elseif nodeType == 'IndexExpr' then

	else
		error("Cannot find type " .. nodeType)
	end
end

local function TrySimplifyExpression(node)
	local success, result = pcall(SimplifyExpression, node)
	if success then
		local resType = type(result)
		if resType == "nil" then
			return {
				AstType = 'NilExpr',
				Tokens  = {{Type = 'Keyword', Data = 'nil'}},
			}
		elseif resType == "string" or resType == "number" then
			resType = (resType:gsub("^%l", string.upper))
			local token = {
				Type = resType,
				Data = result,
			}
			return {
				AstType = resType .. "Expr",
				Value   = token,
				Tokens  = {token},
			}
		elseif resType == "boolean" then
			return {
				AstType = 'BooleanExpr',
				Value = result,
				Tokens = {
					Type = 'Boolean',
					Value = result,
				},
			}
		elseif resType == "table" and result.AstType ~= nil then
			return result
		end
	else
		printError(result)
	end
	return node
end

--- Is an expression true, false or neither
-- @treturn number 0 for false, 1 for true, -1 for unknown
local function ExpressionToBoolean(node)
	local nodeType = node.AstType
	if nodeType == "BooleanExpr" then
		return node.Value and 1 or 0
	elseif nodeType == "NilExpr" then
		return 0
	elseif nodeType == "StringExpr" or node.AstType == "NumberExpr" then
		return 1
	end
	return -1
end

local SimplifyStatementList
local function SimplifyStatement(node)
	local nodeType = node.AstType

	if nodeType == 'AssignmentStatement' then
		if #node.Rhs > 0 then
			for i = 1, #node.Rhs do
				node.Rhs[i] = TrySimplifyExpression(node.Rhs[i])
			end
		end
		return node
	elseif nodeType == 'CallStatement' then
		node.Expression = TrySimplifyExpression(node.Expression)
		return node
	elseif nodeType == 'LocalStatement' then
		if #node.InitList > 0 then
			for i = 1, #node.InitList do
				node.InitList[i] = TrySimplifyExpression(node.InitList[i])
			end
		end
		return node
	elseif nodeType == 'IfStatement' then
		local newClauses = {}

		local condition = TrySimplifyExpression(node.Clauses[1].Condition)
		local result = ExpressionToBoolean(condition)


		-- Handle absolute truth.(Doesn't print out 42)
		if result == 1 then
			local body = SimplifyStatementList(node.Clauses[1].Body)

			-- Simplify body
			if #body.Body == 0 then return end

			return {
				AstType = "DoStatement",
				Body = SimplifyStatementList(body),
			}
		end
		--[[
		for i = 2, #node.Clauses do
			local st = node.Clauses[i]
			if st.Condition then
				out = joinStatements(out, "elseif")
				out = joinStatements(out, formatExpr(st.Condition))
				out = joinStatements(out, "then")
			else
				out = joinStatements(out, "else")
			end
			out = joinStatements(out, SimplifyStatementList(st.Body))
		end]]
	elseif nodeType == 'WhileStatement' then
		local condition = TrySimplifyExpression(node.Condition)
		local result = ExpressionToBoolean(condition)

		if result == 0 then
			return
		elseif result == 1 then
			local body = SimplifyStatementList(node.Body)
			-- Simplify body
			if #body.Body == 0 then return end

			return {
				AstType = "DoStatement",
				Body = body,
			}
		else
			node.Condition = condition
			node.Body = SimplifyStatementList(node.Body)
			return node
		end
	elseif nodeType == 'DoStatement' then
		local body = SimplifyStatementList(node.Body)
		if #body.Body == 0 then return end
		node.Body = body

		return node
	elseif nodeType == 'ReturnStatement' then
		out = "return"
		for i = 1, #node.Arguments do
			node.Arguments[i] = TrySimplifyExpression(node.Arguments[i])
		end
		return node
	elseif nodeType == 'BreakStatement' then
		return node
	elseif nodeType == 'RepeatStatement' then
		local condition = TrySimplifyExpression(node.Condition)
		local result = ExpressionToBoolean(condition)

		local body = SimplifyStatementList(node.Body)
		if result == 0 then -- If the statement is always false wrap it in a do statement
			-- Simplify body
			if #body.Body == 0 then return end

			return {
				AstType = "DoStatement",
				Body = body,
			}
		else
			node.Condition = condition
			node.Body = body
			return node
		end
	elseif nodeType == 'Function' then
		node.Body = SimplifyStatementList(node.Body)
		return node
	elseif nodeType == 'GenericForStatement' then
		out = "for "
		for i = 1, #node.Generators do
			node.Generators[i] = TrySimplifyExpression(node.Generators[i])
		end
		node.Body = SimplifyStatementList(node.Body)
		return node
	elseif nodeType == 'NumericForStatement' then
		node.Start = TrySimplifyExpression(node.Start)
		node.End = TrySimplifyExpression(node.End)
		node.Step = TrySimplifyExpression(node.Step)
		local body = SimplifyStatementList(node.Body)

		if #body.Body == 0 then return end
		node.Body = body

		return node
	elseif nodeType == 'LabelStatement' then
		out = "::" .. node.Label .. "::"
	elseif nodeType == 'GotoStatement' then
		out = "goto " .. node.Label
	elseif nodeType == 'Comment' then
		-- ignore
	elseif nodeType == 'Eof' then
		-- ignore
	else
		error("Unknown AST Type: " .. nodeType)
	end

	return node
end

function SimplifyStatementList(statList)
	local newBody = {}
	local insert = table.insert
	for _, stat in pairs(statList.Body) do
		insert(newBody, SimplifyStatement(stat))
	end
	statList.Body = newBody

	return statList
end

return function(ast)

	return SimplifyStatementList(ast)
end