--- The main lua parser and lexer.
-- LexLua returns a Lua token stream, with tokens that preserve
-- all whitespace formatting information.
-- ParseLua returns an AST, internally relying on LexLua.
-- @module lexer.Parse

local createLookup = Utils.CreateLookup

local lowerChars = Constants.LowerChars
local upperChars = Constants.UpperChars
local digits = Constants.Digits
local symbols = Constants.Symbols
local hexDigits = Constants.HexDigits
local keywords = Constants.Keywords
local statListCloseKeywords = Constants.StatListCloseKeywords
local unops = Constants.UnOps
local setmeta = setmetatable

--- One token
-- @table Token
-- @tparam string Type The token type
-- @param Data Data about the token
-- @tparam string CommentType The type of comment  (Optional)
-- @tparam number Line Line number (Optional)
-- @tparam number Char Character number (Optional)
local Token = {}

--- Creates a string representation of the token
-- @treturn string The resulting string
function Token:Print()
	return "<"..(self.Type .. string.rep(' ', math.max(3, 12-#self.Type))).."  "..(self.Data or '').." >"
end

local tokenMeta = { __index = Token }

--- Create a list of @{Token|tokens} from a Lua source
-- @tparam string src Lua source code
-- @treturn TokenList The list of @{Token|tokens}
local function LexLua(src)
	--token dump
	local tokens = {}

	do -- Main bulk of the work
		--line / char / pointer tracking
		local pointer = 1
		local line = 1
		local char = 1

		--get / peek functions
		local function get()
			local c = src:sub(pointer,pointer)
			if c == '\n' then
				char = 1
				line = line + 1
			else
				char = char + 1
			end
			pointer = pointer + 1
			return c
		end
		local function peek(n)
			n = n or 0
			return src:sub(pointer+n,pointer+n)
		end
		local function consume(chars)
			local c = peek()
			for i = 1, #chars do
				if c == chars:sub(i,i) then return get() end
			end
		end

		--shared stuff
		local function generateError(err)
			error(">> :"..line..":"..char..": "..err, 0)
		end

		local function tryGetLongString()
			local start = pointer
			if peek() == '[' then
				local equalsCount = 0
				local depth = 1
				while peek(equalsCount+1) == '=' do
					equalsCount = equalsCount + 1
				end
				if peek(equalsCount+1) == '[' then
					--start parsing the string. Strip the starting bit
					for _ = 0, equalsCount+1 do get() end

					--get the contents
					local contentStart = pointer
					while true do
						--check for eof
						if peek() == '' then
							generateError("Expected `]"..string.rep('=', equalsCount).."]` near <eof>.", 3)
						end

						--check for the end
						local foundEnd = true
						if peek() == ']' then
							for i = 1, equalsCount do
								if peek(i) ~= '=' then foundEnd = false end
							end
							if peek(equalsCount+1) ~= ']' then
								foundEnd = false
							end
						else
							if peek() == '[' then
								-- is there an embedded long string?
								local embedded = true
								for i = 1, equalsCount do
									if peek(i) ~= '=' then
										embedded = false
										break
									end
								end
								if peek(equalsCount + 1) == '[' and embedded then
									-- oh look, there was
									depth = depth + 1
									for i = 1, (equalsCount + 2) do
										get()
									end
								end
							end
							foundEnd = false
						end

						if foundEnd then
							depth = depth - 1
							if depth == 0 then
								break
							else
								for i = 1, equalsCount + 2 do
									get()
								end
							end
						else
							get()
						end
					end

					--get the interior string
					local contentString = src:sub(contentStart, pointer-1)

					--found the end. Get rid of the trailing bit
					for i = 0, equalsCount+1 do get() end

					--get the exterior string
					local longString = src:sub(start, pointer-1)

					--return the stuff
					return contentString, longString
				else
					return nil
				end
			else
				return nil
			end
		end

		--main token emitting loop
		while true do
			--get leading whitespace. The leading whitespace will include any comments
			--preceding the token. This prevents the parser needing to deal with comments
			--separately.
			local leading = { }
			local leadingWhite = ''
			local longStr = false
			while true do
				local c = peek()
				if c == '#' and peek(1) == '!' and line == 1 then
					-- #! shebang for linux scripts
					get()
					get()
					leadingWhite = "#!"
					while peek() ~= '\n' and peek() ~= '' do
						leadingWhite = leadingWhite .. get()
					end

					table.insert(leading, setmeta({
						Type = 'Comment',
						CommentType = 'Shebang',
						Data = leadingWhite,
						Line = line,
						Char = char
					}, tokenMeta))
					leadingWhite = ""
				end
				if c == ' ' or c == '\t' then
					--whitespace
					--leadingWhite = leadingWhite..get()
					local c2 = get() -- ignore whitespace
					table.insert(leading, setmeta({
						Type = 'Whitespace',
						Line = line,
						Char = char,
						Data = c2
					}, tokenMeta))
				elseif c == '\n' or c == '\r' then
					local nl = get()
					if leadingWhite ~= "" then
						table.insert(leading, setmeta({
							Type = 'Comment',
							CommentType = longStr and 'LongComment' or 'Comment',
							Data = leadingWhite,
							Line = line,
							Char = char,
						}, tokenMeta))
						leadingWhite = ""
					end
					table.insert(leading, setmeta({
						Type = 'Whitespace',
						Line = line,
						Char = char,
						Data = nl,
					}, tokenMeta))
				elseif c == '-' and peek(1) == '-' then
					--comment
					get()
					get()
					leadingWhite = leadingWhite .. '--'
					local _, wholeText = tryGetLongString()
					if wholeText then
						leadingWhite = leadingWhite..wholeText
						longStr = true
					else
						while peek() ~= '\n' and peek() ~= '' do
							leadingWhite = leadingWhite..get()
						end
					end
				else
					break
				end
			end
			if leadingWhite ~= "" then
				table.insert(leading, setmeta(
				{
					Type = 'Comment',
					CommentType = longStr and 'LongComment' or 'Comment',
					Data = leadingWhite,
					Line = line,
					Char = char,
				}, tokenMeta))
			end

			--get the initial char
			local thisLine = line
			local thisChar = char
			local errorAt = ":"..line..":"..char..":> "
			local c = peek()

			--symbol to emit
			local toEmit = nil

			--branch on type
			if c == '' then
				--eof
				toEmit = { Type = 'Eof' }

			elseif upperChars[c] or lowerChars[c] or c == '_' then
				--ident or keyword
				local start = pointer
				repeat
					get()
					c = peek()
				until not (upperChars[c] or lowerChars[c] or digits[c] or c == '_')
				local dat = src:sub(start, pointer-1)
				if keywords[dat] then
					toEmit = {Type = 'Keyword', Data = dat}
				else
					toEmit = {Type = 'Ident', Data = dat}
				end

			elseif digits[c] or (peek() == '.' and digits[peek(1)]) then
				--number const
				local start = pointer
				if c == '0' and peek(1) == 'x' then
					get();get()
					while hexDigits[peek()] do get() end
					if consume('Pp') then
						consume('+-')
						while digits[peek()] do get() end
					end
				else
					while digits[peek()] do get() end
					if consume('.') then
						while digits[peek()] do get() end
					end
					if consume('Ee') then
						consume('+-')
						while digits[peek()] do get() end
					end
				end
				toEmit = {Type = 'Number', Data = src:sub(start, pointer-1)}

			elseif c == '\'' or c == '\"' then
				local start = pointer
				--string const
				local delim = get()
				local contentStart = pointer
				while true do
					local c = get()
					if c == '\\' then
						get() --get the escape char
					elseif c == delim then
						break
					elseif c == '' then
						generateError("Unfinished string near <eof>")
					end
				end
				local content = src:sub(contentStart, pointer-2)
				local constant = src:sub(start, pointer-1)
				toEmit = {Type = 'String', Data = constant, Constant = content}

			elseif c == '[' then
				local content, wholetext = tryGetLongString()
				if wholetext then
					toEmit = {Type = 'String', Data = wholetext, Constant = content}
				else
					get()
					toEmit = {Type = 'Symbol', Data = '['}
				end

			elseif consume('>=<') then
				if consume('=') then
					toEmit = {Type = 'Symbol', Data = c..'='}
				else
					toEmit = {Type = 'Symbol', Data = c}
				end

			elseif consume('~') then
				if consume('=') then
					toEmit = {Type = 'Symbol', Data = '~='}
				else
					generateError("Unexpected symbol `~` in source.", 2)
				end

			elseif consume('.') then
				if consume('.') then
					if consume('.') then
						toEmit = {Type = 'Symbol', Data = '...'}
					else
						toEmit = {Type = 'Symbol', Data = '..'}
					end
				else
					toEmit = {Type = 'Symbol', Data = '.'}
				end

			elseif consume(':') then
				if consume(':') then
					toEmit = {Type = 'Symbol', Data = '::'}
				else
					toEmit = {Type = 'Symbol', Data = ':'}
				end

			elseif symbols[c] then
				get()
				toEmit = {Type = 'Symbol', Data = c}

			else
				local contents, all = tryGetLongString()
				if contents then
					toEmit = {Type = 'String', Data = all, Constant = contents}
				else
					generateError("Unexpected Symbol `"..c.."` in source.", 2)
				end
			end

			--add the emitted symbol, after adding some common data
			toEmit.LeadingWhite = leading -- table of leading whitespace/comments

			toEmit.Line = thisLine
			toEmit.Char = thisChar
			tokens[#tokens+1] = setmeta(toEmit, tokenMeta)

			--halt after eof has been emitted
			if toEmit.Type == 'Eof' then break end
		end
	end

	--public interface:
	local tokenList = setmetatable({
		tokens = tokens,
		savedPointers = {},
		pointer = 1
	}, {__index = TokenList})

	return tokenList
end

--- Create a AST tree from a Lua Source
-- @tparam TokenList tok List of tokens from @{LexLua}
-- @treturn table The AST tree
local function ParseLua(tok)
	--- Generate an error
	-- @tparam string msg The error message
	-- @raise The produces error message
	local function GenerateError(msg)
		local err = ">> :"..tok:Peek().Line..":"..tok:Peek().Char..": "..msg.."\n"
		--find the line
		local lineNum = 0
		if type(src) == 'string' then
			for line in src:gmatch("[^\n]*\n?") do
				if line:sub(-1,-1) == '\n' then line = line:sub(1,-2) end
				lineNum = lineNum+1
				if lineNum == tok:Peek().Line then
					err = err..">> `"..line:gsub('\t','    ').."`\n"
					for i = 1, tok:Peek().Char do
						local c = line:sub(i,i)
						if c == '\t' then
							err = err..'    '
						else
							err = err..' '
						end
					end
					err = err.."   ^^^^"
					break
				end
			end
		end
		error(err)
	end

	local ParseExpr,
	      ParseStatementList,
	      ParseSimpleExpr,
	      ParsePrimaryExpr,
	      ParseSuffixedExpr

	--- Parse the function definition and its arguments
	-- @tparam Scope.Scope The current scope
	-- @tparam table tokenList. A table to fill with tokens
	-- @treturn Node A function Node
	local function ParseFunctionArgsAndBody(scope, tokenList)
		local funcScope = Scope(scope)
		if not tok:ConsumeSymbol('(', tokenList) then
			GenerateError("`(` expected.")
		end

		--arg list
		local argList = {}
		local isVarArg = false
		while not tok:ConsumeSymbol(')', tokenList) do
			if tok:Is('Ident') then
				local arg = funcScope:CreateLocal(tok:Get(tokenList).Data)
				argList[#argList+1] = arg
				if not tok:ConsumeSymbol(',', tokenList) then
					if tok:ConsumeSymbol(')', tokenList) then
						break
					else
						GenerateError("`)` expected.")
					end
				end
			elseif tok:ConsumeSymbol('...', tokenList) then
				isVarArg = true
				if not tok:ConsumeSymbol(')', tokenList) then
					GenerateError("`...` must be the last argument of a function.")
				end
				break
			else
				GenerateError("Argument name or `...` expected")
			end
		end

		--body
		local body = ParseStatementList(funcScope)

		--end
		if not tok:ConsumeKeyword('end', tokenList) then
			GenerateError("`end` expected after function body")
		end

		return {
			AstType   = 'Function',
			Scope     = funcScope,
			Arguments = argList,
			Body      = body,
			VarArg    = isVarArg,
			Tokens    = tokenList,
		}
	end

	--- Parse a simple expression
	-- @tparam Scope.Scope The current scope
	-- @treturn Node the resulting node
	function ParsePrimaryExpr(scope)
		local tokenList = {}

		if tok:ConsumeSymbol('(', tokenList) then
			local ex = ParseExpr(scope)
			if not tok:ConsumeSymbol(')', tokenList) then
				GenerateError("`)` Expected.")
			end

			return {
				AstType = 'Parentheses',
				Inner   = ex,
				Tokens  = tokenList,
			}

		elseif tok:Is('Ident') then
			local id = tok:Get(tokenList)
			local var = scope:GetLocal(id.Data)
			if not var then
				var = scope:GetGlobal(id.Data)
				if not var then
					var = scope:CreateGlobal(id.Data)
				else
					var.References = var.References + 1
				end
			else
				var.References = var.References + 1
			end

			return {
				AstType  = 'VarExpr',
				Name     = id.Data,
				Variable = var,
				Tokens   = tokenList,
			}
		else
			GenerateError("primary expression expected")
		end
	end

	--- Parse some table related expressions
	-- @tparam Scope.Scope scope The current scope
	-- @tparam boolean onlyDotColon Only allow '.' or ':' nodes
	-- @treturn Node The resulting node
	function ParseSuffixedExpr(scope, onlyDotColon)
		--base primary expression
		local prim = ParsePrimaryExpr(scope)

		while true do
			local tokenList = {}

			if tok:IsSymbol('.') or tok:IsSymbol(':') then
				local symb = tok:Get(tokenList).Data
				if not tok:Is('Ident') then
					GenerateError("<Ident> expected.")
				end
				local id = tok:Get(tokenList)

				prim = {
					AstType  = 'MemberExpr',
					Base     = prim,
					Indexer  = symb,
					Ident    = id,
					Tokens   = tokenList,
				}

			elseif not onlyDotColon and tok:ConsumeSymbol('[', tokenList) then
				local ex = ParseExpr(scope)
				if not tok:ConsumeSymbol(']', tokenList) then
					GenerateError("`]` expected.")
				end

				prim = {
					AstType  = 'IndexExpr',
					Base     = prim,
					Index    = ex,
					Tokens   = tokenList,
				}

			elseif not onlyDotColon and tok:ConsumeSymbol('(', tokenList) then
				local args = {}
				while not tok:ConsumeSymbol(')', tokenList) do
					args[#args+1] = ParseExpr(scope)
					if not tok:ConsumeSymbol(',', tokenList) then
						if tok:ConsumeSymbol(')', tokenList) then
							break
						else
							GenerateError("`)` Expected.")
						end
					end
				end

				prim = {
					AstType   = 'CallExpr',
					Base      = prim,
					Arguments = args,
					Tokens    = tokenList,
				}

			elseif not onlyDotColon and tok:Is('String') then
				--string call
				prim = {
					AstType    = 'StringCallExpr',
					Base       = prim,
					Arguments  = { tok:Get(tokenList) },
					Tokens     = tokenList,
				}

			elseif not onlyDotColon and tok:IsSymbol('{') then
				--table call
				local ex = ParseSimpleExpr(scope)
				-- FIX: ParseExpr(scope) parses the table AND and any following binary expressions.
				-- We just want the table

				prim = {
					AstType   = 'TableCallExpr',
					Base      = prim,
					Arguments = { ex },
					Tokens    = tokenList,
				}

			else
				break
			end
		end
		return prim
	end

	--- Parse a simple expression (strings, numbers, booleans, varargs)
	-- @tparam Scope.Scope scope The current scope
	-- @treturn Node The resulting node
	function ParseSimpleExpr(scope)
		local tokenList = {}

		if tok:Is('Number') then
			return {
				AstType = 'NumberExpr',
				Value   = tok:Get(tokenList),
				Tokens  = tokenList,
			}

		elseif tok:Is('String') then
			return {
				AstType = 'StringExpr',
				Value   = tok:Get(tokenList),
				Tokens  = tokenList,
			}

		elseif tok:ConsumeKeyword('nil', tokenList) then
			return {
				AstType = 'NilExpr',
				Tokens  = tokenList,
			}

		elseif tok:IsKeyword('false') or tok:IsKeyword('true') then
			return {
				AstType = 'BooleanExpr',
				Value   = (tok:Get(tokenList).Data == 'true'),
				Tokens  = tokenList,
			}

		elseif tok:ConsumeSymbol('...', tokenList) then
			return {
				AstType  = 'DotsExpr',
				Tokens   = tokenList,
			}

		elseif tok:ConsumeSymbol('{', tokenList) then
			local entryList = {}
			local v = {
				AstType = 'ConstructorExpr',
				EntryList = entryList,
				Tokens  = tokenList,
			}

			while true do
				if tok:IsSymbol('[', tokenList) then
					--key
					tok:Get(tokenList)
					local key = ParseExpr(scope)
					if not tok:ConsumeSymbol(']', tokenList) then
						GenerateError("`]` Expected")
					end
					if not tok:ConsumeSymbol('=', tokenList) then
						GenerateError("`=` Expected")
					end
					local value = ParseExpr(scope)
					entryList[#entryList+1] = {
						Type  = 'Key',
						Key   = key,
						Value = value,
					}

				elseif tok:Is('Ident') then
					--value or key
					local lookahead = tok:Peek(1)
					if lookahead.Type == 'Symbol' and lookahead.Data == '=' then
						--we are a key
						local key = tok:Get(tokenList)
						if not tok:ConsumeSymbol('=', tokenList) then
							GenerateError("`=` Expected")
						end
						local value = ParseExpr(scope)
						entryList[#entryList+1] = {
							Type  = 'KeyString',
							Key   = key.Data,
							Value = value,
						}

					else
						--we are a value
						local value = ParseExpr(scope)
						entryList[#entryList+1] = {
							Type = 'Value',
							Value = value,
						}

					end
				elseif tok:ConsumeSymbol('}', tokenList) then
					break

				else
					--value
					local value = ParseExpr(scope)
					entryList[#entryList+1] = {
						Type = 'Value',
						Value = value,
					}
				end

				if tok:ConsumeSymbol(';', tokenList) or tok:ConsumeSymbol(',', tokenList) then
					--all is good
				elseif tok:ConsumeSymbol('}', tokenList) then
					break
				else
					GenerateError("`}` or table entry Expected")
				end
			end
			return v

		elseif tok:ConsumeKeyword('function', tokenList) then
			local func = ParseFunctionArgsAndBody(scope, tokenList)

			func.IsLocal = true
			return func

		else
			return ParseSuffixedExpr(scope)
		end
	end

	local unopprio = 8
	local priority = {
		['+'] = {6,6},
		['-'] = {6,6},
		['%'] = {7,7},
		['/'] = {7,7},
		['*'] = {7,7},
		['^'] = {10,9},
		['..'] = {5,4},
		['=='] = {3,3},
		['<'] = {3,3},
		['<='] = {3,3},
		['~='] = {3,3},
		['>'] = {3,3},
		['>='] = {3,3},
		['and'] = {2,2},
		['or'] = {1,1},
	}

	--- Parse an expression
	-- @tparam Skcope.Scope scope The current scope
	-- @tparam int level Current level (Optional)
	-- @treturn Node The resulting node
	function ParseExpr(scope, level)
		level = level or 0
		--base item, possibly with unop prefix
		local exp
		if unops[tok:Peek().Data] then
			local tokenList = {}
			local op = tok:Get(tokenList).Data
			exp = ParseExpr(scope, unopprio)

			local nodeEx = {
				AstType = 'UnopExpr',
				Rhs     = exp,
				Op      = op,
				OperatorPrecedence = unopprio,
				Tokens  = tokenList,
			}

			exp = nodeEx
		else
			exp = ParseSimpleExpr(scope)
		end

		--next items in chain
		while true do
			local prio = priority[tok:Peek().Data]
			if prio and prio[1] > level then
				local tokenList = {}
				local op = tok:Get(tokenList).Data
				local rhs = ParseExpr(scope, prio[2])

				local nodeEx = {
					AstType = 'BinopExpr',
					Lhs     = exp,
					Op      = op,
					OperatorPrecedence = prio[1],
					Rhs     = rhs,
					Tokens  = tokenList,
				}

				exp = nodeEx
			else
				break
			end
		end

		return exp
	end

	--- Parse a statement (if, for, while, etc...)
	-- @tparam Scope.Scope scope The current scope
	-- @treturn Node The resulting node
	local function ParseStatement(scope)
		local stat = nil
		local tokenList = {}
		if tok:ConsumeKeyword('if', tokenList) then
			--setup
			local clauses = {}
			local nodeIfStat = {
				AstType = 'IfStatement',
				Clauses = clauses,
			}
			--clauses
			repeat
				local nodeCond = ParseExpr(scope)

				if not tok:ConsumeKeyword('then', tokenList) then
					GenerateError("`then` expected.")
				end
				local nodeBody = ParseStatementList(scope)
				clauses[#clauses+1] = {
					Condition = nodeCond,
					Body = nodeBody,
				}
			until not tok:ConsumeKeyword('elseif', tokenList)

			--else clause
			if tok:ConsumeKeyword('else', tokenList) then
				local nodeBody = ParseStatementList(scope)
				clauses[#clauses+1] = {
					Body = nodeBody,
				}
			end

			--end
			if not tok:ConsumeKeyword('end', tokenList) then
				GenerateError("`end` expected.")
			end

			nodeIfStat.Tokens = tokenList
			stat = nodeIfStat
		elseif tok:ConsumeKeyword('while', tokenList) then
			--condition
			local nodeCond = ParseExpr(scope)

			--do
			if not tok:ConsumeKeyword('do', tokenList) then
				return GenerateError("`do` expected.")
			end

			--body
			local nodeBody = ParseStatementList(scope)

			--end
			if not tok:ConsumeKeyword('end', tokenList) then
				GenerateError("`end` expected.")
			end

			--return
			stat = {
				AstType = 'WhileStatement',
				Condition = nodeCond,
				Body      = nodeBody,
				Tokens    = tokenList,
			}
		elseif tok:ConsumeKeyword('do', tokenList) then
			--do block
			local nodeBlock = ParseStatementList(scope)
			if not tok:ConsumeKeyword('end', tokenList) then
				GenerateError("`end` expected.")
			end

			stat = {
				AstType = 'DoStatement',
				Body    = nodeBlock,
				Tokens  = tokenList,
			}
		elseif tok:ConsumeKeyword('for', tokenList) then
			--for block
			if not tok:Is('Ident') then
				GenerateError("<ident> expected.")
			end
			local baseVarName = tok:Get(tokenList)
			if tok:ConsumeSymbol('=', tokenList) then
				--numeric for
				local forScope = Scope(scope)
				local forVar = forScope:CreateLocal(baseVarName.Data)

				local startEx = ParseExpr(scope)
				if not tok:ConsumeSymbol(',', tokenList) then
					GenerateError("`,` Expected")
				end
				local endEx = ParseExpr(scope)
				local stepEx
				if tok:ConsumeSymbol(',', tokenList) then
					stepEx = ParseExpr(scope)
				end
				if not tok:ConsumeKeyword('do', tokenList) then
					GenerateError("`do` expected")
				end

				local body = ParseStatementList(forScope)
				if not tok:ConsumeKeyword('end', tokenList) then
					GenerateError("`end` expected")
				end

				stat = {
					AstType  = 'NumericForStatement',
					Scope    = forScope,
					Variable = forVar,
					Start    = startEx,
					End      = endEx,
					Step     = stepEx,
					Body     = body,
					Tokens   = tokenList,
				}
			else
				--generic for
				local forScope = Scope(scope)

				local varList = { forScope:CreateLocal(baseVarName.Data) }
				while tok:ConsumeSymbol(',', tokenList) do
					if not tok:Is('Ident') then
						GenerateError("for variable expected.")
					end
					varList[#varList+1] = forScope:CreateLocal(tok:Get(tokenList).Data)
				end
				if not tok:ConsumeKeyword('in', tokenList) then
					GenerateError("`in` expected.")
				end
				local generators = {ParseExpr(scope)}
				while tok:ConsumeSymbol(',', tokenList) do
					generators[#generators+1] = ParseExpr(scope)
				end

				if not tok:ConsumeKeyword('do', tokenList) then
					GenerateError("`do` expected.")
				end

				local body = ParseStatementList(forScope)
				if not tok:ConsumeKeyword('end', tokenList) then
					GenerateError("`end` expected.")
				end

				stat = {
					AstType      = 'GenericForStatement',
					Scope        = forScope,
					VariableList = varList,
					Generators   = generators,
					Body         = body,
					Tokens       = tokenList,
				}
			end
		elseif tok:ConsumeKeyword('repeat', tokenList) then
			local body = ParseStatementList(scope)

			if not tok:ConsumeKeyword('until', tokenList) then
				GenerateError("`until` expected.")
			end

			cond = ParseExpr(body.Scope)

			stat = {
				AstType   = 'RepeatStatement',
				Condition = cond,
				Body      = body,
				Tokens    = tokenList,
			}
		elseif tok:ConsumeKeyword('function', tokenList) then
			if not tok:Is('Ident') then
				GenerateError("Function name expected")
			end
			local name = ParseSuffixedExpr(scope, true) --true => only dots and colons

			local func = ParseFunctionArgsAndBody(scope, tokenList)

			func.IsLocal = false
			func.Name    = name
			stat = func
		elseif tok:ConsumeKeyword('local', tokenList) then
			if tok:Is('Ident') then
				local varList = { tok:Get(tokenList).Data }
				while tok:ConsumeSymbol(',', tokenList) do
					if not tok:Is('Ident') then
						GenerateError("local var name expected")
					end
					varList[#varList+1] = tok:Get(tokenList).Data
				end

				local initList = {}
				if tok:ConsumeSymbol('=', tokenList) then
					repeat
						initList[#initList+1] = ParseExpr(scope)
					until not tok:ConsumeSymbol(',', tokenList)
				end

				--now patch var list
				--we can't do this before getting the init list, because the init list does not
				--have the locals themselves in scope.
				for i, v in pairs(varList) do
					varList[i] = scope:CreateLocal(v)
				end

				stat = {
					AstType   = 'LocalStatement',
					LocalList = varList,
					InitList  = initList,
					Tokens    = tokenList,
				}

			elseif tok:ConsumeKeyword('function', tokenList) then
				if not tok:Is('Ident') then
					GenerateError("Function name expected")
				end
				local name = tok:Get(tokenList).Data
				local localVar = scope:CreateLocal(name)

				local func = ParseFunctionArgsAndBody(scope, tokenList)

				func.Name    = localVar
				func.IsLocal = true
				stat = func

			else
				GenerateError("local var or function def expected")
			end
		elseif tok:ConsumeSymbol('::', tokenList) then
			if not tok:Is('Ident') then
				GenerateError('Label name expected')
			end
			local label = tok:Get(tokenList).Data
			if not tok:ConsumeSymbol('::', tokenList) then
				GenerateError("`::` expected")
			end
			stat = {
				AstType = 'LabelStatement',
				Label   = label,
				Tokens  = tokenList,
			}
		elseif tok:ConsumeKeyword('return', tokenList) then
			local exList = {}
			if not tok:IsKeyword('end') then
				-- Use PCall as this may produce an error
				local st, firstEx = pcall(function() ParseExpr(scope) end)
				if st then
					exList[1] = firstEx
					while tok:ConsumeSymbol(',', tokenList) do
						exList[#exList+1] = ParseExpr(scope)
					end
				end
			end
			stat = {
				AstType   = 'ReturnStatement',
				Arguments = exList,
				Tokens    = tokenList,
			}
		elseif tok:ConsumeKeyword('break', tokenList) then
			stat = {
				AstType = 'BreakStatement',
				Tokens  = tokenList,
			}
		elseif tok:ConsumeKeyword('goto', tokenList) then
			if not tok:Is('Ident') then
				GenerateError("Label expected")
			end
			local label = tok:Get(tokenList).Data
			stat = {
				AstType = 'GotoStatement',
				Label   = label,
				Tokens  = tokenList,
			}
		else
			--statementParseExpr
			local suffixed = ParseSuffixedExpr(scope)

			--assignment or call?
			if tok:IsSymbol(',') or tok:IsSymbol('=') then
				--check that it was not parenthesized, making it not an lvalue
				if (suffixed.ParenCount or 0) > 0 then
					GenerateError("Can not assign to parenthesized expression, is not an lvalue")
				end

				--more processing needed
				local lhs = { suffixed }
				while tok:ConsumeSymbol(',', tokenList) do
					lhs[#lhs+1] = ParseSuffixedExpr(scope)
				end

				--equals
				if not tok:ConsumeSymbol('=', tokenList) then
					GenerateError("`=` Expected.")
				end

				--rhs
				local rhs = {ParseExpr(scope)}
				while tok:ConsumeSymbol(',', tokenList) do
					rhs[#rhs+1] = ParseExpr(scope)
				end

				--done
				stat = {
					AstType = 'AssignmentStatement',
					Lhs     = lhs,
					Rhs     = rhs,
					Tokens  = tokenList,
				}

			elseif suffixed.AstType == 'CallExpr' or
				   suffixed.AstType == 'TableCallExpr' or
				   suffixed.AstType == 'StringCallExpr'
			then
				--it's a call statement
				stat = {
					AstType    = 'CallStatement',
					Expression = suffixed,
					Tokens     = tokenList,
				}
			else
				GenerateError("Assignment Statement Expected")
			end
		end

		if tok:IsSymbol(';') then
			stat.Semicolon = tok:Get( stat.Tokens )
		end
		return stat
	end

	--- Parse a a list of statements
	-- @tparam Scope.Scope scope The current scope
	-- @treturn Node The resulting node
	function ParseStatementList(scope)
		local body = {}
		local nodeStatlist   = {
			Scope   = Scope(scope),
			AstType = 'Statlist',
			Body    = body,
			Tokens  = {},
		}

		while not statListCloseKeywords[tok:Peek().Data] and not tok:IsEof() do
			local nodeStatement = ParseStatement(nodeStatlist.Scope)
			--stats[#stats+1] = nodeStatement
			body[#body + 1] = nodeStatement
		end

		if tok:IsEof() then
			local nodeEof = {}
			nodeEof.AstType = 'Eof'
			nodeEof.Tokens  = { tok:Get() }
			body[#body + 1] = nodeEof
		end

		--nodeStatlist.Body = stats
		return nodeStatlist
	end

	return ParseStatementList(Scope())
end

--- @export
return { LexLua = LexLua, ParseLua = ParseLua }
