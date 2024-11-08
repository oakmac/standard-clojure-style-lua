# Standard Clojure Style in Lua

This is a port of [Standard Clojure Style] in Lua 🌙

[Standard Clojure Style]:https://github.com/oakmac/standard-clojure-style-js

## Development

Make sure [lua] and [Stylua] are installed.

```sh
# run the unit tests
lua tests.lua

# format files with Stylua
./scripts/format.sh
```

[lua]:https://lua.org/
[StyLua]:https://github.com/JohnnyMorganz/StyLua

## TODO

- [ ] add format edge case tests like CRLF and line endings
- [ ] create a changelog file
- [ ] figure out a release process / approach

## License

[ISC License](LICENSE.md)
