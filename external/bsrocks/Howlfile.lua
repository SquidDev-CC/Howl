Options:Default "trace"

plugins {
	{ type = "file", include = { "*.lua" }, exclude = { "Howlfile.lua" } },
}

Tasks:busted "busted" { }
Tasks:ldoc "ldoc" { }
