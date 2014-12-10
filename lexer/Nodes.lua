--- Stores all nodes
-- @module lexer.Nodes

local joinStatements = Rebuild.JoinStatements
--- Options for writing
-- @table Options
-- @tfield boolean comments Include comments
-- @tfield boolean whitespace Include whitespace
-- @tfield boolean emptylines Include empty lines

--- A node
-- @table Node
-- @tparam string AstType The name of the node

local Function = {}
function Function:Print(options)
	local whitespace = 
end