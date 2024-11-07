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

- [x] set up test harness
- [x] set up a formatter script with [StyLua]
- [x] get the internal test cases passing
- [x] get the parser test cases passing
- [x] parse_ns test cases
- [x] format test cases
- [x] set up continuous integration
- [ ] format edge case tests like CRLF and line endings
- [ ] use a Set / Table indices for the special chars lookups
  - https://www.lua.org/pil/11.5.html
- [ ] create a changelog file
- [ ] figure out a release process / approach

## License

[ISC License](LICENSE.md)
