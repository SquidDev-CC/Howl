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

--- One token
-- @table Token
-- @tparam string Type The token type
-- @param Data Data about the token
-- @tparam string CommentType The type of comment  (Optional)
-- @tparam number Line Line number (Optional)
-- @tparam number Char Character number (Optional)

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
						--
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
					local token = {
						Type = 'Comment',
						CommentType = 'Shebang',
						Data = leadingWhite,
						Line = line,
						Char = char
					}
					token.Print = function()
						return "<"..(token.Type .. string.rep(' ', 7-#token.Type)).."  "..(token.Data or '').." >"
					end
					leadingWhite = ""
					table.insert(leading, token)
				end
				if c == ' ' or c == '\t' then
					--whitespace
					--leadingWhite = leadingWhite..get()
					local c2 = get() -- ignore whitespace
					table.insert(leading, { Type = 'Whitespace', Line = line, Char = char, Data = c2 })
				elseif c == '\n' or c == '\r' then
					local nl = get()
					if leadingWhite ~= "" then
						local token = {
							Type = 'Comment',
							CommentType = longStr and 'LongComment' or 'Comment',
							Data = leadingWhite,
							Line = line,
							Char = char,
						}
						token.Print = function()
							return "<"..(token.Type .. string.rep(' ', 7-#token.Type)).."  "..(token.Data or '').." >"
						end
						table.insert(leading, token)
						leadingWhite = ""
					end
					table.insert(leading, { Type = 'Whitespace', Line = line, Char = char, Data = nl })
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
				local token = {
					Type = 'Comment',
					CommentType = longStr and 'LongComment' or 'Com mnment',
					Data = leadingWhite,
					Line = line,
					Char = char,
				}
				token.Print = function()
					return "<"..(token.Type .. string.rep(' ', 7-#token.Type)).."  "..(token.Data or '').." >"
				end
				table.insert(leading, token)
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
			--for k, tok in pairs(leading) do
			--	tokens[#tokens + 1] = tok
			--end

			toEmit.Line = thisLine
			toEmit.Char = thisChar
			toEmit.Print = function()
				return "<"..(toEmit.Type..string.rep(' ', 7-#toEmit.Type)).."  "..(toEmit.Data or '').." >"
			end
			tokens[#tokens+1] = toEmit

			--halt after eof has been emitted
			if toEmit.Type == 'Eof' then break end
		end
	end
	if not st then return false, err end

	--public interface:
	local tokenList = setmetatable({
		tokens = tokens,
		savedPointers = {},
		pointer = 1
	}, TokenList)

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
					return GenerateError("`...` must be the last argument of a function.")
				end
				break
			else
				GenerateError("Argument name or `...` expected")
			end
		end

		--body
		local st, body = ParseStatementList(funcScope)
		if not st then return body end

		--end
		if not tok:ConsumeKeyword('end', tokenList) then
			GenerateError("`end` expected after function body")
		end
		local nodeFunc = {
			AstType   = 'Function',
			Scope     = funcScope,
			Arguments = argList,
			Body      = body,
			VarArg    = isVarArg,
			Tokens    = tokenList,
		}

		return nodeFunc
	end


	function ParsePrimaryExpr(scope)
		local tokenList = {}

		if tok:ConsumeSymbol('(', tokenList) then
			local ex = ParseExpr(scope)
			if not tok:ConsumeSymbol(')', tokenList) then
				GenerateError("`)` Expected.")
			end

			local parensExp = {}
			parensExp.AstType   = 'Parentheses'
			parensExp.Inner     = ex
			parensExp.Tokens    = tokenList
			return parensExp

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
			--
			local nodePrimExp = {}
			nodePrimExp.AstType   = 'VarExpr'
			nodePrimExp.Name      = id.Data
			nodePrimExp.Variable  = var
			nodePrimExp.Tokens    = tokenList
			--
			return nodePrimExp
		else
			GenerateError("primary expression expected")
		end
	end

	function ParseSuffixedExpr(scope, onlyDotColon)
		--base primary expression
		local prim = ParsePrimaryExpr(scope)
		--
		while true do
			local tokenList = {}

			if tok:IsSymbol('.') or tok:IsSymbol(':') then
				local symb = tok:Get(tokenList).Data
				if not tok:Is('Ident') then
					GenerateError("<Ident> expected.")
				end
				local id = tok:Get(tokenList)
				local nodeIndex = {}
				nodeIndex.AstType  = 'MemberExpr'
				nodeIndex.Base     = prim
				nodeIndex.Indexer  = symb
				nodeIndex.Ident    = id
				nodeIndex.Tokens   = tokenList
				--
				prim = nodeIndex

			elseif not onlyDotColon and tok:ConsumeSymbol('[', tokenList) then
				local ex = ParseExpr(scope)
				if not tok:ConsumeSymbol(']', tokenList) then
					GenerateError("`]` expected.")
				end
				local nodeIndex = {}
				nodeIndex.AstType  = 'IndexExpr'
				nodeIndex.Base     = prim
				nodeIndex.Index    = ex
				nodeIndex.Tokens   = tokenList
				--
				prim = nodeIndex

			elseif not onlyDotColon and tok:ConsumeSymbol('(', tokenList) then
				local args = {}
				while not tok:ConsumeSymbol(')', tokenList) do
					local st, ex = ParseExpr(scope)
					if not st then return false, ex end
					args[#args+1] = ex
					if not tok:ConsumeSymbol(',', tokenList) then
						if tok:ConsumeSymbol(')', tokenList) then
							break
						else
							GenerateError("`)` Expected.")
						end
					end
				end
				local nodeCall = {}
				nodeCall.AstType   = 'CallExpr'
				nodeCall.Base      = prim
				nodeCall.Arguments = args
				nodeCall.Tokens    = tokenList
				--
				prim = nodeCall

			elseif not onlyDotColon and tok:Is('String') then
				--string call
				local nodeCall = {}
				nodeCall.AstType    = 'StringCallExpr'
				nodeCall.Base       = prim
				nodeCall.Arguments  = { tok:Get(tokenList) }
				nodeCall.Tokens     = tokenList
				--
				prim = nodeCall

			elseif not onlyDotColon and tok:IsSymbol('{') then
				--table call
				local st, ex = ParseSimpleExpr(scope)
				-- FIX: ParseExpr(scope) parses the table AND and any following binary expressions.
				-- We just want the table
				if not st then return false, ex end
				local nodeCall = {}
				nodeCall.AstType   = 'TableCallExpr'
				nodeCall.Base      = prim
				nodeCall.Arguments = { ex }
				nodeCall.Tokens    = tokenList
				--
				prim = nodeCall

			else
				break
			end
		end
		return prim
	end


	function ParseSimpleExpr(scope)
		local tokenList = {}

		if tok:Is('Number') then
			local nodeNum = {}
			nodeNum.AstType = 'NumberExpr'
			nodeNum.Value   = tok:Get(tokenList)
			nodeNum.Tokens  = tokenList
			return nodeNum

		elseif tok:Is('String') then
			local nodeStr = {}
			nodeStr.AstType = 'StringExpr'
			nodeStr.Value   = tok:Get(tokenList)
			nodeStr.Tokens  = tokenList
			return nodeStr

		elseif tok:ConsumeKeyword('nil', tokenList) then
			local nodeNil = {}
			nodeNil.AstType = 'NilExpr'
			nodeNil.Tokens  = tokenList
			return nodeNil

		elseif tok:IsKeyword('false') or tok:IsKeyword('true') then
			local nodeBoolean = {}
			nodeBoolean.AstType = 'BooleanExpr'
			nodeBoolean.Value   = (tok:Get(tokenList).Data == 'true')
			nodeBoolean.Tokens  = tokenList
			return nodeBoolean

		elseif tok:ConsumeSymbol('...', tokenList) then
			local nodeDots = {}
			nodeDots.AstType  = 'DotsExpr'
			nodeDots.Tokens   = tokenList
			return nodeDots

		elseif tok:ConsumeSymbol('{', tokenList) then
			local v = {}
			v.AstType = 'ConstructorExpr'
			v.EntryList = {}
			--
			while true do
				if tok:IsSymbol('[', tokenList) then
					--key
					tok:Get(tokenList)
					local st, key = ParseExpr(scope)
					if not st then
						GenerateError("Key Expression Expected")
					end
					if not tok:ConsumeSymbol(']', tokenList) then
						GenerateError("`]` Expected")
					end
					if not tok:ConsumeSymbol('=', tokenList) then
						GenerateError("`=` Expected")
					end
					local st, value = ParseExpr(scope)
					if not st then
						GenerateError("Value Expression Expected")
					end
					v.EntryList[#v.EntryList+1] = {
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
						v.EntryList[#v.EntryList+1] = {
							Type  = 'KeyString',
							Key   = key.Data,
							Value = value,
						}

					else
						--we are a value
						local value = ParseExpr(scope)
						v.EntryList[#v.EntryList+1] = {
							Type = 'Value',
							Value = value,
						}

					end
				elseif tok:ConsumeSymbol('}', tokenList) then
					break

				else
					--value
					local value = ParseExpr(scope)
					v.EntryList[#v.EntryList+1] = {
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
			v.Tokens  = tokenList
			return v

		elseif tok:ConsumeKeyword('function', tokenList) then
			local func = ParseFunctionArgsAndBody(scope, tokenList)
			--
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
				local st, rhs = ParseExpr(scope, prio[2])
				if not st then return false, rhs end
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


	local function ParseStatement(scope)
		local stat = nil
		local tokenList = {}
		if tok:ConsumeKeyword('if', tokenList) then
			--setup
			local nodeIfStat = {}
			nodeIfStat.AstType = 'IfStatement'
			nodeIfStat.Clauses = {}

			--clauses
			repeat
				local nodeCond = ParseExpr(scope)

				if not tok:ConsumeKeyword('then', tokenList) then
					GenerateError("`then` expected.")
				end
				local nodeBody = ParseStatementList(scope)
				nodeIfStat.Clauses[#nodeIfStat.Clauses+1] = {
					Condition = nodeCond,
					Body = nodeBody,
				}
			until not tok:ConsumeKeyword('elseif', tokenList)

			--else clause
			if tok:ConsumeKeyword('else', tokenList) then
				local nodeBody = ParseStatementList(scope)
				nodeIfStat.Clauses[#nodeIfStat.Clauses+1] = {
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
					return false, GenerateError("`,` Expected")
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

				nodeFor.AstType  = 'NumericForStatement'
				nodeFor.Scope    = forScope
				nodeFor.Variable = forVar
				nodeFor.Start    = startEx
				nodeFor.End      = endEx
				nodeFor.Step     = stepEx
				nodeFor.Body     = body
				nodeFor.Tokens   = tokenList
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
				--
				local varList = { forScope:CreateLocal(baseVarName.Data) }
				while tok:ConsumeSymbol(',', tokenList) do
					if not tok:Is('Ident') then
						return false, GenerateError("for variable expected.")
					end
					varList[#varList+1] = forScope:CreateLocal(tok:Get(tokenList).Data)
				end
				if not tok:ConsumeKeyword('in', tokenList) then
					return false, GenerateError("`in` expected.")
				end
				local generators = {}
				local st, firstGenerator = ParseExpr(scope)
				if not st then return false, firstGenerator end
				generators[#generators+1] = firstGenerator
				while tok:ConsumeSymbol(',', tokenList) do
					local st, gen = ParseExpr(scope)
					if not st then return false, gen end
					generators[#generators+1] = gen
				end
				if not tok:ConsumeKeyword('do', tokenList) then
					return false, GenerateError("`do` expected.")
				end
				local st, body = ParseStatementList(forScope)
				if not st then return false, body end
				if not tok:ConsumeKeyword('end', tokenList) then
					return false, GenerateError("`end` expected.")
				end
				--
				local nodeFor = {}
				nodeFor.AstType      = 'GenericForStatement'
				nodeFor.Scope        = forScope
				nodeFor.VariableList = varList
				nodeFor.Generators   = generators
				nodeFor.Body         = body
				nodeFor.Tokens       = tokenList
				stat = nodeFor
			end

		elseif tok:ConsumeKeyword('repeat', tokenList) then
			local st, body = ParseStatementList(scope)
			if not st then return false, body end
			--
			if not tok:ConsumeKeyword('until', tokenList) then
				return false, GenerateError("`until` expected.")
			end
			-- FIX: Used to parse in parent scope
			-- Now parses in repeat scope
			local st, cond = ParseExpr(body.Scope)
			if not st then return false, cond end
			--
			local nodeRepeat = {}
			nodeRepeat.AstType   = 'RepeatStatement'
			nodeRepeat.Condition = cond
			nodeRepeat.Body      = body
			nodeRepeat.Tokens    = tokenList
			stat = nodeRepeat

		elseif tok:ConsumeKeyword('function', tokenList) then
			if not tok:Is('Ident') then
				return false, GenerateError("Function name expected")
			end
			local st, name = ParseSuffixedExpr(scope, true) --true => only dots and colons
			if not st then return false, name end
			--
			local st, func = ParseFunctionArgsAndBody(scope, tokenList)
			if not st then return false, func end
			--
			func.IsLocal = false
			func.Name    = name
			stat = func

		elseif tok:ConsumeKeyword('local', tokenList) then
			if tok:Is('Ident') then
				local varList = { tok:Get(tokenList).Data }
				while tok:ConsumeSymbol(',', tokenList) do
					if not tok:Is('Ident') then
						return false, GenerateError("local var name expected")
					end
					varList[#varList+1] = tok:Get(tokenList).Data
				end

				local initList = {}
				if tok:ConsumeSymbol('=', tokenList) then
					repeat
						local st, ex = ParseExpr(scope)
						if not st then return false, ex end
						initList[#initList+1] = ex
					until not tok:ConsumeSymbol(',', tokenList)
				end

				--now patch var list
				--we can't do this before getting the init list, because the init list does not
				--have the locals themselves in scope.
				for i, v in pairs(varList) do
					varList[i] = scope:CreateLocal(v)
				end

				local nodeLocal = {}
				nodeLocal.AstType   = 'LocalStatement'
				nodeLocal.LocalList = varList
				nodeLocal.InitList  = initList
				nodeLocal.Tokens    = tokenList
				--
				stat = nodeLocal

			elseif tok:ConsumeKeyword('function', tokenList) then
				if not tok:Is('Ident') then
					return false, GenerateError("Function name expected")
				end
				local name = tok:Get(tokenList).Data
				local localVar = scope:CreateLocal(name)
				--
				local st, func = ParseFunctionArgsAndBody(scope, tokenList)
				if not st then return false, func end
				--
				func.Name         = localVar
				func.IsLocal      = true
				stat = func

			else
				return false, GenerateError("local var or function def expected")
			end

		elseif tok:ConsumeSymbol('::', tokenList) then
			if not tok:Is('Ident') then
				return false, GenerateError('Label name expected')
			end
			local label = tok:Get(tokenList).Data
			if not tok:ConsumeSymbol('::', tokenList) then
				return false, GenerateError("`::` expected")
			end
			local nodeLabel = {}
			nodeLabel.AstType = 'LabelStatement'
			nodeLabel.Label   = label
			nodeLabel.Tokens  = tokenList
			stat = nodeLabel

		elseif tok:ConsumeKeyword('return', tokenList) then
			local exList = {}
			if not tok:IsKeyword('end') then
				local st, firstEx = ParseExpr(scope)
				if st then
					exList[1] = firstEx
					while tok:ConsumeSymbol(',', tokenList) do
						local st, ex = ParseExpr(scope)
						if not st then return false, ex end
						exList[#exList+1] = ex
					end
				end
			end

			local nodeReturn = {}
			nodeReturn.AstType   = 'ReturnStatement'
			nodeReturn.Arguments = exList
			nodeReturn.Tokens    = tokenList
			stat = nodeReturn

		elseif tok:ConsumeKeyword('break', tokenList) then
			local nodeBreak = {}
			nodeBreak.AstType = 'BreakStatement'
			nodeBreak.Tokens  = tokenList
			stat = nodeBreak

		elseif tok:ConsumeKeyword('goto', tokenList) then
			if not tok:Is('Ident') then
				return false, GenerateError("Label expected")
			end
			local label = tok:Get(tokenList).Data
			local nodeGoto = {}
			nodeGoto.AstType = 'GotoStatement'
			nodeGoto.Label   = label
			nodeGoto.Tokens  = tokenList
			stat = nodeGoto

		else
			--statementParseExpr
			local st, suffixed = ParseSuffixedExpr(scope)
			if not st then return false, suffixed end

			--assignment or call?
			if tok:IsSymbol(',') or tok:IsSymbol('=') then
				--check that it was not parenthesized, making it not an lvalue
				if (suffixed.ParenCount or 0) > 0 then
					return false, GenerateError("Can not assign to parenthesized expression, is not an lvalue")
				end

				--more processing needed
				local lhs = { suffixed }
				while tok:ConsumeSymbol(',', tokenList) do
					local st, lhsPart = ParseSuffixedExpr(scope)
					if not st then return false, lhsPart end
					lhs[#lhs+1] = lhsPart
				end

				--equals
				if not tok:ConsumeSymbol('=', tokenList) then
					return false, GenerateError("`=` Expected.")
				end

				--rhs
				local rhs = {}
				local st, firstRhs = ParseExpr(scope)
				if not st then return false, firstRhs end
				rhs[1] = firstRhs
				while tok:ConsumeSymbol(',', tokenList) do
					local st, rhsPart = ParseExpr(scope)
					if not st then return false, rhsPart end
					rhs[#rhs+1] = rhsPart
				end

				--done
				local nodeAssign = {}
				nodeAssign.AstType = 'AssignmentStatement'
				nodeAssign.Lhs     = lhs
				nodeAssign.Rhs     = rhs
				nodeAssign.Tokens  = tokenList
				stat = nodeAssign

			elseif suffixed.AstType == 'CallExpr' or
				   suffixed.AstType == 'TableCallExpr' or
				   suffixed.AstType == 'StringCallExpr'
			then
				--it's a call statement
				local nodeCall = {}
				nodeCall.AstType    = 'CallStatement'
				nodeCall.Expression = suffixed
				nodeCall.Tokens     = tokenList
				stat = nodeCall
			else
				return false, GenerateError("Assignment Statement Expected")
			end
		end

		if tok:IsSymbol(';') then
			stat.Semicolon = tok:Get( stat.Tokens )
		end
		return stat
	end

	function ParseStatementList(scope)
		local nodeStatlist   = {}
		nodeStatlist.Scope   = Scope(scope)
		nodeStatlist.AstType = 'Statlist'
		nodeStatlist.Body    = { }
		nodeStatlist.Tokens  = { }
		--
		--local stats = {}
		--
		while not statListCloseKeywords[tok:Peek().Data] and not tok:IsEof() do
			local st, nodeStatement = ParseStatement(nodeStatlist.Scope)
			if not st then return false, nodeStatement end
			--stats[#stats+1] = nodeStatement
			nodeStatlist.Body[#nodeStatlist.Body + 1] = nodeStatement
		end

		if tok:IsEof() then
			local nodeEof = {}
			nodeEof.AstType = 'Eof'
			nodeEof.Tokens  = { tok:Get() }
			nodeStatlist.Body[#nodeStatlist.Body + 1] = nodeEof
		end

		--
		--nodeStatlist.Body = stats
		return nodeStatlist
	end

	return ParseStatementList(Scope())
end

--- @export
return { LexLua = LexLua, ParseLua = ParseLua }
