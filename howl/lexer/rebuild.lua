--- Rebuild source code from an AST
-- Does not preserve whitespace
-- @module howl.lexer.rebuild

local Constants = require "howl.lexer.constants"
local Parse = require "howl.lexer.parse"
local platform = require "howl.platform"

local lowerChars = Constants.LowerChars
local upperChars = Constants.UpperChars
local digits = Constants.Digits
local symbols = Constants.Symbols

--- Join two statements together
-- @tparam string left The left statement
-- @tparam string right The right statement
-- @tparam string sep The string used to separate the characters
-- @treturn string The joined strings
local function JoinStatements(left, right, sep)
	sep = sep or ' '
	local leftEnd, rightStart = left:sub(-1, -1), right:sub(1, 1)
	if upperChars[leftEnd] or lowerChars[leftEnd] or leftEnd == '_' then
		if not (rightStart == '_' or upperChars[rightStart] or lowerChars[rightStart] or digits[rightStart]) then
			--rightStart is left symbol, can join without seperation
			return left .. right
		else
			return left .. sep .. right
		end
	elseif digits[leftEnd] then
		if rightStart == '(' then
			--can join statements directly
			return left .. right
		elseif symbols[rightStart] then
			return left .. right
		else
			return left .. sep .. right
		end
	elseif leftEnd == '' then
		return left .. right
	else
		if rightStart == '(' then
			--don't want to accidentally call last statement, can't join directly
			return left .. sep .. right
		else
			return left .. right
		end
	end
end

--- Returns the minified version of an AST. Operations which are performed:
--  - All comments and whitespace are ignored
--  - All local variables are renamed
-- @tparam Node ast The AST tree
-- @treturn string The minified string
-- @todo Ability to control minification level
local function Minify(ast)
	local formatStatlist, formatExpr
	local count = 0
	local function joinStatements(left, right, sep)
		if count > 150 then
			count = 0
			return left .. "\n" .. right
		else
			return JoinStatements(left, right, sep)
		end
	end

	formatExpr = function(expr, precedence)
		local precedence = precedence or 0
		local currentPrecedence = 0
		local skipParens = false
		local out = ""
		if expr.AstType == 'VarExpr' then
			if expr.Variable then
				out = out .. expr.Variable.Name
			else
				out = out .. expr.Name
			end

		elseif expr.AstType == 'NumberExpr' then
			out = out .. expr.Value.Data

		elseif expr.AstType == 'StringExpr' then
			out = out .. expr.Value.Data

		elseif expr.AstType == 'BooleanExpr' then
			out = out .. tostring(expr.Value)

		elseif expr.AstType == 'NilExpr' then
			out = joinStatements(out, "nil")

		elseif expr.AstType == 'BinopExpr' then
			currentPrecedence = expr.OperatorPrecedence
			out = joinStatements(out, formatExpr(expr.Lhs, currentPrecedence))
			out = joinStatements(out, expr.Op)
			out = joinStatements(out, formatExpr(expr.Rhs))
			if expr.Op == '^' or expr.Op == '..' then
				currentPrecedence = currentPrecedence - 1
			end

			if currentPrecedence < precedence then
				skipParens = false
			else
				skipParens = true
			end
		elseif expr.AstType == 'UnopExpr' then
			out = joinStatements(out, expr.Op)
			out = joinStatements(out, formatExpr(expr.Rhs))

		elseif expr.AstType == 'DotsExpr' then
			out = out .. "..."

		elseif expr.AstType == 'CallExpr' then
			out = out .. formatExpr(expr.Base)
			out = out .. "("
			for i = 1, #expr.Arguments do
				out = out .. formatExpr(expr.Arguments[i])
				if i ~= #expr.Arguments then
					out = out .. ","
				end
			end
			out = out .. ")"

		elseif expr.AstType == 'TableCallExpr' then
			out = out .. formatExpr(expr.Base)
			out = out .. formatExpr(expr.Arguments[1])

		elseif expr.AstType == 'StringCallExpr' then
			out = out .. formatExpr(expr.Base)
			out = out .. expr.Arguments[1].Data

		elseif expr.AstType == 'IndexExpr' then
			out = out .. formatExpr(expr.Base) .. "[" .. formatExpr(expr.Index) .. "]"

		elseif expr.AstType == 'MemberExpr' then
			out = out .. formatExpr(expr.Base) .. expr.Indexer .. expr.Ident.Data

		elseif expr.AstType == 'Function' then
			expr.Scope:ObfuscateLocals()
			out = out .. "function("
			if #expr.Arguments > 0 then
				for i = 1, #expr.Arguments do
					out = out .. expr.Arguments[i].Name
					if i ~= #expr.Arguments then
						out = out .. ","
					elseif expr.VarArg then
						out = out .. ",..."
					end
				end
			elseif expr.VarArg then
				out = out .. "..."
			end
			out = out .. ")"
			out = joinStatements(out, formatStatlist(expr.Body))
			out = joinStatements(out, "end")

		elseif expr.AstType == 'ConstructorExpr' then
			out = out .. "{"
			for i = 1, #expr.EntryList do
				local entry = expr.EntryList[i]
				if entry.Type == 'Key' then
					out = out .. "[" .. formatExpr(entry.Key) .. "]=" .. formatExpr(entry.Value)
				elseif entry.Type == 'Value' then
					out = out .. formatExpr(entry.Value)
				elseif entry.Type == 'KeyString' then
					out = out .. entry.Key .. "=" .. formatExpr(entry.Value)
				end
				if i ~= #expr.EntryList then
					out = out .. ","
				end
			end
			out = out .. "}"

		elseif expr.AstType == 'Parentheses' then
			out = out .. "(" .. formatExpr(expr.Inner) .. ")"
		end
		if not skipParens then
			out = string.rep('(', expr.ParenCount or 0) .. out
			out = out .. string.rep(')', expr.ParenCount or 0)
		end
		count = count + #out
		return out
	end

	local formatStatement = function(statement)
		local out = ''
		if statement.AstType == 'AssignmentStatement' then
			for i = 1, #statement.Lhs do
				out = out .. formatExpr(statement.Lhs[i])
				if i ~= #statement.Lhs then
					out = out .. ","
				end
			end
			if #statement.Rhs > 0 then
				out = out .. "="
				for i = 1, #statement.Rhs do
					out = out .. formatExpr(statement.Rhs[i])
					if i ~= #statement.Rhs then
						out = out .. ","
					end
				end
			end

		elseif statement.AstType == 'CallStatement' then
			out = formatExpr(statement.Expression)

		elseif statement.AstType == 'LocalStatement' then
			out = out .. "local "
			for i = 1, #statement.LocalList do
				out = out .. statement.LocalList[i].Name
				if i ~= #statement.LocalList then
					out = out .. ","
				end
			end
			if #statement.InitList > 0 then
				out = out .. "="
				for i = 1, #statement.InitList do
					out = out .. formatExpr(statement.InitList[i])
					if i ~= #statement.InitList then
						out = out .. ","
					end
				end
			end

		elseif statement.AstType == 'IfStatement' then
			out = joinStatements("if", formatExpr(statement.Clauses[1].Condition))
			out = joinStatements(out, "then")
			out = joinStatements(out, formatStatlist(statement.Clauses[1].Body))
			for i = 2, #statement.Clauses do
				local st = statement.Clauses[i]
				if st.Condition then
					out = joinStatements(out, "elseif")
					out = joinStatements(out, formatExpr(st.Condition))
					out = joinStatements(out, "then")
				else
					out = joinStatements(out, "else")
				end
				out = joinStatements(out, formatStatlist(st.Body))
			end
			out = joinStatements(out, "end")

		elseif statement.AstType == 'WhileStatement' then
			out = joinStatements("while", formatExpr(statement.Condition))
			out = joinStatements(out, "do")
			out = joinStatements(out, formatStatlist(statement.Body))
			out = joinStatements(out, "end")

		elseif statement.AstType == 'DoStatement' then
			out = joinStatements(out, "do")
			out = joinStatements(out, formatStatlist(statement.Body))
			out = joinStatements(out, "end")

		elseif statement.AstType == 'ReturnStatement' then
			out = "return"
			for i = 1, #statement.Arguments do
				out = joinStatements(out, formatExpr(statement.Arguments[i]))
				if i ~= #statement.Arguments then
					out = out .. ","
				end
			end

		elseif statement.AstType == 'BreakStatement' then
			out = "break"

		elseif statement.AstType == 'RepeatStatement' then
			out = "repeat"
			out = joinStatements(out, formatStatlist(statement.Body))
			out = joinStatements(out, "until")
			out = joinStatements(out, formatExpr(statement.Condition))

		elseif statement.AstType == 'Function' then
			statement.Scope:ObfuscateLocals()
			if statement.IsLocal then
				out = "local"
			end
			out = joinStatements(out, "function ")
			if statement.IsLocal then
				out = out .. statement.Name.Name
			else
				out = out .. formatExpr(statement.Name)
			end
			out = out .. "("
			if #statement.Arguments > 0 then
				for i = 1, #statement.Arguments do
					out = out .. statement.Arguments[i].Name
					if i ~= #statement.Arguments then
						out = out .. ","
					elseif statement.VarArg then
						out = out .. ",..."
					end
				end
			elseif statement.VarArg then
				out = out .. "..."
			end
			out = out .. ")"
			out = joinStatements(out, formatStatlist(statement.Body))
			out = joinStatements(out, "end")

		elseif statement.AstType == 'GenericForStatement' then
			statement.Scope:ObfuscateLocals()
			out = "for "
			for i = 1, #statement.VariableList do
				out = out .. statement.VariableList[i].Name
				if i ~= #statement.VariableList then
					out = out .. ","
				end
			end
			out = out .. " in"
			for i = 1, #statement.Generators do
				out = joinStatements(out, formatExpr(statement.Generators[i]))
				if i ~= #statement.Generators then
					out = joinStatements(out, ',')
				end
			end
			out = joinStatements(out, "do")
			out = joinStatements(out, formatStatlist(statement.Body))
			out = joinStatements(out, "end")

		elseif statement.AstType == 'NumericForStatement' then
			statement.Scope:ObfuscateLocals()
			out = "for "
			out = out .. statement.Variable.Name .. "="
			out = out .. formatExpr(statement.Start) .. "," .. formatExpr(statement.End)
			if statement.Step then
				out = out .. "," .. formatExpr(statement.Step)
			end
			out = joinStatements(out, "do")
			out = joinStatements(out, formatStatlist(statement.Body))
			out = joinStatements(out, "end")
		elseif statement.AstType == 'LabelStatement' then
			out = "::" .. statement.Label .. "::"
		elseif statement.AstType == 'GotoStatement' then
			out = "goto " .. statement.Label
		elseif statement.AstType == 'Comment' then
			-- ignore
		elseif statement.AstType == 'Eof' then
			-- ignore
		else
			error("Unknown AST Type: " .. statement.AstType)
		end
		count = count + #out
		return out
	end

	formatStatlist = function(statList)
		local out = ''
		statList.Scope:ObfuscateLocals()
		for _, stat in pairs(statList.Body) do
			out = joinStatements(out, formatStatement(stat), ';')
		end
		return out
	end

	return formatStatlist(ast)
end

--- Minify a string
-- @tparam string input The input string
-- @treturn string The minifyied string
local function MinifyString(input)
	local lex = Parse.LexLua(input)
	platform.refreshYield()

	local tree = Parse.ParseLua(lex)
	platform.refreshYield()

	return Minify(tree)
end

--- Minify a file
-- @tparam string cd Current directory
-- @tparam string inputFile File to read from
-- @tparam string outputFile File to write to (Defaults to inputFile)
local function MinifyFile(cd, inputFile, outputFile)
	outputFile = outputFile or inputFile

	local contents = platform.fs.read(platform.fs.combine(cd, inputFile))

	contents = MinifyString(contents)

	platform.fs.write(platform.fs.combine(cd, outputFile))
end

--- @export
return {
	JoinStatements = JoinStatements,
	Minify = Minify,
	MinifyString = MinifyString,
	MinifyFile = MinifyFile,
}
