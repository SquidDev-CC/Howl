--Credit goes to http://www.computercraft.info/forums2/index.php?/topic/5854-json-api-v201-for-computercraft/
local controls = {["\n"]="\\n", ["\r"]="\\r", ["\t"]="\\t", ["\b"]="\\b", ["\f"]="\\f", ["\""]="\\\"", ["\\"]="\\\\"}
local whites = {['\n']=true; ['r']=true; ['\t']=true; [' ']=true; [',']=true; [':']=true}
local function removeWhite(str)
	while whites[str:sub(1, 1)] do
		str = str:sub(2)
	end
	return str
end

local jsonParseValue
local function jsonParseBoolean(str)
	if str:sub(1, 4) == "true" then
		return true, removeWhite(str:sub(5))
	else
		return false, removeWhite(str:sub(6))
	end
end

local function jsonParseNull(str)
	return nil, removeWhite(str:sub(5))
end

local numChars = {['e']=true; ['E']=true; ['+']=true; ['-']=true; ['.']=true}
local function jsonParseNumber(str)
	local i = 1
	while numChars[str:sub(i, i)] or tonumber(str:sub(i, i)) do
		i = i + 1
	end
	local val = tonumber(str:sub(1, i - 1))
	str = removeWhite(str:sub(i))
	return val, str
end

local function jsonParseString(str)
	local i,j = str:find('^".-[^\\]"')
	local s = str:sub(i + 1,j - 1)

	for k,v in pairs(controls) do
		s = s:gsub(v, k)
	end
	str = removeWhite(str:sub(j + 1))
	return s, str
end

local function jsonParseArray(str)
	str = removeWhite(str:sub(2))

	local val = {}
	local i = 1
	while str:sub(1, 1) ~= "]" do
		local v = nil
		v, str = jsonParseValue(str)
		val[i] = v
		i = i + 1
		str = removeWhite(str)
	end
	str = removeWhite(str:sub(2))
	return val, str
end

local function jsonParseMember(str)
	local k = nil
	k, str = jsonParseValue(str)
	local val = nil
	val, str = jsonParseValue(str)
	return k, val, str
end

local function jsonParseObject(str)
	str = removeWhite(str:sub(2))

	local val = {}
	while str:sub(1, 1) ~= "}" do
		local k, v = nil, nil
		k, v, str = jsonParseMember(str)
		val[k] = v
		str = removeWhite(str)
	end
	str = removeWhite(str:sub(2))
	return val, str
end

function jsonParseValue(str)
	local fchar = str:sub(1, 1)
	if fchar == "{" then
		return jsonParseObject(str)
	elseif fchar == "[" then
		return jsonParseArray(str)
	elseif tonumber(fchar) ~= nil or numChars[fchar] then
		return jsonParseNumber(str)
	elseif str:sub(1, 4) == "true" or str:sub(1, 5) == "false" then
		return jsonParseBoolean(str)
	elseif fchar == "\"" then
		return jsonParseString(str)
	elseif str:sub(1, 4) == "null" then
		return jsonParseNull(str)
	end
	return nil
end

local function jsonDecode(str)
	str = removeWhite(str)
	t = jsonParseValue(str)
	return t
end

return function(url)
	local file = http.get(url)
	return file and jsonDecode(file.readAll())
end
