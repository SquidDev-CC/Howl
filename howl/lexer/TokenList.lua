--- Provides utilities for reading tokens from a 'stream'
-- @module howl.lexer.TokenList

local min = math.min
local insert = table.insert

return function(tokens)
	local n = #tokens
	local pointer = 1

	local TokenList = {}

	--- Get this element in the token list
	-- @tparam int offset The offset in the token list
	local function Peek(offset)
		return tokens[min(n, pointer + (offset or 0))]
	end

	--- Get the next token in the list
	-- @tparam table tokenList Add the token onto this table
	-- @treturn Token The token
	local function Get(tokenList)
		local token = tokens[pointer]
		pointer = min(pointer + 1, n)
		if tokenList then
			insert(tokenList, token)
		end
		return token
	end

	--- Check if the next token is of a type
	-- @tparam string type The type to compare it with
	-- @treturn bool If the type matches
	local function Is(type)
		return Peek().Type == type
	end

	--- Check if the next token is a symbol and return it
	-- @tparam string symbol Symbol to check (Optional)
	-- @tparam table tokenList Add the token onto this table
	-- @treturn [ 0 ] ?|token If symbol is not specified, return the token
	-- @treturn [ 1 ] boolean If symbol is specified, return true if it matches
	local function ConsumeSymbol(symbol, tokenList)
		local token = Peek()
		if token.Type == 'Symbol' then
			if symbol then
				if token.Data == symbol then
					if tokenList then insert(tokenList, token) end
					pointer = pointer + 1
					return true
				else
					return nil
				end
			else
				if tokenList then insert(tokenList, token) end
				pointer = pointer + 1
				return token
			end
		else
			return nil
		end
	end

	--- Check if the next token is a keyword and return it
	-- @tparam string kw Keyword to check (Optional)
	-- @tparam table tokenList Add the token onto this table
	-- @treturn [ 0 ] ?|token If kw is not specified, return the token
	-- @treturn [ 1 ] boolean If kw is specified, return true if it matches
	local function ConsumeKeyword(kw, tokenList)
		local token = Peek()
		if token.Type == 'Keyword' and token.Data == kw then
			if tokenList then insert(tokenList, token) end
			pointer = pointer + 1
			return true
		else
			return nil
		end
	end

	--- Check if the next token matches is a keyword
	-- @tparam string kw The particular keyword
	-- @treturn boolean If it matches or not
	local function IsKeyword(kw)
		local token = Peek()
		return token.Type == 'Keyword' and token.Data == kw
	end

	--- Check if the next token matches is a symbol
	-- @tparam string symbol The particular symbol
	-- @treturn boolean If it matches or not
	local function IsSymbol(symbol)
		local token = Peek()
		return token.Type == 'Symbol' and token.Data == symbol
	end

	--- Check if the next token is an end of file
	-- @treturn boolean If the next token is an end of file
	local function IsEof()
		return Peek().Type == 'Eof'
	end

	--- Produce a string off all tokens
	-- @tparam boolean includeLeading Include the leading whitespace
	-- @treturn string The resulting string
	local function Print(includeLeading)
		includeLeading = (includeLeading == nil and true or includeLeading)

		local out = ""
		for _, token in ipairs(tokens) do
			if includeLeading then
				for _, whitespace in ipairs(token.LeadingWhite) do
					out = out .. whitespace:Print() .. "\n"
				end
			end
			out = out .. token:Print() .. "\n"
		end

		return out
	end

	return {
		Peek = Peek,
		Get = Get,
		Is = Is,
		ConsumeSymbol = ConsumeSymbol,
		ConsumeKeyword = ConsumeKeyword,
		IsKeyword = IsKeyword,
		IsSymbol = IsSymbol,
		IsEof = IsEof,
		Print = Print,
	}
end
