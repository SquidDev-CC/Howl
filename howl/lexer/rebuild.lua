--- Rebuild source code from an AST
-- Does not preserve whitespace
-- @module howl.lexer.rebuild

local constants = require "howl.lexer.constants"
local parse = require "howl.lexer.parse"
local platform = require "howl.platform"

local lowerChars = constants.LowerChars
local upperChars = constants.UpperChars
local digits = constants.Digits
local symbols = constants.Symbols

--- Join two statements together
-- @tparam string left The left statement
-- @tparam string right The right statement
-- @treturn string|nil The separator, or nil
local function get_separator(left, right)
	local left_end, right_start = left:sub(-1, -1), right:sub(1, 1)
	if left_end:find("[%w_]") and right_start:find("[%w_]") then return " " end
	return nil
end

--- Returns the minified version of an AST. Operations which are performed:
--  - All comments and whitespace are ignored
--  - All local variables are renamed
-- @tparam Node ast The AST tree
-- @treturn string The minified string
-- @todo Ability to control minification level
-- @todo Convert to a buffer
local function minify(ast)
	local formatStatlist, formatExpr

	local out_buf, out_n, line_len = {}, 0, 0
	local function append(str)
		if type(str) ~= "string" then error("expected string") end

		local prev = out_buf[out_n]
		if prev then
			local sep = get_separator(prev, str)
			if sep then
				out_buf[out_n + 1], out_n = sep, out_n + 1
				line_len = line_len + #sep
			end
		end

		if line_len > 80 and line_len + #str > 120 and str:sub(1,1) ~= "(" then
			out_buf[out_n + 1], out_n = "\n", out_n + 1
			line_len = 0
		end

		out_buf[out_n + 1], out_n = str, out_n + 1
		line_len = line_len + #str
	end

	formatExpr = function(expr, precedence)
		precedence = precedence or 0
		if expr.AstType == 'VarExpr' then
			if expr.Variable then
				append(expr.Variable.Name)
			else
				append(expr.Name)
			end

		elseif expr.AstType == 'NumberExpr' then
			append(expr.Value.Data)

		elseif expr.AstType == 'StringExpr' then
			append(expr.Value.Data)

		elseif expr.AstType == 'BooleanExpr' then
			append(tostring(expr.Value))

		elseif expr.AstType == 'NilExpr' then
			append("nil")

		elseif expr.AstType == 'BinopExpr' then
			local currentPrecedence = expr.OperatorPrecedence
			if currentPrecedence < precedence then
				append(string.rep('(', expr.ParenCount or 0))
			end

			formatExpr(expr.Lhs, currentPrecedence)
			append(expr.Op)
			formatExpr(expr.Rhs)
			if expr.Op == '^' or expr.Op == '..' then
				currentPrecedence = currentPrecedence - 1
			end

			if currentPrecedence < precedence then
				append(string.rep(')', expr.ParenCount or 0))
			end
		elseif expr.AstType == 'UnopExpr' then
			append(expr.Op)
			formatExpr(expr.Rhs)

		elseif expr.AstType == 'DotsExpr' then
			append("...")

		elseif expr.AstType == 'CallExpr' then
			formatExpr(expr.Base)
			append("(")
			for i = 1, #expr.Arguments do
				formatExpr(expr.Arguments[i])
				if i ~= #expr.Arguments then append(",") end
			end
			append(")")

		elseif expr.AstType == 'TableCallExpr' then
			formatExpr(expr.Base)
			formatExpr(expr.Arguments[1])

		elseif expr.AstType == 'StringCallExpr' then
			formatExpr(expr.Base)
			append(expr.Arguments[1].Data)

		elseif expr.AstType == 'IndexExpr' then
			formatExpr(expr.Base)
			append("[")
			formatExpr(expr.Index)
			append("]")

		elseif expr.AstType == 'MemberExpr' then
			formatExpr(expr.Base)
			append(expr.Indexer)
			append(expr.Ident.Data)

		elseif expr.AstType == 'Function' then
			expr.Scope:ObfuscateLocals()
			append("function(")
			if #expr.Arguments > 0 then
				for i = 1, #expr.Arguments do
					append(expr.Arguments[i].Name)
					if i ~= #expr.Arguments then
						append(",")
					elseif expr.VarArg then
						append(",...")
					end
				end
			elseif expr.VarArg then
				append("...")
			end
			append(")")
			formatStatlist(expr.Body)
			append("end")

		elseif expr.AstType == 'ConstructorExpr' then
			append("{")
			for i = 1, #expr.EntryList do
				local entry = expr.EntryList[i]
				if entry.Type == 'Key' then
					append("[")
					formatExpr(entry.Key)
					append("]=")
					formatExpr(entry.Value)
				elseif entry.Type == 'Value' then
					formatExpr(entry.Value)
				elseif entry.Type == 'KeyString' then
					append(entry.Key)
					append("=")
					formatExpr(entry.Value)
				end
				if i ~= #expr.EntryList then
					append(",")
				end
			end
			append("}")

		elseif expr.AstType == 'Parentheses' then
			append("(")
			formatExpr(expr.Inner)
			append(")")
		end
	end

	local formatStatement = function(statement)
		if statement.AstType == 'AssignmentStatement' then
			for i = 1, #statement.Lhs do
				formatExpr(statement.Lhs[i])
				if i ~= #statement.Lhs then append(",") end
			end
			if #statement.Rhs > 0 then
				append("=")
				for i = 1, #statement.Rhs do
					formatExpr(statement.Rhs[i])
					if i ~= #statement.Rhs then append(",") end
				end
			end

		elseif statement.AstType == 'CallStatement' then
			formatExpr(statement.Expression)

		elseif statement.AstType == 'LocalStatement' then
			append("local ")
			for i = 1, #statement.LocalList do
				append(statement.LocalList[i].Name)
				if i ~= #statement.LocalList then
					append(",")
				end
			end
			if #statement.InitList > 0 then
				append("=")
				for i = 1, #statement.InitList do
					formatExpr(statement.InitList[i])
					if i ~= #statement.InitList then append(",") end
				end
			end

		elseif statement.AstType == 'IfStatement' then
			append("if")
			formatExpr(statement.Clauses[1].Condition)
			append("then")
			formatStatlist(statement.Clauses[1].Body)
			for i = 2, #statement.Clauses do
				local st = statement.Clauses[i]
				if st.Condition then
					append("elseif")
					formatExpr(st.Condition)
					append("then")
				else
					append("else")
				end
				formatStatlist(st.Body)
			end
			append("end")

		elseif statement.AstType == 'WhileStatement' then
			append("while")
			formatExpr(statement.Condition)
			append("do")
			formatStatlist(statement.Body)
			append("end")

		elseif statement.AstType == 'DoStatement' then
			append("do")
			formatStatlist(statement.Body)
			append("end")

		elseif statement.AstType == 'ReturnStatement' then
			append("return")
			for i = 1, #statement.Arguments do
				formatExpr(statement.Arguments[i])
				if i ~= #statement.Arguments then append(",") end
			end

		elseif statement.AstType == 'BreakStatement' then
			append("break")

		elseif statement.AstType == 'RepeatStatement' then
			append("repeat")
			formatStatlist(statement.Body)
			append("until")
			formatExpr(statement.Condition)

		elseif statement.AstType == 'Function' then
			statement.Scope:ObfuscateLocals()
			if statement.IsLocal then
				append("local")
			end
			append("function ")
			if statement.IsLocal then
				append(statement.Name.Name)
			else
				formatExpr(statement.Name)
			end
			append("(")
			if #statement.Arguments > 0 then
				for i = 1, #statement.Arguments do
					append(statement.Arguments[i].Name)
					if i ~= #statement.Arguments then
						append(",")
					elseif statement.VarArg then
						append(",...")
					end
				end
			elseif statement.VarArg then
				append("...")
			end
			append(")")
			formatStatlist(statement.Body)
			append("end")

		elseif statement.AstType == 'GenericForStatement' then
			statement.Scope:ObfuscateLocals()
			append("for")
			for i = 1, #statement.VariableList do
				append(statement.VariableList[i].Name)
				if i ~= #statement.VariableList then append(",") end
			end
			append("in")
			for i = 1, #statement.Generators do
				formatExpr(statement.Generators[i])
				if i ~= #statement.Generators then append(",") end
			end
			append("do")
			formatStatlist(statement.Body)
			append("end")

		elseif statement.AstType == 'NumericForStatement' then
			statement.Scope:ObfuscateLocals()
			append("for")
			append(statement.Variable.Name)
			append("=")
			formatExpr(statement.Start)
			append(",")
			formatExpr(statement.End)
			if statement.Step then
				append(",")
				formatExpr(statement.Step)
			end
			append("do")
			formatStatlist(statement.Body)
			append("end")
		elseif statement.AstType == 'LabelStatement' then
			append("::")
			append(statement.Label)
			append("::")
		elseif statement.AstType == 'GotoStatement' then
			append("goto")
			append(statement.Label)
		elseif statement.AstType == 'Comment' then
			-- ignore
		elseif statement.AstType == 'Eof' then
			-- ignore
		else
			error("Unknown AST Type: " .. statement.AstType)
		end
	end

	formatStatlist = function(statList)
		statList.Scope:ObfuscateLocals()
		for _, stat in pairs(statList.Body) do
			formatStatement(stat)
		end
	end

	formatStatlist(ast)
	return table.concat(out_buf)
end

--- Minify a string
-- @tparam string input The input string
-- @treturn string The minifyied string
local function minifyString(input)
	local lex = parse.LexLua(input)
	platform.refreshYield()

	local tree = parse.ParseLua(lex)
	platform.refreshYield()

	local min = minify(tree)
	platform.refreshYield()
	return min
end

--- Minify a file
-- @tparam string cd Current directory
-- @tparam string inputFile File to read from
-- @tparam string outputFile File to write to (Defaults to inputFile)
local function minifyFile(cd, inputFile, outputFile)
	outputFile = outputFile or inputFile

	local oldContents = platform.fs.read(platform.fs.combine(cd, inputFile))
	local newContents = minifyString(oldContents)

	platform.fs.write(platform.fs.combine(cd, outputFile), newContents)
	return #oldContents, #newContents
end

--- @export
return {
	minify = minify,
	minifyString = minifyString,
	minifyFile = minifyFile,
}
