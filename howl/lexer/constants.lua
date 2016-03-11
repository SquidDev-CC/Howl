--- Lexer constants
-- @module howl.lexer.constants

local createLookup = require "howl.lib.utils".createLookup

return {
	--- List of white chars
	WhiteChars = createLookup { ' ', '\n', '\t', '\r' },

	--- Lookup of escape characters
	EscapeLookup = { ['\r'] = '\\r', ['\n'] = '\\n', ['\t'] = '\\t', ['"'] = '\\"', ["'"] = "\\'" },

	--- Lookup of lower case characters
	LowerChars = createLookup {
		'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
		'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
	},

	--- Lookup of upper case characters
	UpperChars = createLookup {
		'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
		'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
	},

	--- Lookup of digits
	Digits = createLookup { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' },

	--- Lookup of hex digits
	HexDigits = createLookup {
		'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
		'A', 'a', 'B', 'b', 'C', 'c', 'D', 'd', 'E', 'e', 'F', 'f'
	},

	--- Lookup of valid symbols
	Symbols = createLookup { '+', '-', '*', '/', '^', '%', ',', '{', '}', '[', ']', '(', ')', ';', '#' },

	--- Lookup of valid keywords
	Keywords = createLookup {
		'and', 'break', 'do', 'else', 'elseif',
		'end', 'false', 'for', 'function', 'goto', 'if',
		'in', 'local', 'nil', 'not', 'or', 'repeat',
		'return', 'then', 'true', 'until', 'while',
	},

	--- Keywords that end a block
	StatListCloseKeywords = createLookup { 'end', 'else', 'elseif', 'until' },

	--- Unary operators
	UnOps = createLookup { '-', 'not', '#' },
}
