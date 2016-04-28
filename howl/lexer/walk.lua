local function terminate() end
local function callExpr(node, visitor)
	visitor(node.Base)
	for _, v in ipairs(node.Arguments) do visitor(v) end
end

local function indexExpr(node, visitor)
	visitor(node.Base)
	visitor(node.Index)
end

local visitors

local function visit(node, visitor)
	local traverse = visitors[node.AstType]
	if not traverse then
		error("No visitor for " .. node.AstType)
	end
	traverse(node, visitor)
end

visitors = {
	VarExpr = terminate,
	NumberExpr = terminate,
	StringExpr = terminate,
	BooleanExpr = terminate,
	NilExpr = terminate,
	DotsExpr = terminate,
	Eof = terminate,

	BinopExpr = function(node, visitor)
		visitor(node.Lhs)
		visitor(node.Rhs)
	end,

	UnopExpr = function(node, visitor)
		visitor(node.Rhs)
	end,

	CallExpr = callExpr,
	TableCallExpr = callExpr,
	StringCallExpr = callExpr,

	IndexExpr = indexExpr,
	MemberExpr = indexExpr,
	Function = function(node, visitor)
		if node.Name and not node.IsLocal then visitor(node.Name) end
		visitor(node.Body)
	end,

	ConstructorExpr = function(node, visitor)
		for _, v in ipairs(node.EntryList) do
			if v.Type == "Key" then visitor(v.Key) end
			visitor(v.Value)
		end
	end,

	Parentheses = function(node, visitor)
		visitor(v.Inner)
	end,

	Statlist = function(node, visitor)
		for _, v in ipairs(node.Body) do
			visitor(v)
		end
	end,

	ReturnStatement = function(node, visitor)
		for _, v in ipairs(node.Arguments) do visitor(v) end
	end,

	AssignmentStatement = function(node, visitor)
		for _, v in ipairs(node.Lhs) do visitor(v) end
		for _, v in ipairs(node.Rhs) do visitor(v) end
	end,

	LocalStatement = function(node, visitor)
		for _, v in ipairs(node.InitList) do visitor(v) end
	end,

	CallStatement = function(node, visitor)
		visitor(v.Expression)
	end,

	IfStatement = function(node, visitor)
		for _, v in ipairs(node.Clauses) do
			if v.Condition then visitor(v.Condition) end
			visitor(v.Body)
		end
	end,

	WhileStatement = function(node, visitor)
		visitor(node.Condition)
		visitor(node.Body)
	end,
	DoStatement = function(node, visitor) visitor(node.Body) end,
	BreakStatement = terminate,
	LabelStatement = terminate,
	GotoStatement = terminate,
	RepeatStatement = function(node, visitor)
		visitor(node.Body)
		visitor(node.Condition)
	end,

	GenericForStatement = function(node, visitor)
		for _, v in ipairs(node.Generators) do visitor(v) end
		visitor(node.Body)
	end,

	NumericForStatement = function(node, visitor)
		visitor(node.Start)
		visitor(node.End)
		if node.Step then visitor(node.Step) end
		visitor(node.Body)
	end
}

return visit