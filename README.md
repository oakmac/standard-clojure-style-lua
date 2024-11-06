# Standard Clojure Style in Lua

This is a port of [Standard Clojure Style] in Lua 🌙

[Standard Clojure Style]:https://github.com/oakmac/standard-clojure-style-js

## Development

```sh
lua tests.lua
```

## TODO

- [x] set up test harness
- [x] set up a formatter script with [StyLua]
- [x] get the internal test cases passing
- [x] get the parser test cases passing
- [x] parse_ns test cases
- [x] format test cases
- [ ] format edge case tests like CRLF and line endings
- [ ] set up continuous integration
- [ ] use a Set / Table indices for the special chars lookups
  - https://www.lua.org/pil/11.5.html
- [ ] set up CI
- [ ] create a changelog file

[StyLua]:https://github.com/JohnnyMorganz/StyLua

## License

[ISC License](LICENSE.md)
