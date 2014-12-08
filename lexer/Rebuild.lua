--- Rebuild source code from an AST
-- Does not preserve whitespace
-- @module lexer.Rebuild

local lowerChars = Constants.lowerChars
local upperChars = Constants.upperChars
local digits = Constants.digits
local symbols = Constants.symbols

--- Join two statements together
-- @tparam string left The left statement
-- @tparam string right The right statement
-- @tparam string sep The string used to separate the characters
-- @treturn string The joined strings
local function JoinStatements(left, right, sep)
	sep = sep or ' '
	local leftEnd, rightStart = left:sub(-1,-1), right:sub(1,1)
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

--- @export
return {
	JoinStatements = JoinStatements,
}