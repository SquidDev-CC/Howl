[Lua Parsing and Refactorization tools](https://github.com/stravant/LuaMinify)
=========

A collection of tools for working with Lua source code. Primarily a Lua source code minifier, but also includes some static analysis tools and a general Lua lexer and parser.

Currently the minifier performs:

- Stripping of all comments and whitespace
- True semantic renaming of all local variables to a reduced form
- Reduces the source to the minimal spacing, spaces are only inserted where actually needed.

Features/Todo
-------------
Features:

    - Lua scanner/parser, which generates a full AST
    - Lua reconstructor
        - minimal
        - full reconstruction (TODO: options, comments)
        - TODO: exact reconstructor
    - support for embedded long strings/comments e.g. [[abc [[ def ]] ghi]]

Todo:
    - use table.concat instead of appends in the reconstructors
