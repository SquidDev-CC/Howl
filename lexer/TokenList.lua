--- @module lexer.TokenList

--- Stores a list of tokens
-- @type TokenList
-- @tfield table tokens List of tokens
-- @tfield number pointer Pointer to the current
-- @tfield table savedPointers A save point
local TokenList = {}

--- Get this element in the token list
-- @tparam int offset The offset in the token list
function TokenList:Peek(offset)
	local tokens = self.tokens
	offset = offset or 0
	return tokens[math.min(#tokens, self.pointer+offset)]
end

--- Get the next token in the list
-- @tparam table tokenList Add the token onto this table
-- @treturn Token The token
function TokenList:Get(tokenList)
	local tokens = self.tokens
	local pointer = self.pointer
	local token = tokens[pointer]
	self.pointer = math.min(pointer + 1, #tokens)
	if tokenList then
		table.insert(tokenList, token)
	end
	return token
end

--- Check if the next token is of a type
-- @tparam string type The type to compare it with
-- @treturn bool If the type matches
function TokenList:Is(type)
	return self:Peek().Type == type
end

--- Save position in a stream
function TokenList:Save()
	table.insert(self.savedPointers, self.pointer)
end

--- Remove the last position in the stream
function TokenList:Commit()
	local savedPointers = self.savedPointers
	savedPointers[#savedPointers] = nil
end

--- Restore to the previous save point
function TokenList:Restore()
	local savedPointers = self.savedPointers
	local sPLength = #savedPointers
	self.pointer = savedP[sPLength]
	savedPointers[sPLength] = nil
end

--- Check if the next token is a symbol and return it
-- @tparam string symbol Symbol to check (Optional)
-- @tparam table tokenList Add the token onto this table
-- @treturn[0] ?|token If symbol is not specified, return the token
-- @treturn[1] boolean If symbol is specified, return true if it matches
function TokenList:ConsumeSymbol(symbol, tokenList)
	local token = self:Peek()
	if token.Type == 'Symbol' then
		if symbol then
			if token.Data == symbol then
				self:Get(tokenList)
				return true
			else
				return nil
			end
		else
			self:Get(tokenList)
			return token
		end
	else
		return nil
	end
end

--- Check if the next token is a keyword and return it
-- @tparam string kw Keyword to check (Optional)
-- @tparam table tokenList Add the token onto this table
-- @treturn[0] ?|token If kw is not specified, return the token
-- @treturn[1] boolean If kw is specified, return true if it matches
function TokenList:ConsumeKeyword(kw, tokenList)
	local token = self:Peek()
	if token.Type == 'Keyword' and token.Data == kw then
		self:Get(tokenList)
		return true
	else
		return nil
	end
end

--- Check if the next token matches is a keyword
-- @tparam string kw The particular keyword
-- @treturn boolean If it matches or not
function TokenList:IsKeyword(kw)
	local token = self:Peek()
	return token.Type == 'Keyword' and token.Data == kw
end

--- Check if the next token matches is a symbol
-- @tparam string symbol The particular symbol
-- @treturn boolean If it matches or not
function TokenList:IsSymbol(symbol)
	local token = self:Peek()
	return token.Type == 'Symbol' and token.Data == symbol
end

--- Check if the next token is an end of file
-- @treturn boolean If the next token is an end of file
function TokenList:IsEof()
	return self:Peek().Type == 'Eof'
end

--- Produce a string off all tokens
-- @tparam boolean includeLeading Include the leading whitespace
-- @treturn string The resulting string
function TokenList:Print(includeLeading)
	includeLeading = (includeLeading == nil and true or includeLeading)

	local out = ""
	for _, token in ipairs(self.tokens) do
		if includeLeading then
			for _, whitespace in ipairs(token.LeadingWhite) do
				if whitespace.Print then
					out = out .. whitespace:Print() .. "\n"
				end
			end
		end
		out = out .. token:Print() .. "\n"
	end

	return out
end

return TokenList