# Standard Clojure Style in Lua

This is a port of [Standard Clojure Style] in Lua 🌙

[Standard Clojure Style]:https://github.com/oakmac/standard-clojure-style-js

## Editor Integrations

- [Neovim plugin](https://git.sr.ht/~ioiojo/standard-clojure-style.nvim)

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

- [ ] merge the changes that fix multibyte strings (utf8-aware string functions)
- [ ] add the profiler code
  - profiling recommendations https://claude.ai/chat/32f22525-71ad-4311-ad4e-27417618c7d2
  - string concatenation --> table.concat
  - resolve getParser once instead of every time

## License

[ISC License](LICENSE.md)
