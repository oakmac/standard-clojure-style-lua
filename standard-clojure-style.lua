-- standard-clojure-style.lua - an implementation of Standard Clojure Style in Lua
-- v0.16.0
-- https://github.com/oakmac/standard-clojure-style-lua
--
-- Copyright (c) 2024, Chris Oakman
-- Released under the ISC license
-- https://github.com/oakmac/standard-clojure-style-lua/blob/master/LICENSE.md

-- forward declarations
local appendChildren, formatRenamesList, getParser, inc, isNamespacedMapOpener, parse, removeCharsUpToNewline

-- exported module table
local M = {}
M.version = "0.15.0"

-- -----------------------------------------------------------------------------
-- Development Helpers

-- NOTE: this is useful for development and debugging purposes
-- not required for the core library
-- local inspect = require("libs/inspect")

-- -----------------------------------------------------------------------------
-- Type Predicates

local function isString(s)
  return type(s) == "string"
end

local function isInteger(x)
  return type(x) == "number" and x == math.floor(x)
end

local function isPositiveInt(i)
  return isInteger(i) and i >= 0
end

local function isFunction(f)
  return type(f) == "function"
end

local function isTable(t)
  return type(t) == "table"
end

-- quickly check that something is Array-like
-- NOTE: see a more thorough version of this below which also passes the test suite
local function isArray(arr)
  return type(arr) == "table"
end

-- NOTE: this is a more thorough version of isArray than the function above
-- commented out here because we do not really need this level of thoroughness
-- for this library
-- local function isArray(arr)
--   -- In Lua, arrays are tables with consecutive integer keys starting at 1
--   -- This is a basic implementation that checks if a table appears to be array-like
--   if type(arr) ~= "table" then
--     return false
--   end

--   local count = 0
--   for _ in pairs(arr) do
--     count = count + 1
--   end

--   -- Check if all indices from 1 to count exist
--   for i = 1, count do
--     if arr[i] == nil then
--       return false
--     end
--   end
--   return true
-- end

-- -----------------------------------------------------------------------------
-- Language Helpers

-- returns the length of a String
local function strLen(s)
  return #s
end

-- returns the length of an Array
local function arraySize(a)
  return #a
end

-- returns the last item in an Array
-- returns nil if the Array has no items
local function arrayLast(a)
  local s = arraySize(a)
  if s == 0 then
    return nil
  else
    return a[s]
  end
end

local function dropLast(arr)
  local size = arraySize(arr)
  local newArr = {}
  for i = 1, dec(size) do
    newArr[i] = arr[i]
  end
  return newArr
end

-- given an array of objects, returns a new array of the values at obj[key]
local function arrayPluck(arr, key)
  local arr2 = {}
  local size = arraySize(arr)
  local idx = 1
  while idx <= size do
    local itm = arr[idx]
    arr2[idx] = itm[key]
    idx = inc(idx)
  end
  return arr2
end

local function arrayReverse(arr)
  local newArr = {}
  local size = arraySize(arr)
  for i = size, 1, -1 do
    newArr[size - i + 1] = arr[i]
  end
  return newArr
end

local function strConcat(s1, s2)
  return tostring(s1) .. tostring(s2)
end

local function strConcat3(s1, s2, s3)
  return tostring(s1) .. tostring(s2) .. tostring(s3)
end

function inc(n)
  return n + 1
end

local function dec(n)
  return n - 1
end

-- runs aFn(key, value) on every key/value pair inside of obj
local function objectForEach(obj, aFn)
  for key, value in pairs(obj) do
    aFn(key, value)
  end
end

local function deleteObjKey(obj, key)
  obj[key] = nil
  return obj
end

local function alwaysTrue()
  return true
end

-- Convert character sets to Lua pattern-safe strings
local function escapePattern(str)
  return str:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

-- -----------------------------------------------------------------------------
-- Stack Operations

local function stackPeek(arr, idxFromBack)
  local maxIdx = dec(arraySize(arr))
  if idxFromBack > maxIdx then
    return nil
  end
  return arr[maxIdx - idxFromBack + 1] -- Added +1 for Lua's 1-based indexing
end

local function stackPop(s)
  local itm = table.remove(s)
  return itm
end

local function stackPush(s, itm)
  table.insert(s, itm)
  return nil
end

-- -----------------------------------------------------------------------------
-- String Utils

local function charAt(s, n)
  if n < 0 then
    return ""
  end
  return string.sub(s, n, n)
end

-- Returns the substring of s beginning at startIdx inclusive, and ending
-- at endIdx exclusive.
-- Pass -1 to endIdx to mean "until the end of the string"
local function substr(s, startIdx, endIdx)
  if startIdx == endIdx then
    return ""
  end

  if endIdx < 0 then
    local len = strLen(s)
    endIdx = len + 1
  end
  return string.sub(s, startIdx, endIdx - 1)
end

local function repeatString(text, n)
  local result = ""
  local i = 0
  while i < n do
    result = result .. text
    i = inc(i)
  end
  return result
end

-- does String needle exist inside of String s?
local function strIncludes(s, needle)
  return string.find(s, needle, 1, true) ~= nil
end

local function toUpperCase(s)
  return string.upper(s)
end

local function strJoin(arr, s)
  return table.concat(arr, s)
end

local function rtrim(s)
  return s:match("(.-)%s*$")
end

local function strTrim(s)
  return s:match("^%s*(.-)%s*$")
end

local function strStartsWith(s, startStr)
  return s:sub(1, #startStr) == startStr
end

local function strEndsWith(s, endStr)
  if endStr == "" then
    return true
  end
  return s:sub(-#endStr) == endStr
end

local function isStringWithChars(s)
  return isString(s) and s ~= ""
end

local function strReplaceFirst(s, find, replace)
  if find == "" then
    return s
  end
  return (s:gsub(find, replace, 1))
end

local function strReplaceAll(s, find, replace)
  return string.gsub(s, find, replace)
end

-- replaces all instances of findStr with replaceStr inside of String s
-- local function strReplaceAll(s, findStr, replaceStr)
--   return string.gsub(s, findStr:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"), replaceStr)
-- end

local function crlfToLf(txt)
  return txt:gsub("\r\n", "\n")
end

-- ---------------------------------------------------------------------------
-- id generator

local idCounter = 0

local function createId()
  idCounter = inc(idCounter)
  return idCounter
end

-- ---------------------------------------------------------------------------
-- Node Types

-- creates and returns an AST Node Object:
-- - start: start position in String (inclusive)
-- - end: end position in String (exclusive)
-- - children: array of child Nodes
-- - name: name of the Node
-- - text: raw text of the Node (only for terminal nodes like Regex or Strings)
local function Node(opts)
  local n = {}
  n.children = opts.children
  n.endIdx = opts.endIdx
  n.id = createId()
  n.name = opts.name
  n.startIdx = opts.startIdx
  n.text = opts.text

  return n
end

local function Named(opts)
  local n = {}
  n.parse = function(txt, pos)
    local parser = getParser(opts.parser)
    local node = parser.parse(txt, pos)
    if not node then
      return nil
    elseif node and not isString(node.name) then
      node.name = opts.name
      return node
    else
      return Node({
        children = { node },
        endIdx = node.endIdx,
        name = opts.name,
        startIdx = node.startIdx,
      })
    end
  end

  return n
end

-- ---------------------------------------------------------------------------
-- Terminal Parsers

-- Terminal parser that matches any single character.
local function AnyChar(opts)
  local n = {}
  n.name = opts.name
  n.parse = function(txt, pos)
    if pos <= strLen(txt) then
      return Node({
        endIdx = inc(pos),
        name = opts.name,
        startIdx = pos,
        text = charAt(txt, pos),
      })
    else
      return nil
    end
  end
  return n
end

-- Terminal parser that matches one character.
local function Char(opts)
  local n = {}
  n.isTerminal = true
  n.char = opts.char
  n.name = opts.name
  n.parse = function(txt, pos)
    if pos <= strLen(txt) and charAt(txt, pos) == opts.char then
      return Node({
        endIdx = inc(pos),
        name = opts.name,
        startIdx = pos,
        text = opts.char,
      })
    else
      return nil
    end
  end
  return n
end

-- Terminal parser that matches any single character, except one.
local function NotChar(opts)
  return {
    isTerminal = true,
    char = opts.char,
    name = opts.name,
    parse = function(txt, pos)
      if pos <= strLen(txt) then
        local charAtThisPos = charAt(txt, pos)
        if charAtThisPos ~= opts.char then
          return Node({
            endIdx = inc(pos),
            name = opts.name,
            startIdx = pos,
            text = charAtThisPos,
          })
        end
      end

      return nil
    end,
  }
end

-- Terminal parser that matches a String
local function String(opts)
  return {
    name = opts.name,
    parse = function(txt, pos)
      local len = strLen(opts.str)
      if pos + len - 1 <= strLen(txt) then
        local strToCompare = substr(txt, pos, pos + len)
        if opts.str == strToCompare then
          return Node({
            endIdx = pos + len,
            name = opts.name,
            startIdx = pos,
            text = opts.str,
          })
        end
      end
      return nil
    end,
  }
end

-- FIXME: rename to "Pattern"
local function Pattern(opts)
  return {
    name = opts.name,
    pattern = opts.pattern,
    parse = function(txt, pos)
      local txt2 = substr(txt, pos, -1)
      local pattern2 = strConcat("^", opts.pattern)
      local matchResult = txt2:match(pattern2)

      if isString(matchResult) then
        return Node({
          endIdx = pos + strLen(matchResult),
          name = opts.name,
          startIdx = pos,
          text = matchResult,
        })
      end

      return nil
    end,
  }
end

-- Parses a body of a String character-by-character
local function stringBodyParser(txt, pos)
  local maxLength = strLen(txt)
  if maxLength == 0 then
    return nil
  end

  local charIdx = pos
  local endIdx = -1
  local keepSearching = true
  local parsedTxt = ""

  while keepSearching do
    local ch = charAt(txt, charIdx)
    if ch == nil or ch == "" then
      keepSearching = false
    elseif ch == "\\" then
      local nextChar = charAt(txt, inc(charIdx))
      if isString(nextChar) and nextChar ~= "" then
        parsedTxt = strConcat3(parsedTxt, ch, nextChar)
        charIdx = inc(charIdx)
      else
        return nil
      end
    elseif ch == '"' then
      keepSearching = false
      endIdx = charIdx
    else
      parsedTxt = strConcat(parsedTxt, ch)
    end

    charIdx = inc(charIdx)
    if charIdx > maxLength then
      keepSearching = false
    end
  end

  if endIdx > 0 then
    return Node({
      endIdx = endIdx,
      name = ".body",
      startIdx = pos,
      text = parsedTxt,
    })
  end

  return nil
end

local whitespaceCharsTbl = {
  -- Common chars
  [" "] = true,
  [","] = true,
  ["\n"] = true,
  ["\r"] = true,
  ["\t"] = true,
  ["\f"] = true,

  -- Unicode chars
  ["\u{000B}"] = true,
  ["\u{001C}"] = true,
  ["\u{001D}"] = true,
  ["\u{001E}"] = true,
  ["\u{001F}"] = true,
  ["\u{2028}"] = true,
  ["\u{2029}"] = true,
  ["\u{1680}"] = true,
  ["\u{2000}"] = true,
  ["\u{2001}"] = true,
  ["\u{2002}"] = true,
  ["\u{2003}"] = true,
  ["\u{2004}"] = true,
  ["\u{2005}"] = true,
  ["\u{2006}"] = true,
  ["\u{2008}"] = true,
  ["\u{2009}"] = true,
  ["\u{200a}"] = true,
  ["\u{205f}"] = true,
  ["\u{3000}"] = true,
}

local invalidTokenHeadCharsTbl = {
  ["("] = true,
  [")"] = true,
  ["["] = true,
  ["]"] = true,
  ["{"] = true,
  ["}"] = true,
  ['"'] = true,
  ["@"] = true,
  ["~"] = true,
  ["^"] = true,
  [";"] = true,
  ["`"] = true,
  ["#"] = true,
  ["'"] = true,
}

local invalidTokenTailCharsTbl = {
  ["("] = true,
  [")"] = true,
  ["["] = true,
  ["]"] = true,
  ["{"] = true,
  ["}"] = true,
  ['"'] = true,
  ["@"] = true,
  ["^"] = true,
  [";"] = true,
  ["`"] = true,
}

local function isValidTokenHeadChar(ch)
  return not whitespaceCharsTbl[ch] and not invalidTokenHeadCharsTbl[ch]
end

local function isValidTokenTailChar(ch)
  return not whitespaceCharsTbl[ch] and not invalidTokenTailCharsTbl[ch]
end

-- parses a Token character-by-character
local function tokenParser(txt, pos)
  local maxLength = strLen(txt)
  if maxLength == 0 then
    return nil
  end

  local charIdx = pos
  local endIdx = -1
  local keepSearching = true
  local parsedTxt = ""
  local firstChar = true

  local firstTwoChars = substr(txt, pos, inc(inc(pos)))
  if firstTwoChars == "##" then
    parsedTxt = "##"
    charIdx = inc(inc(charIdx))
  end

  while keepSearching do
    local ch = charAt(txt, charIdx)
    if ch == nil or ch == "" then
      keepSearching = false
    elseif firstChar then
      if isValidTokenHeadChar(ch) then
        parsedTxt = strConcat(parsedTxt, ch)
        endIdx = charIdx
        firstChar = false
      else
        return nil
      end
    elseif isValidTokenTailChar(ch) then
      parsedTxt = strConcat(parsedTxt, ch)
      endIdx = charIdx
    else
      keepSearching = false
    end

    charIdx = inc(charIdx)
    if charIdx > maxLength then
      keepSearching = false
    end
  end

  if endIdx > 0 then
    return Node({
      endIdx = inc(endIdx),
      name = "token",
      startIdx = pos,
      text = parsedTxt,
    })
  end

  return nil
end

local specialCharsTbl = {
  ["("] = true,
  [")"] = true,
  ["["] = true,
  ["]"] = true,
  ["{"] = true,
  ["}"] = true,
  ['"'] = true,
  ["@"] = true,
  ["^"] = true,
  [";"] = true,
  ["`"] = true,
  [","] = true,
  [" "] = true,
}

local function specialCharParser(txt, pos)
  local maxLength = strLen(txt)
  if maxLength == 0 then
    return nil
  end

  local firstChar = charAt(txt, pos)
  if firstChar == "\\" then
    local secondChar = charAt(txt, inc(pos))
    if specialCharsTbl[secondChar] then
      return Node({
        endIdx = inc(inc(pos)),
        name = "token",
        startIdx = pos,
        text = strConcat(firstChar, secondChar),
      })
    end
  end

  return nil
end

-- parses whitespace character-by-character
local function whitespaceParser(txt, pos)
  local maxLength = strLen(txt)
  if maxLength == 0 then
    return nil
  end

  local charIdx = pos
  local endIdx = -1
  local keepSearching = true
  local parsedTxt = ""

  while keepSearching do
    local ch = charAt(txt, charIdx)
    if ch == nil or ch == "" then
      keepSearching = false
    elseif whitespaceCharsTbl[ch] then
      parsedTxt = strConcat(parsedTxt, ch)
      endIdx = charIdx
    else
      keepSearching = false
    end

    charIdx = inc(charIdx)
    if charIdx > maxLength then
      keepSearching = false
    end
  end

  if endIdx > 0 then
    return Node({
      endIdx = inc(endIdx),
      name = "whitespace",
      startIdx = pos,
      text = parsedTxt,
    })
  end

  return nil
end

-- -----------------------------------------------------------------------------
-- Sequence Parsers

-- parser that matches a linear sequence of other parsers
local function Seq(opts)
  return {
    isTerminal = false,
    name = opts.name,
    parse = function(txt, pos)
      local children = {}
      local endIdx = pos
      local idx = 1
      local numParsers = arraySize(opts.parsers)
      while idx <= numParsers do
        local parser = opts.parsers[idx]
        local possibleNode = parser.parse(txt, endIdx)
        if possibleNode then
          appendChildren(children, possibleNode)
          endIdx = possibleNode.endIdx
        else
          -- else this is not a valid sequence: early return
          return nil
        end
        idx = inc(idx)
      end

      return Node({
        children = children,
        endIdx = endIdx,
        name = opts.name,
        startIdx = pos,
      })
    end,
  }
end

-- matches the first matching of several parsers
local function Choice(opts)
  return {
    parse = function(txt, pos)
      local idx = 1
      local numParsers = arraySize(opts.parsers)
      while idx <= numParsers do
        local parser = getParser(opts.parsers[idx])
        local possibleNode = parser.parse(txt, pos)
        if possibleNode then
          return possibleNode
        end
        idx = inc(idx)
      end
      return nil
    end,
  }
end

-- matches child parser zero or more times
local function Repeat(opts)
  return {
    parse = function(txt, pos)
      opts.parser = getParser(opts.parser)
      local minMatches = 0
      if isPositiveInt(opts.minMatches) then
        minMatches = opts.minMatches
      end
      local children = {}
      local endIdx = pos
      local lookForTheNextNode = true
      while lookForTheNextNode do
        local node = opts.parser.parse(txt, endIdx)
        if node then
          appendChildren(children, node)
          endIdx = node.endIdx
        else
          lookForTheNextNode = false
        end
      end
      local name2 = nil
      if isString(opts.name) and endIdx > pos then
        name2 = opts.name
      end
      if arraySize(children) >= minMatches then
        return Node({
          children = children,
          endIdx = endIdx,
          name = name2,
          startIdx = pos,
        })
      end
      return nil
    end,
  }
end

-- Parser that either matches a child parser or skips it
local function Optional(parser)
  return {
    parse = function(txt, pos)
      local node = parser.parse(txt, pos)
      if node and isString(node.text) and node.text ~= "" then
        return node
      else
        return Node({ startIdx = pos, endIdx = pos })
      end
    end,
  }
end

-- -----------------------------------------------------------------------------
-- Parser Helpers

function appendChildren(childrenArr, node)
  if isString(node.name) and node.name ~= "" then
    table.insert(childrenArr, node)
  elseif isArray(node.children) then
    local idx = 1
    local numChildren = arraySize(node.children)
    while idx <= numChildren do
      local child = node.children[idx]
      if child then
        appendChildren(childrenArr, child)
      end
      idx = inc(idx)
    end
  end
end

local parsers = {}

function getParser(p)
  if isString(p) and parsers[p] then
    return parsers[p]
  end
  if isTable(p) and isFunction(p.parse) then
    return p
  end
  return nil
end

-- -----------------------------------------------------------------------------
-- Parser Definitions

parsers.string = Seq({
  name = "string",
  parsers = {
    Pattern({ pattern = '%#?%"', name = ".open" }),
    -- NOTE: difference from Standard Clojure Style JavaScript here
    Optional({ parse = stringBodyParser }),
    Optional(Char({ char = '"', name = ".close" })),
  },
})

parsers.token = Choice({
  parsers = {
    { parse = specialCharParser },
    { parse = tokenParser },
  },
})

-- dev toggle
local usePatternWhitespaceParser = false

if usePatternWhitespaceParser then
  local whitespaceChars = ""
  for key, value in pairs(whitespaceCharsTbl) do
    whitespaceChars = whitespaceChars .. key
  end
  local whitespacePattern = escapePattern(whitespaceChars)
  parsers._ws = Pattern({ name = "whitespace", pattern = "[" .. whitespacePattern .. "]+" })
else
  parsers._ws = { name = "whitespace", parse = whitespaceParser }
end

parsers.comment = Pattern({ name = "comment", pattern = ";[^\n]*" })

parsers.discard = Seq({
  name = "discard",
  parsers = {
    String({ name = "marker", str = "#_" }),
    Repeat({ parser = "_gap" }),
    Named({ name = ".body", parser = "_form" }),
  },
})

parsers.braces = Seq({
  name = "braces",
  parsers = {
    Choice({
      parsers = {
        Char({ name = ".open", char = "{" }),
        String({ name = ".open", str = "#{" }),
        String({ name = ".open", str = "#::{" }),
        Pattern({ name = ".open", pattern = "%#%:%:?[a-zA-Z][a-zA-Z0-9%.%-%_]*%{" }),
      },
    }),
    Repeat({
      name = ".body",
      parser = Choice({ parsers = { "_gap", "_form", NotChar({ name = "error", char = "}" }) } }),
    }),
    Optional(Char({ name = ".close", char = "}" })),
  },
})

parsers.brackets = Seq({
  name = "brackets",
  parsers = {
    Char({ name = ".open", char = "[" }),
    Repeat({
      name = ".body",
      parser = Choice({ parsers = { "_gap", "_form", NotChar({ name = "error", char = "]" }) } }),
    }),
    Optional(Char({ name = ".close", char = "]" })),
  },
})

parsers.parens = Seq({
  name = "parens",
  parsers = {
    -- NOTE: difference from Standard Clojure Style JS here
    Choice({
      parsers = {
        Char({ name = ".open", char = "(" }),
        Pattern({ name = ".open", pattern = "%#%?%@%(" }),
        Pattern({ name = ".open", pattern = "%#%?%(" }),
        Pattern({ name = ".open", pattern = "%#%=%(" }),
        Pattern({ name = ".open", pattern = "%#%(" }),
      },
    }),
    Repeat({
      name = ".body",
      parser = Choice({ parsers = { "_gap", "_form", NotChar({ char = ")", name = "error" }) } }),
    }),
    Optional(Char({ name = ".close", char = ")" })),
  },
})

parsers._gap = Choice({ parsers = { "_ws", "comment", "discard" } })

parsers.meta = Seq({
  name = "meta",
  parsers = {
    Repeat({
      minMatches = 1,
      parser = Seq({
        parsers = {
          Pattern({ name = ".marker", pattern = "%#?%^" }),
          Repeat({ parser = "_gap" }),
          Named({ name = ".meta", parser = "_form" }),
          Repeat({ parser = "_gap" }),
        },
      }),
    }),
    Named({ name = ".body", parser = "_form" }),
  },
})

parsers.wrap = Seq({
  name = "wrap",
  parsers = {
    -- NOTE: difference from Standard Clojure Style JS here
    Choice({
      parsers = {
        Pattern({ name = ".marker", pattern = "%~%@" }),
        Pattern({ name = ".marker", pattern = "%#%'" }),
        Char({ name = ".marker", char = "@" }),
        Char({ name = ".marker", char = "'" }),
        Char({ name = ".marker", char = "`" }),
        Char({ name = ".marker", char = "~" }),
      },
    }),
    Repeat({ parser = "_gap" }),
    Named({ name = ".body", parser = "_form" }),
  },
})

parsers.tagged = Seq({
  name = "tagged",
  parsers = {
    Char({ char = "#" }),
    Repeat({ parser = "_gap" }),
    Named({ name = ".tag", parser = "token" }),
    Repeat({ parser = "_gap" }),
    Named({ name = ".body", parser = "_form" }),
  },
})

parsers._form = Choice({ parsers = { "token", "string", "parens", "brackets", "braces", "wrap", "meta", "tagged" } })

parsers.source = Repeat({
  name = "source",
  parser = Choice({ parsers = { "_gap", "_form", AnyChar({ name = "error" }) } }),
})

-- -----------------------------------------------------------------------------
-- Format Helpers

local function nodeContainsText(node)
  return node and isString(node.text) and node.text ~= ""
end

local function isNodeWithNonBlankText(node)
  return nodeContainsText(node) and charAt(node.text, 1) ~= " "
end

local function isNsNode(node)
  return node.name == "token" and node.text == "ns"
end

local function isRequireNode(node)
  return node and isString(node.text) and (node.text == ":require" or node.text == "require")
end

local function isRequireMacrosKeyword(node)
  return node and isString(node.text) and node.text == ":require-macros"
end

local function isReferClojureNode(node)
  return node and isString(node.text) and (node.text == ":refer-clojure" or node.text == "refer-clojure")
end

local function isExcludeKeyword(node)
  return node and isString(node.text) and node.text == ":exclude"
end

local function isOnlyKeyword(node)
  return node and isString(node.text) and node.text == ":only"
end

local function isRenameKeyword(node)
  return node and isString(node.text) and node.text == ":rename"
end

local function isAsKeyword(node)
  return node and isString(node.text) and node.text == ":as"
end

local function isAsAliasKeyword(node)
  return node and isString(node.text) and node.text == ":as-alias"
end

local function isReferKeyword(node)
  return node and isString(node.text) and node.text == ":refer"
end

local function isDefaultKeyword(node)
  return node and isString(node.text) and node.text == ":default"
end

local function isReferMacrosKeyword(node)
  return node and isString(node.text) and node.text == ":refer-macros"
end

local function isIncludeMacrosNode(node)
  return node and isString(node.text) and node.text == ":include-macros"
end

local function isBooleanNode(node)
  return node and isString(node.text) and (node.text == "true" or node.text == "false")
end

local function isAllNode(node)
  return node and isString(node.text) and node.text == ":all"
end

local function isKeywordNode(node)
  return node and isString(node.text) and strStartsWith(node.text, ":")
end

local function isImportNode(node)
  return node and isString(node.text) and (node.text == ":import" or node.text == "import")
end

local function isNewlineNode(n)
  return n.name == "whitespace" and isString(n.text) and strIncludes(n.text, "\n")
end

local function isWhitespaceNode(n)
  return n.name == "whitespace" or isNewlineNode(n)
end

local function isCommaNode(n)
  return n.name == "whitespace" and strIncludes(n.text, ",")
end

local parenOpenersTbl = {
  ["("] = true,
  ["["] = true,
  ["{"] = true,
  ["#{"] = true,
  ["#("] = true,
  ["#?("] = true,
  ["#?@("] = true,
}

local function isParenOpener(n)
  return n and n.name == ".open" and (parenOpenersTbl[n.text] or isNamespacedMapOpener(n))
end

local function isParenCloser(n)
  return n and n.name == ".close" and (n.text == ")" or n.text == "]" or n.text == "}")
end

local function isTokenNode(n)
  return n.name == "token"
end

local function isTagNode(n)
  return n.name == ".tag"
end

local function isStringNode(n)
  return n
    and n.name == "string"
    and isArray(n.children)
    and arraySize(n.children) == 3
    and n.children[2].name == ".body"
end

local function getTextFromStringNode(n)
  return n.children[2].text
end

local function isCommentNode(n)
  return n.name == "comment"
end

local function isReaderCommentNode(n)
  return n.name == "discard"
end

local function isDiscardNode(n)
  return n.name == "marker" and n.text == "#_"
end

local function isStandardCljIgnoreKeyword(n)
  return n.name == "token" and n.text == ":standard-clj/ignore"
end

local function isStandardCljIgnoreFileKeyword(n)
  return n.name == "token" and n.text == ":standard-clj/ignore-file"
end

local function nodeContainsTextAndNotWhitespace(n)
  return nodeContainsText(n) and not isWhitespaceNode(n)
end

local function isOneSpaceOpener(opener)
  -- TODO: also check node type here?
  return opener.text == "{" or opener.text == "["
end

local function isAnonFnOpener(opener)
  return opener.text == "#("
end

function isNamespacedMapOpener(opener)
  return opener.name == ".open" and strStartsWith(opener.text, "#:") and strEndsWith(opener.text, "{")
end

local function isReaderConditionalOpener(opener)
  return opener.text == "#?(" or opener.text == "#?@("
end

local function isOpeningBraceNode(n)
  return n.name == "braces"
    and isArray(n.children)
    and arraySize(n.children) == 3
    and n.children[3].name == ".close"
    and n.children[3].text == "}"
end

local function commentNeedsSpaceBefore(lineTxt, nodeTxt)
  return strStartsWith(nodeTxt, ";")
    and lineTxt ~= ""
    and not strEndsWith(lineTxt, " ")
    and not strEndsWith(lineTxt, "(")
    and not strEndsWith(lineTxt, "[")
    and not strEndsWith(lineTxt, "{")
end

local function commentNeedsSpaceInside(commentTxt)
  return not string.match(commentTxt, "^;+ ") and not string.match(commentTxt, "^;+$")
end

local function isGenClassNode(node)
  return node and isString(node.text) and node.text == ":gen-class"
end

local genClassKeywordsTbl = {
  [":name"] = true,
  [":extends"] = true,
  [":implements"] = true,
  [":init"] = true,
  [":constructors"] = true,
  [":post-init"] = true,
  [":methods"] = true,
  [":main"] = true,
  [":factory"] = true,
  [":state"] = true,
  [":exposes"] = true,
  [":exposes-methods"] = true,
  [":prefix"] = true,
  [":impl-ns"] = true,
  [":load-impl-ns"] = true,
}

local function isGenClassKeyword(node)
  return node and isString(node.text) and genClassKeywordsTbl[node.text]
end

local genClassKeys = {
  "name",
  "extends",
  "implements",
  "init",
  "constructors",
  "post-init",
  "methods",
  "main",
  "factory",
  "state",
  "exposes",
  "exposes-methods",
  "prefix",
  "impl-ns",
  "load-impl-ns",
}

-- these are all of the possible :gen-class keywords that should have a token value
-- FIXME: we need to confirm this is accurate for :extends, which should be a class name
local function isGenClassNameKey(keyTxt)
  return (
    keyTxt == "name"
    or keyTxt == "extends"
    or keyTxt == "init"
    or keyTxt == "post-init"
    or keyTxt == "factory"
    or keyTxt == "state"
    or keyTxt == "impl-ns"
  )
end

local function isGenClassBooleanKey(keyTxt)
  return (keyTxt == "main" or keyTxt == "load-impl-ns")
end

-- recursively runs function f on every node in the tree
local function recurseAllChildren(node, f)
  f(node)
  if node.children then
    local numChildren = arraySize(node.children)
    local idx = 1
    while idx <= numChildren do
      local childNode = node.children[idx]
      recurseAllChildren(childNode, f)
      idx = inc(idx)
    end
  end
  return nil
end

-- given a root node, returns a string of all the text found within its children
local function getTextFromRootNode(rootNode)
  local s = ""
  recurseAllChildren(rootNode, function(n)
    if isStringWithChars(n.text) then
      s = strConcat(s, n.text)
    end
  end)
  return s
end

-- given a root node, returns the last node that contains text from its children
local function getLastChildNodeWithText(rootNode)
  local lastNode = nil
  recurseAllChildren(rootNode, function(n)
    if isStringWithChars(n.text) then
      lastNode = n
    end
  end)
  return lastNode
end

-- returns a flat array of the nodes to print
local function flattenTree(tree)
  local nodes = {}
  local function pushNodeToNodes(node)
    table.insert(nodes, node)
  end
  recurseAllChildren(tree, pushNodeToNodes)
  return nodes
end

-- searches forward to find the next node that has non-empty text
-- returns the node if found, null otherwise
local function findNextNodeWithText(allNodes, idx)
  local maxIdx = arraySize(allNodes)
  while idx <= maxIdx do
    local node = allNodes[idx]
    if isString(node.text) and node.text ~= "" then
      return node
    end
    idx = inc(idx)
  end
  return null
end

-- searches forward to find the next node that can be the starting node of an ignore block
-- returns the node if found, null otherwise
local function findNextNonWhitespaceNode(allNodes, idx)
  local maxIdx = arraySize(allNodes)
  while idx <= maxIdx do
    local node = allNodes[idx]
    if not isWhitespaceNode(node) then
      return node
    end
    idx = inc(idx)
  end
  return null
end

-- searches backwards in the nodes array to find the previous node with non-empty text
-- note that this node must be before the startingNodeId argument
-- returns the node if found, null otherwise
-- TODO: this could be made into a generic "search backwards with predicate function" function
local function findPrevNodeWithText(allNodes, startIdx, startingNodeId)
  local keepSearching = true
  local idx = startIdx
  local beforeStartingNode = false
  while keepSearching do
    local node = allNodes[idx]
    if not beforeStartingNode then
      if node.id == startingNodeId then
        beforeStartingNode = true
      end
    else
      if nodeContainsText(node) then
        return node
      end
    end
    idx = dec(idx)
    if idx == 0 then
      keepSearching = false
    end
  end
  return null
end

-- searches forward in the nodes Array to find a node that returns true for predFn(node)
-- and is located after specificNodeId
-- returns the node if found, null otherwise
function findNextNodeWithPredicateAfterSpecificNode(allNodes, startIdx, predFn, specificNodeId)
  local maxIdx = arraySize(allNodes)
  local keepSearching = true
  local idx = startIdx
  local afterSpecificNode = false
  while keepSearching do
    local node = allNodes[idx]
    if not afterSpecificNode then
      if node.id == specificNodeId then
        afterSpecificNode = true
      end
    else
      if predFn(node) then
        return node
      end
    end
    idx = inc(idx)
    if idx >= maxIdx then
      keepSearching = false
    end
  end
  return null
end

-- searches backwards in the nodes Array to find a node that returns true for predFn(node)
-- returns the node if found, null otherwise
function findPrevNodeWithPredicate(allNodes, startIdx, predFn)
  local idx = startIdx
  while idx >= 0 do
    local node = allNodes[idx]
    if predFn(node) then
      return node
    end
    idx = dec(idx)
  end
  return null
end

-- Are all of the nodes on the next line already slurped up or whitespace nodes?
function areForwardNodesAlreadySlurped(nodes, idx)
  local nodesSize = arraySize(nodes)
  local result = true
  local keepSearching = true
  while keepSearching do
    local node = nodes[idx]
    if not node then
      keepSearching = false
    elseif isNewlineNode(node) then
      keepSearching = false
    elseif not isString(node.text) then
      keepSearching = true
    elseif node._wasSlurpedUp or isWhitespaceNode(node) then
      keepSearching = true
    else
      keepSearching = false
      result = false
    end

    idx = inc(idx)
    -- stop searching if we are at the end of the nodes list
    if idx > nodesSize then
      keepSearching = false
    end
  end
  return result
end

local function isNewlineNodeWithCommaOnNextLine(n)
  if n and isNewlineNode(n) then
    local tailStr = removeCharsUpToNewline(n.text)
    if strIncludes(tailStr, ",") then
      return true
    end
  end

  return false
end

-- Searches forward in the nodes array for closing paren nodes that could potentially
-- be slurped up to the current line. Includes whitespace and comment nodes as well.
-- returns an array of the nodes (possibly empty)
function findForwardClosingParens(nodes, idx)
  local closers = {}
  local nodesSize = arraySize(nodes)
  local keepSearching = true
  while keepSearching do
    local node = nodes[idx]

    if not node then
      keepSearching = false
    elseif isNewlineNodeWithCommaOnNextLine(node) then
      keepSearching = false
    elseif isWhitespaceNode(node) or isParenCloser(node) or isCommentNode(node) then
      table.insert(closers, node) -- Lua's equivalent of push
      keepSearching = true
    else
      keepSearching = false
    end

    idx = inc(idx)

    -- stop searching if we are at the end of the nodes list
    if idx > nodesSize then
      keepSearching = false
    end
  end

  return closers
end

function numSpacesAfterNewline(newlineNode)
  return strLen(removeCharsUpToNewline(newlineNode.text))
end

-- adds _origColIdx to the nodes on this line, stopping when we reach the next newline node
function recordOriginalColIndexes(nodes, idx)
  local initialSpaces = 0
  if isNewlineNode(nodes[idx]) then
    initialSpaces = numSpacesAfterNewline(nodes[idx])
    idx = inc(idx)
  end
  local colIdx = initialSpaces
  local numNodes = arraySize(nodes)
  local keepSearching = true
  while keepSearching do
    local node = nodes[idx]
    if not node then
      keepSearching = false
    elseif isNewlineNode(node) then
      keepSearching = false
    else
      local nodeTxt = node.text
      if isString(nodeTxt) and nodeTxt ~= "" then
        local nodeTxtLength = strLen(nodeTxt)
        node._origColIdx = colIdx
        colIdx = colIdx + nodeTxtLength
      end
    end
    idx = inc(idx)
    if idx > numNodes then
      keepSearching = false
    end
  end
  return nodes
end

local function removeLeadingWhitespace(txt)
  return rtrim(strReplaceFirst(txt, "^[, ]*\n+ *", "")) -- Lua pattern syntax
end

-- NOTE: this function does not remove newline characters because it only
-- needs to operates on a single line
local function removeTrailingWhitespace(txt)
  return string.gsub(txt, "[, ]*$", "")
end

function removeCharsUpToNewline(txt)
  local lastNewlineIdx = txt:reverse():find("\n")
  if lastNewlineIdx then
    lastNewlineIdx = #txt - lastNewlineIdx + 1
    return txt:sub(lastNewlineIdx + 1)
  else
    return txt
  end
end

local function txtHasCommasAfterNewline(s)
  return s:match("\n.*,.*$") ~= nil -- Lua's pattern matching instead of .test()
end

local function hasCommasAfterNewline(node)
  return isWhitespaceNode(node) and txtHasCommasAfterNewline(node.text)
end

-- Starting from idx, is the next line a line where there is only a comment and nothing else?
local function isNextLineACommentLine(nodes, idx)
  local n1 = nodes[idx]
  local n2 = nodes[inc(idx)]
  if n1 and n2 then
    return isCommentNode(n1) and isNewlineNode(n2)
  elseif n1 and not n2 then
    return isCommentNode(n1)
  else
    return false
  end
end

-- returns the number of spaces to use for indentation at the beginning of a line
local function numSpacesForIndentation(wrappingOpener)
  if not wrappingOpener then
    return 0
  else
    local nextNodeAfterOpener = wrappingOpener._nextWithText
    local openerTextLength = strLen(wrappingOpener.text)
    local openerColIdx = wrappingOpener._printedColIdx
    local directlyUnderneathOpener = openerColIdx + openerTextLength

    if isReaderConditionalOpener(wrappingOpener) then
      return directlyUnderneathOpener
    elseif nextNodeAfterOpener and isParenOpener(nextNodeAfterOpener) then
      return inc(openerColIdx)
    elseif isOneSpaceOpener(wrappingOpener) then
      return inc(openerColIdx)
    elseif isAnonFnOpener(wrappingOpener) then
      return openerColIdx + 3
    elseif isNamespacedMapOpener(wrappingOpener) then
      return openerColIdx + strLen(wrappingOpener.text)
    else
      -- else indent two spaces from the wrapping opener
      return inc(inc(openerColIdx))
    end
  end
end

-- -----------------------------------------------------------------------------
-- Parse Namespace

local function compareSymbolsThenPlatform(itmA, itmB)
  if itmA.symbol > itmB.symbol then
    return false
  elseif itmA.symbol < itmB.symbol then
    return true
  elseif itmA.symbol == itmB.symbol then
    if itmA.platform and not itmB.platform then
      return false
    elseif itmB.platform and not itmA.platform then
      return true
    elseif itmA.platform and itmB.platform then
      if itmA.platform > itmB.platform then
        return false
      elseif itmA.platform < itmB.platform then
        return true
      end
    end
  end

  return false
end

local function compareFromSymbol(itmA, itmB)
  if itmA.fromSymbol > itmB.fromSymbol then
    return false
  elseif itmA.fromSymbol < itmB.fromSymbol then
    return true
  else
    return false
  end
end

local function compareImports(importA, importB)
  if importA.package > importB.package then
    return false
  elseif importA.package < importB.package then
    return true
  else
    return false
  end
end

local function looksLikeAJavaClassname(s)
  local firstChar = string.sub(s, 1, 1)
  return string.upper(firstChar) == firstChar
end

local function parseJavaPackageWithClass(s)
  local chunks = {}
  for chunk in string.gmatch(s, "[^.]+") do
    table.insert(chunks, chunk)
  end
  local lastItm = chunks[#chunks]

  if looksLikeAJavaClassname(lastItm) then
    table.remove(chunks) -- remove last item
    local packageName = table.concat(chunks, ".")
    return {
      package = packageName,
      className = lastItm,
    }
  else
    return {
      package = s,
      className = nil,
    }
  end
end

-- returns the next token node inside a :require list / vector, starting from idx
-- returns nil if we reach a closing paren
-- FIXME: this will not work with metadata, comments, or reader conditionals
local function findNextTokenInsideRequireForm(nodes, idx)
  local result = nil
  local numNodes = arraySize(nodes)
  local keepSearching = true
  while keepSearching do
    local node = nodes[idx]
    if isParenCloser(node) then
      keepSearching = false
      result = nil
    elseif isTokenNode(node) and node.text ~= "" then
      keepSearching = false
      result = node
    end
    idx = inc(idx)
    if idx >= numNodes then
      keepSearching = false
    end
  end
  return result
end

local function sortNsResult(result, prefixListComments)
  -- sort :refer-clojure :exclude symbols
  if result.referClojure and isArray(result.referClojure.exclude) then
    table.sort(result.referClojure.exclude, compareSymbolsThenPlatform)
  end

  -- sort :refer-clojure :only symbols
  if result.referClojure and isArray(result.referClojure.only) then
    table.sort(result.referClojure.only, compareSymbolsThenPlatform)
  end

  -- sort :refer-clojure :rename symbols
  if result.referClojure and isArray(result.referClojure.rename) then
    table.sort(result.referClojure.rename, compareFromSymbol)
  end

  -- sort :require-macros symbols
  if isArray(result.requireMacros) then
    table.sort(result.requireMacros, compareSymbolsThenPlatform)

    -- sort :refer symbols
    local rmIdx = 0
    local numRequireMacrosResults = arraySize(result.requireMacros)
    while rmIdx < numRequireMacrosResults do
      if isArray(result.requireMacros[rmIdx + 1].refer) then
        table.sort(result.requireMacros[rmIdx + 1].refer, compareSymbolsThenPlatform)
      end
      rmIdx = inc(rmIdx)
    end
  end

  -- sort the requires symbols
  if isArray(result.requires) then
    table.sort(result.requires, compareSymbolsThenPlatform)

    local numRequires = arraySize(result.requires)
    local requiresIdx = 1
    while requiresIdx <= numRequires do
      local req = result.requires[requiresIdx]

      -- attach prefix list comments to the first require with the same id (if possible)
      if req.prefixListId then
        if prefixListComments[req.prefixListId] then
          if prefixListComments[req.prefixListId].commentsAbove then
            req.commentsAbove = prefixListComments[req.prefixListId].commentsAbove
          end
          if prefixListComments[req.prefixListId].commentAfter then
            req.commentAfter = prefixListComments[req.prefixListId].commentAfter
          end
          deleteObjKey(prefixListComments, req.prefixListId)
        end

        -- delete prefixListIds from the result
        deleteObjKey(req, "prefixListId")
      end

      -- sort :require :refer symbols
      if isArray(result.requires[requiresIdx].refer) then
        table.sort(result.requires[requiresIdx].refer, compareSymbolsThenPlatform)
      end

      -- sort :require :exclude symbols
      if isArray(result.requires[requiresIdx].exclude) then
        table.sort(result.requires[requiresIdx].exclude, compareSymbolsThenPlatform)
      end

      -- sort :require :rename symbols
      if isArray(result.requires[requiresIdx].rename) then
        table.sort(result.requires[requiresIdx].rename, compareFromSymbol)
      end

      requiresIdx = inc(requiresIdx)
    end
  end

  -- convert and sort the imports
  if result.importsObj then
    result.imports = {}

    objectForEach(result.importsObj, function(packageName, obj)
      local sortedClasses = obj.classes
      table.sort(sortedClasses)
      local importObj = {
        package = packageName,
        classes = sortedClasses,
      }

      if obj.commentsAbove then
        importObj.commentsAbove = obj.commentsAbove
      end
      if obj.commentAfter then
        importObj.commentAfter = obj.commentAfter
      end
      if obj.platform then
        importObj.platform = obj.platform
      end

      stackPush(result.imports, importObj)
    end)

    deleteObjKey(result, "importsObj")

    table.sort(result.imports, compareImports)
  end

  -- merge nsMetadata keys
  if isArray(result.nsMetadata) then
    local numMetadataItms = arraySize(result.nsMetadata)
    if numMetadataItms > 1 then
      local metadataObj = {}
      local metadataKeys = {}
      local idx = 1
      while idx <= numMetadataItms do
        local metadataItm = result.nsMetadata[idx]
        metadataObj[metadataItm.key] = metadataItm.value
        stackPush(metadataKeys, metadataItm.key)
        idx = inc(idx)
      end

      local newNsMetadata = {}
      local reverseIdx = dec(arraySize(metadataKeys))
      while reverseIdx >= 0 do
        local key2 = metadataKeys[reverseIdx + 1]

        if metadataObj[key2] then
          local metadataItm2 = {}
          metadataItm2.key = key2
          metadataItm2.value = metadataObj[key2]

          deleteObjKey(metadataObj, key2)
          stackPush(newNsMetadata, metadataItm2)
        end

        reverseIdx = dec(reverseIdx)
      end

      result.nsMetadata = arrayReverse(newNsMetadata)
    end
  end

  return result
end

-- search for a #_ :standard-clj/ignore-file
-- stopping when we reach the first (ns) form
local function lookForIgnoreFile(nodesArr)
  local keepSearching = true
  local numNodes = arraySize(nodesArr)
  local idx = 1
  while keepSearching do
    local node = nodesArr[idx]
    if isDiscardNode(node) then
      local next1 = findNextNodeWithPredicateAfterSpecificNode(nodesArr, idx, nodeContainsTextAndNotWhitespace, node.id)
      if isStandardCljIgnoreFileKeyword(next1) then
        return true
      elseif next1.text == "{" then
        local next2 =
          findNextNodeWithPredicateAfterSpecificNode(nodesArr, idx, nodeContainsTextAndNotWhitespace, next1.id)
        if isStandardCljIgnoreFileKeyword(next2) then
          local next3 =
            findNextNodeWithPredicateAfterSpecificNode(nodesArr, idx, nodeContainsTextAndNotWhitespace, next2.id)
          if next3.name == "token" and next3.text == "true" then
            return true
          end
        end
      end
    elseif isNsNode(node) then
      return false
    end
    idx = inc(idx)
    if idx > numNodes then
      keepSearching = false
    end
  end
  return false
end

-- Extracts namespace information from a flat array of Nodes.
-- Returns a data structure of the ns form that can be used to "print from scratch"
-- TODO: this function should accept a string and parse it into a flat node array
local function parseNs(nodesArr)
  local idx = 1
  local numNodes = arraySize(nodesArr)
  local result = {
    nsSymbol = nil,
  }
  local continueParsingNsForm = true
  local nsFormEndsLineIdx = -1
  local parenNestingDepth = 0
  local lineNo = 0
  local parenStack = {}
  local insideNsForm = false
  local insideReferClojureForm = false
  local referClojureParenNestingDepth = -1
  local insideRequireForm = false
  local requireFormParenNestingDepth = -1
  local requireFormLineNo = -1
  local insideImportForm = false
  local importFormLineNo = -1
  local nextTextNodeIsNsSymbol = false
  local insideImportPackageList = false
  local collectReferClojureExcludeSymbols = false
  local collectReferClojureOnlySymbols = false
  local collectReferClojureRenameSymbols = false
  local collectRequireExcludeSymbols = false
  local requireExcludeSymbolParenDepth = -1
  local renamesTmp = {}
  local importPackageListFirstToken = nil
  local nsNodeIdx = -1
  local nsSymbolIdx = -1
  local beyondNsMetadata = false
  local insideNsMetadataHashMap = false
  local insideNsMetadataShorthand = false
  local nextTokenNodeIsMetadataTrueKey = false
  local nextTextNodeIsMetadataKey = false
  local metadataValueNodeId = -1
  local tmpMetadataKey = ""
  local referClojureNodeIdx = -1
  local requireNodeIdx = -1
  local referIdx = -1
  local referParenNestingDepth = -1
  local importNodeIdx = -1
  local importNodeParenNestingDepth = -1
  local activeRequireIdx = -1
  local requireSymbolIdx = -1
  local nextTokenIsAsSymbol = false
  local singleLineComments = {}
  local activeImportPackageName = nil
  local prevNodeIsNewline = false
  local lineOfLastCommentRecording = -1
  local insidePrefixList = false
  local prefixListPrefix = nil
  local prefixListLineNo = -1
  local prefixListComments = {}
  local currentPrefixListId = nil
  local insideReaderConditional = false
  local currentReaderConditionalPlatform = nil
  local readerConditionalParenNestingDepth = -1
  local insideRequireList = false
  local requireListParenNestingDepth = -1
  local referMacrosIdx = -1
  local referMacrosParenNestingDepth = -1
  local insideIncludeMacros = false
  local activeRequireMacrosIdx = -1
  local insideRequireMacrosForm = false
  local requireMacrosNodeIdx = -1
  local requireMacrosLineNo = -1
  local requireMacrosParenNestingDepth = -1
  local requireMacrosReferNodeIdx = -1
  local requireMacrosAsNodeIdx = -1
  local requireMacrosRenameIdx = -1
  local genClassNodeIdx = -1
  local insideGenClass = false
  local genClassLineNo = -1
  local genClassToggle = 0
  local genClassKeyStr = nil
  local genClassValueLineNo = -1
  local insideReaderComment = false
  local idOfLastNodeInsideReaderComment = -1
  local requireRenameIdx = -1
  local skipNodesUntilWeReachThisId = -1
  local sectionToAttachEolCommentsTo = nil
  local nextTokenIsRequireDefaultSymbol = false

  while continueParsingNsForm do
    local node = nodesArr[idx]
    local currentNodeIsNewline = isNewlineNode(node)

    if parenNestingDepth == 1 and isNsNode(node) then
      insideNsForm = true
      nextTextNodeIsNsSymbol = true
      nsNodeIdx = idx
    elseif insideNsForm and isReferClojureNode(node) then
      insideReferClojureForm = true
      referClojureParenNestingDepth = parenNestingDepth
      sectionToAttachEolCommentsTo = "refer-clojure"
      referClojureNodeIdx = idx
      beyondNsMetadata = true
    elseif insideNsForm and isRequireNode(node) then
      insideRequireForm = true
      requireFormParenNestingDepth = parenNestingDepth
      requireFormLineNo = lineNo
      requireNodeIdx = idx
      beyondNsMetadata = true
      sectionToAttachEolCommentsTo = "require"
    elseif insideNsForm and isImportNode(node) then
      insideImportForm = true
      importFormLineNo = lineNo
      importNodeIdx = idx
      importNodeParenNestingDepth = parenNestingDepth
      beyondNsMetadata = true
      sectionToAttachEolCommentsTo = "import"
    elseif insideNsForm and isRequireMacrosKeyword(node) then
      insideRequireMacrosForm = true
      requireMacrosNodeIdx = idx
      requireMacrosLineNo = lineNo
      requireMacrosParenNestingDepth = parenNestingDepth
      beyondNsMetadata = true
      sectionToAttachEolCommentsTo = "require-macros"
    elseif insideNsForm and isGenClassNode(node) then
      insideGenClass = true
      genClassNodeIdx = idx
      beyondNsMetadata = true
      sectionToAttachEolCommentsTo = "gen-class"
    end

    if isParenOpener(node) then
      parenNestingDepth = inc(parenNestingDepth)
      stackPush(parenStack, node)
      if insideNsForm and isReaderConditionalOpener(node) then
        insideReaderConditional = true
        currentReaderConditionalPlatform = nil
        readerConditionalParenNestingDepth = parenNestingDepth
      elseif insideRequireForm then
        insideRequireList = true
        requireListParenNestingDepth = parenNestingDepth
      elseif insideImportForm and parenNestingDepth > importNodeParenNestingDepth then
        insideImportPackageList = true
      end
    elseif isParenCloser(node) then
      parenNestingDepth = dec(parenNestingDepth)
      stackPop(parenStack)

      -- TODO: should these be "elseif"s or just "if"s ?
      -- I think maybe they should be "if"s
      if insideImportPackageList then
        insideImportPackageList = false
        importPackageListFirstToken = nil
      elseif insideRequireForm and parenNestingDepth < requireFormParenNestingDepth then
        insideRequireForm = false
      elseif insideRequireList and parenNestingDepth < requireListParenNestingDepth then
        insideRequireList = false
        requireListParenNestingDepth = -1
        requireRenameIdx = -1
      elseif insideReferClojureForm and parenNestingDepth < referClojureParenNestingDepth then
        insideReferClojureForm = false
        referClojureNodeIdx = -1
      elseif insideNsForm and parenNestingDepth == 0 then
        -- We can assume there is only one ns form per file and exit the main
        -- loop once we have finished parsing it.
        insideNsForm = false
        nsFormEndsLineIdx = lineNo
      end

      if insideReferClojureForm and parenNestingDepth <= referClojureParenNestingDepth then
        collectReferClojureExcludeSymbols = false
        collectReferClojureOnlySymbols = false
        collectReferClojureRenameSymbols = false
      end

      if referIdx > 0 and parenNestingDepth < referParenNestingDepth then
        referIdx = -1
        referParenNestingDepth = -1
        nextTokenIsRequireDefaultSymbol = false
      end
      if insideRequireForm and requireSymbolIdx > 0 then
        requireSymbolIdx = -1
      end
      if insideRequireForm and insidePrefixList then
        insidePrefixList = false
        prefixListPrefix = nil
      end
      if insideReaderConditional and parenNestingDepth == dec(readerConditionalParenNestingDepth) then
        insideReaderConditional = false
        currentReaderConditionalPlatform = nil
        readerConditionalParenNestingDepth = -1
      end
      if idx > referMacrosIdx and parenNestingDepth <= referMacrosParenNestingDepth then
        referMacrosIdx = -1
        referMacrosParenNestingDepth = -1
      end
      if insideImportForm and parenNestingDepth < importNodeParenNestingDepth then
        insideImportForm = false
        importNodeIdx = -1
        importNodeParenNestingDepth = -1
      end
      if insideRequireMacrosForm and parenNestingDepth < requireMacrosParenNestingDepth then
        insideRequireMacrosForm = false
        requireMacrosParenNestingDepth = -1
        requireMacrosNodeIdx = -1
        requireMacrosAsNodeIdx = -1
      end
      if collectRequireExcludeSymbols and parenNestingDepth < requireExcludeSymbolParenDepth then
        collectRequireExcludeSymbols = false
        requireExcludeSymbolParenDepth = -1
      end
      requireMacrosReferNodeIdx = -1
      requireMacrosRenameIdx = -1
    end

    local isTokenNode2 = isTokenNode(node)
    local isTextNode = nodeContainsText(node)
    local isCommentNode2 = isCommentNode(node)
    local isReaderCommentNode2 = isReaderCommentNode(node)

    if isReaderCommentNode2 then
      insideReaderComment = true
      local lastNodeOfReaderComment = getLastChildNodeWithText(node)
      idOfLastNodeInsideReaderComment = lastNodeOfReaderComment.id
    end

    if skipNodesUntilWeReachThisId > 0 then
      if node.id == skipNodesUntilWeReachThisId then
        skipNodesUntilWeReachThisId = -1
      end

    -- collect ns metadata shorthand
    elseif insideNsMetadataShorthand then
      if node.name == ".marker" and node.text == "^" then
        nextTokenNodeIsMetadataTrueKey = true
      elseif nextTokenNodeIsMetadataTrueKey and isTokenNode2 then
        if not result.nsMetadata then
          result.nsMetadata = {}
        end
        local metadataObj = {}
        metadataObj.key = node.text
        metadataObj.value = "true"
        stackPush(result.nsMetadata, metadataObj)
        nextTokenNodeIsMetadataTrueKey = false
        insideNsMetadataShorthand = false
      end

    -- collect ns metadata inside a hash map literal
    elseif insideNsMetadataHashMap then
      if nextTextNodeIsMetadataKey and node.name == ".close" and node.text == "}" then
        insideNsMetadataHashMap = false
      elseif not nextTextNodeIsMetadataKey and node.name == ".open" and node.text == "{" then
        nextTextNodeIsMetadataKey = true
      elseif nextTextNodeIsMetadataKey and isTokenNode2 then
        if not result.nsMetadata then
          result.nsMetadata = {}
        end
        tmpMetadataKey = node.text
        nextTextNodeIsMetadataKey = false
        -- the next node should be a whitespace node, then collect the value for this key
        local nextNonWhitespaceNode = findNextNonWhitespaceNode(nodesArr, inc(idx))
        metadataValueNodeId = nextNonWhitespaceNode.id
      elseif node.id == metadataValueNodeId then
        local metadataObj = {}
        metadataObj.key = tmpMetadataKey
        metadataObj.value = getTextFromRootNode(node)
        stackPush(result.nsMetadata, metadataObj)
        tmpMetadataKey = ""
        nextTextNodeIsMetadataKey = true
        metadataValueNodeId = -1
        -- skip any forward nodes that we have just collected as text
        if isArray(node.children) then
          local lastChildNode = arrayLast(node.children)
          skipNodesUntilWeReachThisId = lastChildNode.id
        end
      end

    -- collect ns metadata before we hit the nsSymbol
    elseif
      not insideNsMetadataHashMap
      and not insideNsMetadataShorthand
      and insideNsForm
      and nsSymbolIdx < 0
      and node.name == "meta"
    then
      local markerNode = findNextNodeWithText(nodesArr, inc(idx))
      -- NOTE: this should always be true
      if markerNode.text == "^" then
        local nodeAfterMarker = findNextNodeWithText(nodesArr, inc(inc(idx)))
        if nodeAfterMarker and nodeAfterMarker.text == "{" then
          insideNsMetadataHashMap = true
        elseif nodeAfterMarker and isTokenNode(nodeAfterMarker) then
          insideNsMetadataShorthand = true
        end
      end

    -- collect metadata hash map after the ns symbol
    elseif
      insideNsForm
      and idx > nsNodeIdx
      and parenNestingDepth >= 1
      and not beyondNsMetadata
      and not insideReaderComment
      and not insideNsMetadataShorthand
      and not insideNsMetadataHashMap
      and node.name == ".open"
      and node.text == "{"
    then
      insideNsMetadataHashMap = true
      nextTextNodeIsMetadataKey = true

    -- collect the ns symbol
    elseif idx > nsNodeIdx and nextTextNodeIsNsSymbol and isTokenNode2 and isTextNode then
      result.nsSymbol = node.text
      nsSymbolIdx = idx
      nextTextNodeIsNsSymbol = false

    -- collect reader conditional platform keyword
    elseif
      insideReaderConditional
      and parenNestingDepth == readerConditionalParenNestingDepth
      and isKeywordNode(node)
    then
      currentReaderConditionalPlatform = node.text

    -- collect single-line comments
    elseif insideNsForm and idx > nsNodeIdx and prevNodeIsNewline and isCommentNode2 then
      stackPush(singleLineComments, node.text)

    -- collect reader macro comment line(s)
    elseif insideNsForm and idx > nsNodeIdx and prevNodeIsNewline and isReaderCommentNode2 then
      stackPush(singleLineComments, getTextFromRootNode(node))

    -- collect comments at the end of a line
    elseif idx > nsNodeIdx and not prevNodeIsNewline and (isCommentNode2 or isReaderCommentNode2) then
      local commentAtEndOfLine = nil
      if isCommentNode2 then
        commentAtEndOfLine = node.text
      else
        commentAtEndOfLine = getTextFromRootNode(node)
      end

      if prefixListLineNo == lineNo then
        if not prefixListComments[currentPrefixListId] then
          prefixListComments[currentPrefixListId] = {}
        end
        prefixListComments[currentPrefixListId].commentAfter = commentAtEndOfLine
        lineOfLastCommentRecording = lineNo
      elseif requireFormLineNo == lineNo and activeRequireIdx < 0 then
        result.requireCommentAfter = commentAtEndOfLine
        lineOfLastCommentRecording = lineNo
      elseif requireFormLineNo == lineNo and activeRequireIdx >= 1 then
        result.requires[activeRequireIdx].commentAfter = commentAtEndOfLine
        lineOfLastCommentRecording = lineNo
      elseif sectionToAttachEolCommentsTo == "refer-clojure" and result.referClojure then
        result.referClojureCommentAfter = commentAtEndOfLine
        lineOfLastCommentRecording = lineNo
      elseif importFormLineNo == lineNo and not result.importsObj then
        result.importCommentAfter = commentAtEndOfLine
        lineOfLastCommentRecording = lineNo
      elseif importFormLineNo == lineNo then
        result.importsObj[activeImportPackageName].commentAfter = commentAtEndOfLine
        lineOfLastCommentRecording = lineNo
      elseif requireMacrosLineNo == lineNo then
        result.requireMacros[activeRequireMacrosIdx].commentAfter = commentAtEndOfLine
        lineOfLastCommentRecording = lineNo
      elseif genClassLineNo == lineNo then
        result.genClass.commentAfter = commentAtEndOfLine
        lineOfLastCommentRecording = lineNo
      elseif genClassValueLineNo == lineNo then
        result.genClass[genClassKeyStr].commentAfter = commentAtEndOfLine
        lineOfLastCommentRecording = lineNo
      end

      if not insideNsForm and lineNo == lineOfLastCommentRecording then
        result.commentOutsideNsForm = commentAtEndOfLine
      end

    -- discard nodes that are inside a reader comment
    elseif insideReaderComment then
      if node.id == idOfLastNodeInsideReaderComment then
        insideReaderComment = false
        idOfLastNodeInsideReaderComment = -1
      end

    -- attach comments to the :require form
    elseif insideRequireForm and idx == requireNodeIdx and arraySize(singleLineComments) > 0 then
      result.requireCommentsAbove = singleLineComments
      singleLineComments = {}

    -- attach comments to the :import form
    elseif insideImportForm and idx == importNodeIdx and arraySize(singleLineComments) > 0 then
      result.importCommentsAbove = singleLineComments
      singleLineComments = {}

    -- attach comments to the :refer-clojure form
    elseif insideReferClojureForm and idx == referClojureNodeIdx and arraySize(singleLineComments) > 0 then
      result.referClojureCommentsAbove = singleLineComments
      singleLineComments = {}

    -- collect the docstring
    elseif
      insideNsForm
      and idx > nsNodeIdx
      and parenNestingDepth == 1
      and not beyondNsMetadata
      and not insideNsMetadataShorthand
      and not insideNsMetadataHashMap
      and isStringNode(node)
    then
      result.docstring = getTextFromStringNode(node)

    -- collect :refer-clojure :exclude
    elseif insideReferClojureForm and idx > referClojureNodeIdx and isExcludeKeyword(node) then
      if not result.referClojure then
        result.referClojure = {}
      end
      if not isArray(result.referClojure.exclude) then
        result.referClojure.exclude = {}
      end
      collectReferClojureExcludeSymbols = true

    -- collect :refer-clojure :exclude symbols
    elseif
      idx > inc(referClojureNodeIdx)
      and collectReferClojureExcludeSymbols
      and parenNestingDepth >= 3
      and isTokenNode2
      and isTextNode
      and result.referClojure
      and isArray(result.referClojure.exclude)
    then
      local symbolObj = {}
      symbolObj.symbol = node.text

      if insideReaderConditional and currentReaderConditionalPlatform then
        symbolObj.platform = currentReaderConditionalPlatform
      end

      stackPush(result.referClojure.exclude, symbolObj)

    -- collect :refer-clojure :only
    elseif insideReferClojureForm and idx > referClojureNodeIdx and isOnlyKeyword(node) then
      if not result.referClojure then
        result.referClojure = {}
      end
      result.referClojure.only = {}
      collectReferClojureOnlySymbols = true

    -- collect :refer-clojure :only symbols
    elseif
      idx > inc(referClojureNodeIdx)
      and collectReferClojureOnlySymbols
      and parenNestingDepth >= 3
      and isTokenNode2
      and isTextNode
      and result.referClojure
      and isArray(result.referClojure.only)
    then
      local symbolObj = {
        symbol = node.text,
      }

      -- add reader conditional platform if necessary
      if insideReaderConditional and currentReaderConditionalPlatform then
        symbolObj.platform = currentReaderConditionalPlatform
      end

      stackPush(result.referClojure.only, symbolObj)

    -- collect :refer-clojure :rename
    elseif insideReferClojureForm and idx > referClojureNodeIdx and isRenameKeyword(node) then
      if not result.referClojure then
        result.referClojure = {}
      end
      result.referClojure.rename = {}
      collectReferClojureRenameSymbols = true

    -- collect :refer-clojure :rename symbols
    elseif
      idx > inc(referClojureNodeIdx)
      and collectReferClojureRenameSymbols
      and parenNestingDepth >= 3
      and isTokenNode2
      and isTextNode
      and result.referClojure
      and isArray(result.referClojure.rename)
    then
      stackPush(renamesTmp, node.text)

      if arraySize(renamesTmp) == 2 then
        local itm = {}
        itm.fromSymbol = renamesTmp[1]
        itm.toSymbol = renamesTmp[2]

        if insideReaderConditional and currentReaderConditionalPlatform then
          itm.platform = currentReaderConditionalPlatform
        end

        stackPush(result.referClojure.rename, itm)

        renamesTmp = {}
      end

    -- is this :require :as ?
    elseif idx > requireNodeIdx and insideRequireForm and isTokenNode2 and isAsKeyword(node) then
      nextTokenIsAsSymbol = true

    -- collect the require :as symbol
    elseif idx > requireNodeIdx and insideRequireForm and nextTokenIsAsSymbol and isTokenNode2 and isTextNode then
      nextTokenIsAsSymbol = false
      result.requires[activeRequireIdx].as = node.text

    -- collect :require-macros :refer symbols
    elseif
      insideRequireMacrosForm
      and requireMacrosReferNodeIdx ~= -1
      and idx > requireMacrosReferNodeIdx
      and isTokenNode2
      and isTextNode
    then
      if not isArray(result.requireMacros[activeRequireMacrosIdx].refer) then
        result.requireMacros[activeRequireMacrosIdx].refer = {}
      end

      local referObj = {}
      referObj.symbol = node.text

      if insideReaderConditional and currentReaderConditionalPlatform then
        referObj.platform = currentReaderConditionalPlatform
      end

      stackPush(result.requireMacros[activeRequireMacrosIdx].refer, referObj)

    -- collect :require-macros :as symbol
    elseif
      insideRequireMacrosForm
      and requireMacrosAsNodeIdx ~= -1
      and idx > requireMacrosAsNodeIdx
      and isTokenNode2
      and isTextNode
    then
      result.requireMacros[activeRequireMacrosIdx].as = node.text
      requireMacrosAsNodeIdx = -1

    -- collect :require-macros :rename
    elseif
      insideRequireMacrosForm
      and requireMacrosRenameIdx ~= -1
      and idx > requireMacrosRenameIdx
      and isTokenNode2
      and isTextNode
    then
      if not isArray(result.requireMacros[activeRequireMacrosIdx].rename) then
        result.requireMacros[activeRequireMacrosIdx].rename = {}
      end

      stackPush(renamesTmp, node.text)

      if arraySize(renamesTmp) == 2 then
        local itm = {}
        itm.fromSymbol = renamesTmp[1]
        itm.toSymbol = renamesTmp[2]
        if insideReaderConditional and currentReaderConditionalPlatform then
          itm.platform = currentReaderConditionalPlatform
        end
        stackPush(result.requireMacros[activeRequireMacrosIdx].rename, itm)
        renamesTmp = {}
      end

    -- :require-macros :refer
    elseif insideRequireMacrosForm and idx > requireMacrosNodeIdx and isReferKeyword(node) then
      requireMacrosReferNodeIdx = idx

    -- :require-macros :as
    elseif insideRequireMacrosForm and idx > requireMacrosNodeIdx and isAsKeyword(node) then
      requireMacrosAsNodeIdx = idx

    -- :require-macros :rename
    elseif insideRequireMacrosForm and idx > requireMacrosNodeIdx and isRenameKeyword(node) then
      requireMacrosRenameIdx = idx
      renamesTmp = {}

    -- collect :require-macros symbol
    elseif insideRequireMacrosForm and idx > requireMacrosNodeIdx and isTokenNode2 and isTextNode then
      if not result.requireMacros then
        result.requireMacros = {}

        -- add commentsAbove to the :require-macros form if possible
        if arraySize(singleLineComments) > 0 then
          result.requireMacrosCommentsAbove = singleLineComments
          singleLineComments = {}
        end
      end

      local reqObj = {
        symbol = node.text,
      }

      -- store the comments above this line
      if arraySize(singleLineComments) > 0 then
        reqObj.commentsAbove = singleLineComments
        singleLineComments = {}
      end

      -- add reader conditional platform
      if insideReaderConditional and currentReaderConditionalPlatform then
        reqObj.platform = currentReaderConditionalPlatform
      end

      stackPush(result.requireMacros, reqObj)
      if activeRequireMacrosIdx < 0 then
        activeRequireMacrosIdx = 1
      else
        activeRequireMacrosIdx = inc(activeRequireMacrosIdx)
      end
      requireMacrosLineNo = lineNo

    -- is this :include-macros ?
    elseif idx > requireNodeIdx and insideRequireForm and isTokenNode2 and isIncludeMacrosNode(node) then
      insideIncludeMacros = true

    -- collect :include-macros boolean
    elseif insideIncludeMacros and isTokenNode2 and isBooleanNode(node) then
      if node.text == "true" then
        result.requires[activeRequireIdx].includeMacros = true
      else
        result.requires[activeRequireIdx].includeMacros = false
      end

      insideIncludeMacros = false

    -- is this :refer-macros ?
    elseif idx > requireNodeIdx and insideRequireForm and isTokenNode2 and isReferMacrosKeyword(node) then
      referMacrosIdx = idx
      referMacrosParenNestingDepth = parenNestingDepth

    -- collect :refer-macros symbols
    elseif
      idx > referMacrosIdx
      and insideRequireForm
      and parenNestingDepth == inc(referMacrosParenNestingDepth)
      and isTokenNode2
      and isTextNode
    then
      if not isArray(result.requires[activeRequireIdx].referMacros) then
        result.requires[activeRequireIdx].referMacros = {}
      end
      stackPush(result.requires[activeRequireIdx].referMacros, node.text)

    -- is this :require :refer ?
    elseif idx > requireNodeIdx and insideRequireForm and isTokenNode2 and isReferKeyword(node) then
      referIdx = idx
      referParenNestingDepth = parenNestingDepth

    -- is this :require :default ?
    elseif idx > requireNodeIdx and insideRequireForm and isTokenNode2 and isDefaultKeyword(node) then
      nextTokenIsRequireDefaultSymbol = true

    -- collect :require :exclude symbols
    elseif
      idx > requireNodeIdx
      and insideRequireForm
      and isTokenNode2
      and collectRequireExcludeSymbols
      and parenNestingDepth > requireExcludeSymbolParenDepth
    then
      local symbolObj = {
        symbol = node.text,
      }
      stackPush(result.requires[activeRequireIdx].exclude, symbolObj)

    -- is this :require :exclude ?
    elseif idx > requireNodeIdx and insideRequireForm and isTokenNode2 and isExcludeKeyword(node) then
      result.requires[activeRequireIdx].exclude = {}
      collectRequireExcludeSymbols = true
      requireExcludeSymbolParenDepth = parenNestingDepth

    -- :require :as-alias
    elseif idx > requireNodeIdx and insideRequireForm and isTokenNode2 and isAsAliasKeyword(node) then
      local nextSymbol = findNextTokenInsideRequireForm(nodesArr, inc(idx))
      result.requires[activeRequireIdx].asAlias = nextSymbol.text

    -- collect :refer :all
    elseif idx > referIdx and insideRequireForm and isTokenNode2 and isAllNode(node) then
      result.requires[activeRequireIdx].refer = "all"

    -- collect :refer :default symbol
    elseif idx > referIdx and insideRequireForm and isTokenNode2 and nextTokenIsRequireDefaultSymbol then
      result.requires[activeRequireIdx].default = node.text
      nextTokenIsRequireDefaultSymbol = false

    -- collect :require :refer symbols
    elseif
      idx > referIdx
      and insideRequireForm
      and parenNestingDepth == inc(referParenNestingDepth)
      and isTokenNode2
      and isTextNode
    then
      if not isArray(result.requires[activeRequireIdx].refer) then
        result.requires[activeRequireIdx].refer = {}
      end
      local referObj = {
        symbol = node.text,
      }
      stackPush(result.requires[activeRequireIdx].refer, referObj)

    -- collect :require symbol not inside of a list / vector
    elseif
      insideRequireForm
      and not insideRequireList
      and idx > requireNodeIdx
      and isTokenNode2
      and isTextNode
      and requireSymbolIdx == -1
      and not isKeywordNode(node)
    then
      if not isArray(result.requires) then
        result.requires = {}
      end

      local requireObj = {
        symbol = node.text,
      }
      stackPush(result.requires, requireObj)
      if activeRequireIdx < 0 then
        activeRequireIdx = 1
      else
        activeRequireIdx = inc(activeRequireIdx)
      end
      requireFormLineNo = lineNo

      -- attach comments from the lines above this require
      if arraySize(singleLineComments) > 0 then
        result.requires[activeRequireIdx].commentsAbove = singleLineComments
        singleLineComments = {}
      end

      -- add platform if we are inside a Reader Conditional
      if insideReaderConditional and currentReaderConditionalPlatform then
        result.requires[activeRequireIdx].platform = currentReaderConditionalPlatform
      end

    -- collect symbols inside of a prefix list
    elseif insidePrefixList and isTokenNode2 and isTextNode then
      if not isArray(result.requires) then
        result.requires = {}
      end

      local namespace = strConcat3(prefixListPrefix, ".", node.text)

      local requireObj = {
        prefixListId = currentPrefixListId,
        symbol = namespace,
      }
      stackPush(result.requires, requireObj)
      if activeRequireIdx < 0 then
        activeRequireIdx = 1
      else
        activeRequireIdx = inc(activeRequireIdx)
      end
      requireSymbolIdx = idx
      requireFormLineNo = lineNo
      insidePrefixList = true

    -- collect :require renames
    elseif
      insideRequireForm
      and insideRequireList
      and requireRenameIdx > 0
      and idx > requireRenameIdx
      and isTokenNode2
      and isTextNode
    then
      stackPush(renamesTmp, node.text)

      if arraySize(renamesTmp) == 2 then
        local itm = {}
        itm.fromSymbol = renamesTmp[1]
        itm.toSymbol = renamesTmp[2]

        if insideReaderConditional and currentReaderConditionalPlatform then
          itm.platform = currentReaderConditionalPlatform
        end

        if not isArray(result.requires[activeRequireIdx].rename) then
          result.requires[activeRequireIdx].rename = {}
        end

        stackPush(result.requires[activeRequireIdx].rename, itm)

        renamesTmp = {}
      end

    -- collect :require symbol inside of a list / vector
    elseif
      insideRequireForm
      and insideRequireList
      and idx > requireNodeIdx
      and isTokenNode2
      and isTextNode
      and requireSymbolIdx == -1
      and not isKeywordNode(node)
    then
      if not isArray(result.requires) then
        result.requires = {}
      end

      -- five possibilities for a :require import:
      -- - require symbol not inside of list / vector
      -- - require symbol inside a list / vector, followed by nothing
      -- - require symbol for a prefix list (need to examine the following symbols in order to know this)
      -- - require symbol followed by :as
      -- - require symbol followed by :refer

      local nextTokenInsideRequireForm = findNextTokenInsideRequireForm(nodesArr, inc(idx))
      local isPrefixList = nextTokenInsideRequireForm and not isKeywordNode(nextTokenInsideRequireForm)

      if isPrefixList then
        local prefixListId = createId()
        insidePrefixList = true
        prefixListLineNo = lineNo
        prefixListPrefix = node.text
        currentPrefixListId = prefixListId

        -- store the comments above this line
        -- we will attach them to the first ns imported by this prefix list later
        if arraySize(singleLineComments) > 0 then
          local itm = {
            commentsAbove = singleLineComments,
          }
          prefixListComments[prefixListId] = itm
          singleLineComments = {}
        end
      else
        local requireObj = {
          symbol = node.text,
        }
        stackPush(result.requires, requireObj)
        if activeRequireIdx < 0 then
          activeRequireIdx = 1
        else
          activeRequireIdx = inc(activeRequireIdx)
        end
        requireSymbolIdx = idx
        requireFormLineNo = lineNo
        insidePrefixList = false
        prefixListLineNo = -1

        -- attach comments from the lines above this require
        if arraySize(singleLineComments) > 0 then
          result.requires[activeRequireIdx].commentsAbove = singleLineComments
          singleLineComments = {}
        end

        -- add platform if we are inside a Reader Conditional
        if insideReaderConditional and currentReaderConditionalPlatform then
          result.requires[activeRequireIdx].platform = currentReaderConditionalPlatform
        end
      end

    -- :rename inside require
    elseif insideRequireForm and insideRequireList and idx > requireNodeIdx and isRenameKeyword(node) then
      requireRenameIdx = idx
      renamesTmp = {}

    -- collect require Strings in ClojureScript
    elseif insideRequireForm and insideRequireList and idx > requireNodeIdx and isStringNode(node) then
      if not isArray(result.requires) then
        result.requires = {}
      end

      local requireObj = {}
      stackPush(result.requires, requireObj)
      if activeRequireIdx < 0 then
        activeRequireIdx = 1
      else
        activeRequireIdx = inc(activeRequireIdx)
      end
      requireFormLineNo = lineNo

      -- attach comments from the lines above this require
      if arraySize(singleLineComments) > 0 then
        result.requires[activeRequireIdx].commentsAbove = singleLineComments
        singleLineComments = {}
      end

      -- add platform if we are inside a Reader Conditional
      if insideReaderConditional and currentReaderConditionalPlatform then
        result.requires[activeRequireIdx].platform = currentReaderConditionalPlatform
      end

      result.requires[activeRequireIdx].symbol = strConcat3('"', getTextFromStringNode(node), '"')
      result.requires[activeRequireIdx].symbolIsString = true

    -- collect :import packages not inside of a list or vector
    elseif insideImportForm and idx > importNodeIdx and not insideImportPackageList and isTokenNode2 and isTextNode then
      if not result.importsObj then
        result.importsObj = {}
      end

      local packageParsed = parseJavaPackageWithClass(node.text)
      local packageName = packageParsed.package
      local className = packageParsed.className

      if not result.importsObj[packageName] then
        result.importsObj[packageName] = {
          classes = {},
        }
      end

      stackPush(result.importsObj[packageName].classes, className)
      activeImportPackageName = packageName
      importFormLineNo = lineNo

      if arraySize(singleLineComments) > 0 then
        result.importsObj[packageName].commentsAbove = singleLineComments
        singleLineComments = {}
      end

      -- add platform if we are inside a Reader Conditional
      if insideReaderConditional and currentReaderConditionalPlatform then
        result.importsObj[packageName].platform = currentReaderConditionalPlatform
      end

    -- collect :import classes inside of a list or vector
    elseif insideImportPackageList and isTokenNode2 and isTextNode then
      if not importPackageListFirstToken then
        local packageName = node.text
        importPackageListFirstToken = packageName
        activeImportPackageName = packageName
        importFormLineNo = lineNo

        if not result.importsObj then
          result.importsObj = {}
        end

        if not result.importsObj[packageName] then
          result.importsObj[packageName] = {
            classes = {},
          }
        end

        if arraySize(singleLineComments) > 0 then
          result.importsObj[packageName].commentsAbove = singleLineComments
          singleLineComments = {}
        end

        -- add platform if we are inside a Reader Conditional
        if insideReaderConditional and currentReaderConditionalPlatform then
          result.importsObj[packageName].platform = currentReaderConditionalPlatform
        end
      else
        stackPush(result.importsObj[importPackageListFirstToken].classes, node.text)
      end

    -- we are on the :gen-class node
    elseif insideGenClass and idx == genClassNodeIdx then
      result.genClass = {}
      result.genClass.isEmpty = true

      -- add platform if we are inside a Reader Conditional
      if insideReaderConditional and currentReaderConditionalPlatform then
        result.genClass.platform = currentReaderConditionalPlatform
      end

      -- add commentsAbove
      if arraySize(singleLineComments) > 0 then
        result.genClass.commentsAbove = singleLineComments
        singleLineComments = {}
      end

      genClassLineNo = lineNo

    -- :gen-class key like :main, :name, :state, :init, etc
    elseif
      insideGenClass
      and idx > genClassNodeIdx
      and isTextNode
      and genClassToggle == 0
      and isGenClassKeyword(node)
    then
      result.genClass.isEmpty = false

      genClassKeyStr = string.sub(node.text, 2, -1)
      result.genClass[genClassKeyStr] = {}

      -- add commentsAbove if possible
      if arraySize(singleLineComments) > 0 then
        result.genClass[genClassKeyStr].commentsAbove = singleLineComments
        singleLineComments = {}
      end

      -- genClassToggle = 0 means we are looking for a key
      -- genClassToggle = 1 means we are looking for a value
      genClassToggle = 1

    -- :gen-class :prefix value
    elseif
      insideGenClass
      and idx > genClassNodeIdx
      and genClassToggle == 1
      and genClassKeyStr == "prefix"
      and isStringNode(node)
    then
      result.genClass.prefix.value = strConcat3('"', getTextFromStringNode(node), '"')
      genClassToggle = 0
      genClassValueLineNo = lineNo

    -- other :gen-class values
    elseif insideGenClass and idx > genClassNodeIdx and isTextNode and isTokenNode2 and genClassToggle == 1 then
      -- :name, :extends, :init, :post-init, :factory, :state, :impl-ns
      if isGenClassNameKey(genClassKeyStr) then
        result.genClass[genClassKeyStr].value = node.text
        genClassToggle = 0
        genClassValueLineNo = lineNo
      -- :main, :load-impl-ns
      elseif isGenClassBooleanKey(genClassKeyStr) then
        if node.text == "true" then
          result.genClass[genClassKeyStr].value = true
          genClassToggle = 0
          genClassValueLineNo = lineNo
        elseif node.text == "false" then
          result.genClass[genClassKeyStr].value = false
          genClassToggle = 0
          genClassValueLineNo = lineNo
        else
          -- FIXME: throw here? this is almost certainly an error in the source
        end
      end
      -- FIXME: we need to handle :implements, :constructors, :methods, :exposes, :exposes-methods, here
    end

    -- increment the lineNo for the next node if we are on a newline node
    -- NOTE: this lineNo variable does not account for newlines inside of multi-line strings
    -- but we can ignore that for the purposes of ns parsing here
    if currentNodeIsNewline then
      lineNo = inc(lineNo)
    end
    prevNodeIsNewline = currentNodeIsNewline

    -- increment to look at the next node
    idx = inc(idx)

    -- exit if we are at the end of the nodes
    if idx > numNodes then
      continueParsingNsForm = false

    -- exit if we have finished parsing the ns form
    elseif nsNodeIdx > 0 and not insideNsForm and lineNo >= inc(inc(nsFormEndsLineIdx)) then
      continueParsingNsForm = false
    end
  end -- end main ns parsing parsing node loop

  return sortNsResult(result, prefixListComments)
end

-- -----------------------------------------------------------------------------
-- Formatter

-- adds the lines from a commentsAbove array to outTxt if possible
-- returns outTxt (String)
local function printCommentsAbove(outTxt, commentsAbove, indentationStr)
  if isArray(commentsAbove) then
    local numCommentLines = arraySize(commentsAbove)
    local idx = 1
    while idx <= numCommentLines do
      local commentLine = strConcat(indentationStr, commentsAbove[idx])
      outTxt = strConcat3(outTxt, commentLine, "\n")
      idx = inc(idx)
    end
  end
  return outTxt
end

-- returns a sorted array of platform strings found on items in arr
local function getPlatformsFromArray(arr)
  local hasDefault = false
  local platforms = {}
  local numItms = arraySize(arr)
  local idx = 1
  while idx <= numItms do
    local itm = arr[idx]
    if itm.platform then
      if itm.platform == ":default" then
        hasDefault = true
      else
        platforms[itm.platform] = true
      end
    end
    idx = inc(idx)
  end

  local platformsArr = {}
  objectForEach(platforms, function(platformStr, _ignore)
    stackPush(platformsArr, platformStr)
  end)

  table.sort(platformsArr)

  if hasDefault then
    stackPush(platformsArr, ":default")
  end

  return platformsArr
end

-- returns true if there are only one require per platform
-- this lets us use the standard reader conditional #?( instead of
-- the splicing reader conditional #?@(
local function onlyOneRequirePerPlatform(reqs)
  local platformCounts = {}
  local numReqs = arraySize(reqs)
  local idx = 0
  local keepSearching = true
  local result = true
  while keepSearching do
    if reqs[idx + 1] and reqs[idx + 1].platform and isString(reqs[idx + 1].platform) then
      local platform = reqs[idx + 1].platform
      if platform ~= "" then
        if platformCounts[platform] then
          keepSearching = false
          result = false
        else
          platformCounts[platform] = 1
        end
      end
    end
    idx = inc(idx)
    if idx > numReqs then
      keepSearching = false
    end
  end
  return result
end

-- Returns an array of Objects filtered on the .platform key
function filterOnPlatform(arr, platform)
  local filteredReqs = {}
  local idx = 0
  local numReqs = arraySize(arr)
  while idx < numReqs do
    local itm = arr[idx + 1]
    if platform == false and not itm.platform then
      stackPush(filteredReqs, itm)
    elseif isString(itm.platform) and itm.platform == platform then
      stackPush(filteredReqs, arr[idx + 1])
    end
    idx = inc(idx)
  end
  return filteredReqs
end

function formatRequireLine(req, initialIndentation)
  local outTxt = ""
  outTxt = printCommentsAbove(outTxt, req.commentsAbove, initialIndentation)
  outTxt = strConcat(outTxt, initialIndentation)
  outTxt = strConcat3(outTxt, "[", req.symbol)
  if isString(req.as) and req.as ~= "" then
    outTxt = strConcat3(outTxt, " :as ", req.as)
  elseif isString(req.asAlias) and req.asAlias ~= "" then
    outTxt = strConcat3(outTxt, " :as-alias ", req.asAlias)
  elseif isString(req.default) and req.default ~= "" then
    outTxt = strConcat3(outTxt, " :default ", req.default)
  end

  -- NOTE: this will not work if the individual :refer symbols are wrapped in a reader conditional
  if isArray(req.refer) and arraySize(req.refer) > 0 then
    outTxt = strConcat(outTxt, " :refer [")
    local referSymbols = arrayPluck(req.refer, "symbol")
    outTxt = strConcat(outTxt, strJoin(referSymbols, " "))
    outTxt = strConcat(outTxt, "]")
  elseif req.refer == "all" then
    outTxt = strConcat(outTxt, " :refer :all")
  end
  -- NOTE: this will not work if the individual :exclude symbols are wrapped in a reader conditional
  if isArray(req.exclude) and arraySize(req.exclude) > 0 then
    outTxt = strConcat(outTxt, " :exclude [")
    local excludeSymbols = arrayPluck(req.exclude, "symbol")
    outTxt = strConcat(outTxt, strJoin(excludeSymbols, " "))
    outTxt = strConcat(outTxt, "]")
  end
  if req.includeMacros == true then
    outTxt = strConcat(outTxt, " :include-macros true")
  elseif req.includeMacros == false then
    outTxt = strConcat(outTxt, " :include-macros false")
  end
  if isArray(req.referMacros) and arraySize(req.referMacros) > 0 then
    outTxt = strConcat(outTxt, " :refer-macros [")
    outTxt = strConcat(outTxt, strJoin(req.referMacros, " "))
    outTxt = strConcat(outTxt, "]")
  end
  if isArray(req.rename) and arraySize(req.rename) > 0 then
    outTxt = strConcat(outTxt, " :rename {")
    outTxt = strConcat(outTxt, formatRenamesList(req.rename))
    outTxt = strConcat(outTxt, "}")
  end
  outTxt = strConcat(outTxt, "]")
  return outTxt
end

-- returns an array of the available :refer-clojure keys
-- valid options are: :exclude, :only, :rename
local function getReferClojureKeys(referClojure)
  local keys = {}
  if referClojure then
    if referClojure.exclude then
      stackPush(keys, ":exclude")
    end
    if referClojure.only then
      stackPush(keys, ":only")
    end
    if referClojure.rename then
      stackPush(keys, ":rename")
    end
  end
  return keys
end

local function formatKeywordFollowedByListOfSymbols(kwd, symbols)
  local s = strConcat(kwd, " [")
  s = strConcat(s, strJoin(symbols, " "))
  s = strConcat(s, "]")
  return s
end

function formatRenamesList(itms)
  local s = ""
  local numItms = arraySize(itms)
  local idx = 0
  while idx < numItms do
    s = strConcat(s, itms[idx + 1].fromSymbol)
    s = strConcat(s, " ")
    s = strConcat(s, itms[idx + 1].toSymbol)
    if inc(idx) < numItms then
      s = strConcat(s, ", ")
    end
    idx = inc(idx)
  end
  return s
end

local function formatReferClojureSingleKeyword(ns, excludeOrOnly)
  local symbolsArr = ns.referClojure[excludeOrOnly]
  local kwd = strConcat(":", excludeOrOnly)
  local platforms = getPlatformsFromArray(symbolsArr)
  local numPlatforms = arraySize(platforms)
  local symbolsForAllPlatforms = arrayPluck(filterOnPlatform(symbolsArr, false), "symbol")
  local numSymbolsForAllPlatforms = arraySize(symbolsForAllPlatforms)
  -- there are no reader conditionals: print all of the symbols
  if numPlatforms == 0 then
    local s = "\n"
    s = printCommentsAbove(s, ns.referClojureCommentsAbove, "  ")
    s = strConcat(s, "  (:refer-clojure ")
    s = strConcat(s, formatKeywordFollowedByListOfSymbols(kwd, symbolsForAllPlatforms))
    s = strConcat(s, ")")
    return s
    -- all symbols are for a single platform: wrap the entire (:refer-clojure) in a single reader conditional
  elseif numPlatforms == 1 and numSymbolsForAllPlatforms == 0 then
    local symbols2 = arrayPluck(symbolsArr, "symbol")
    local s = strConcat3("\n  #?(", platforms[1], "\n")
    s = printCommentsAbove(s, ns.referClojureCommentsAbove, "     ")
    s = strConcat(s, "     (:refer-clojure ")
    s = strConcat(s, formatKeywordFollowedByListOfSymbols(kwd, symbols2))
    s = strConcat(s, "))")
    return s
    -- all symbols are for specific platforms, ie: every symbol is wrapped in a reader conditional
  elseif numPlatforms > 1 and numSymbolsForAllPlatforms == 0 then
    local s = "\n"
    s = printCommentsAbove(s, ns.referClojureCommentsAbove, "  ")
    s = strConcat(s, "  (:refer-clojure\n")
    s = strConcat3(s, "    ", kwd)
    s = strConcat(s, " #?@(")
    local platformIdx = 0
    while platformIdx < numPlatforms do
      local platform = platforms[platformIdx + 1]
      local symbolsForPlatform = arrayPluck(filterOnPlatform(symbolsArr, platform), "symbol")
      s = strConcat(s, formatKeywordFollowedByListOfSymbols(platform, symbolsForPlatform))
      if inc(platformIdx) ~= numPlatforms then
        if kwd == ":exclude" then
          s = strConcat3(s, "\n", repeatString(" ", 17))
        elseif kwd == ":only" then
          s = strConcat3(s, "\n", repeatString(" ", 14))
        else
          -- FIXME: throw error here?
        end
      end
      platformIdx = inc(platformIdx)
    end
    s = strConcat(s, "))")
    return s
    -- we have a mix of symbols for all platforms and some for specific platforms
  else
    local s = "\n"
    s = printCommentsAbove(s, ns.referClojureCommentsAbove, "  ")
    s = strConcat(s, "  (:refer-clojure\n")
    s = strConcat3(s, "    ", kwd)
    s = strConcat(s, " [")
    s = strConcat(s, strJoin(symbolsForAllPlatforms, " "))
    if kwd == ":exclude" then
      s = strConcat3(s, "\n", repeatString(" ", 14))
    elseif kwd == ":only" then
      s = strConcat3(s, "\n", repeatString(" ", 11))
    else
      -- FIXME: throw error here?
    end
    s = strConcat(s, "#?@(")
    local platformIdx = 0
    while platformIdx < numPlatforms do
      local platform = platforms[platformIdx + 1]
      local symbolsForPlatform = arrayPluck(filterOnPlatform(symbolsArr, platform), "symbol")
      s = strConcat(s, formatKeywordFollowedByListOfSymbols(platform, symbolsForPlatform))
      if inc(platformIdx) ~= numPlatforms then
        if kwd == ":exclude" then
          s = strConcat3(s, "\n", repeatString(" ", 18))
        elseif kwd == ":only" then
          s = strConcat3(s, "\n", repeatString(" ", 15))
        end
      end
      platformIdx = inc(platformIdx)
    end
    s = strConcat(s, ")])")
    return s
  end
end

local function formatReferClojure(ns)
  local keys = getReferClojureKeys(ns.referClojure)
  local numKeys = arraySize(keys)
  -- there are no :refer-clojure items, we are done
  if numKeys == 0 then
    return ""

  -- there is only :exclude
  elseif numKeys == 1 and keys[1] == ":exclude" then
    return formatReferClojureSingleKeyword(ns, "exclude")

  -- there is only :only
  elseif numKeys == 1 and keys[1] == ":only" then
    return formatReferClojureSingleKeyword(ns, "only")

  -- there is only :rename
  elseif numKeys == 1 and keys[1] == ":rename" then
    local platforms = getPlatformsFromArray(ns.referClojure.rename)
    local numPlatforms = arraySize(platforms)
    local nonPlatformSpecificRenames = filterOnPlatform(ns.referClojure.rename, false)
    local numNonPlatformSpecificRenames = arraySize(nonPlatformSpecificRenames)
    local allRenamesForSamePlatform = numNonPlatformSpecificRenames == 0 and arraySize(platforms) > 0

    if numPlatforms == 0 then
      local s = "\n"
      s = printCommentsAbove(s, ns.referClojureCommentsAbove, "  ")
      s = strConcat(s, "  (:refer-clojure :rename {")
      s = strConcat(s, formatRenamesList(ns.referClojure.rename))
      s = strConcat(s, "})")
      return s
    elseif numPlatforms == 1 and allRenamesForSamePlatform then
      local s = strConcat3("\n  #?(", platforms[1], "\n")
      s = printCommentsAbove(s, ns.referClojureCommentsAbove, "     ")
      s = strConcat(s, "     (:refer-clojure :rename {")
      s = strConcat(s, formatRenamesList(ns.referClojure.rename))
      s = strConcat(s, "}))")
      return s
    else
      local s = "\n  (:refer-clojure\n    :rename {"
      s = strConcat(s, formatRenamesList(nonPlatformSpecificRenames))
      s = strConcat(s, "\n             #?@(")

      local platformIdx = 0
      while platformIdx < numPlatforms do
        local platformStr = platforms[platformIdx + 1]
        local platformRenames = filterOnPlatform(ns.referClojure.rename, platformStr)

        if platformIdx == 0 then
          s = strConcat3(s, platformStr, " [")
        else
          s = strConcat(s, "\n                 ")
          s = strConcat3(s, platformStr, " [")
        end
        s = strConcat(s, formatRenamesList(platformRenames))
        s = strConcat(s, "]")

        platformIdx = inc(platformIdx)
      end

      s = strConcat(s, ")})")

      return s
    end

  -- there are multiple keys, put each one on it's own line
  else
    local s = "\n  (:refer-clojure"

    if ns.referClojure.exclude and arraySize(ns.referClojure.exclude) > 0 then
      local excludeSymbols = arrayPluck(ns.referClojure.exclude, "symbol")
      s = strConcat(s, "\n    ")
      s = strConcat(s, formatKeywordFollowedByListOfSymbols(":exclude", excludeSymbols))
    end

    if ns.referClojure.only and arraySize(ns.referClojure.only) > 0 then
      local onlySymbols = arrayPluck(ns.referClojure.only, "symbol")
      s = strConcat(s, "\n    ")
      s = strConcat(s, formatKeywordFollowedByListOfSymbols(":only", onlySymbols))
    end

    if ns.referClojure.rename and arraySize(ns.referClojure.rename) > 0 then
      s = strConcat(s, "\n    :rename {")
      s = strConcat(s, formatRenamesList(ns.referClojure.rename))
      s = strConcat(s, "}")
    end

    s = strConcat(s, ")")
    return s

    -- FIXME - I need to create some tests cases for this
    -- return 'FIXME: handle reader conditionals for multiple :refer-clojure keys'
  end
end

local function formatNs(ns)
  local outTxt = strConcat("(ns ", ns.nsSymbol)

  local numRequireMacros = 0
  if isArray(ns.requireMacros) then
    numRequireMacros = arraySize(ns.requireMacros)
  end

  local numRequires = 0
  if isArray(ns.requires) then
    numRequires = arraySize(ns.requires)
  end

  local numImports = 0
  if isArray(ns.imports) then
    numImports = arraySize(ns.imports)
  end

  local commentOutsideNsForm2 = nil
  local hasGenClass = not not ns.genClass
  local importsIsLastMainForm = numImports > 0 and not hasGenClass
  local requireIsLastMainForm = numRequires > 0 and not importsIsLastMainForm and not hasGenClass
  local requireMacrosIsLastMainForm = numRequireMacros > 0 and numRequires == 0 and numImports == 0 and not hasGenClass
  local referClojureIsLastMainForm = ns.referClojure
    and numRequireMacros == 0
    and numRequires == 0
    and numImports == 0
    and not hasGenClass
  local trailingParensArePrinted = false

  if isString(ns.docstring) then
    outTxt = strConcat(outTxt, '\n  "')
    outTxt = strConcat(outTxt, ns.docstring)
    outTxt = strConcat(outTxt, '"')
  end

  if isArray(ns.nsMetadata) then
    local numMetadataItms = arraySize(ns.nsMetadata)
    if numMetadataItms > 0 then
      local metadataItmsIdx = 0
      outTxt = strConcat(outTxt, "\n  {")
      while metadataItmsIdx < numMetadataItms do
        local metadataItm = ns.nsMetadata[metadataItmsIdx + 1] -- Lua arrays are 1-based
        outTxt = strConcat3(outTxt, metadataItm.key, " ")
        outTxt = strConcat(outTxt, metadataItm.value)
        metadataItmsIdx = inc(metadataItmsIdx)
        if metadataItmsIdx ~= numMetadataItms then
          outTxt = strConcat(outTxt, "\n   ")
        end
      end
      outTxt = strConcat(outTxt, "}")
    end
  end

  -- FIXME - we need reader conditionals for :refer-clojure here
  if ns.referClojure then
    outTxt = strConcat(outTxt, formatReferClojure(ns))

    if isStringWithChars(ns.referClojureCommentAfter) then
      if referClojureIsLastMainForm then
        commentOutsideNsForm2 = ns.referClojureCommentAfter
      else
        outTxt = strConcat3(outTxt, " ", ns.referClojureCommentAfter)
      end
    end
  end

  if numRequireMacros > 0 then
    local cljsPlatformRequireMacros = filterOnPlatform(ns.requireMacros, ":cljs")
    local wrapRequireMacrosWithReaderConditional = arraySize(cljsPlatformRequireMacros) == numRequireMacros
    local rmLastLineCommentAfter = nil

    local rmIndentation = "   "
    if wrapRequireMacrosWithReaderConditional then
      outTxt = strConcat(outTxt, "\n")
      outTxt = strConcat(outTxt, "  #?(:cljs\n")
      outTxt = printCommentsAbove(outTxt, ns.requireMacrosCommentsAbove, "     ")
      outTxt = strConcat(outTxt, "     (:require-macros\n")

      rmIndentation = "      "
    else
      outTxt = strConcat(outTxt, "\n")
      outTxt = printCommentsAbove(outTxt, ns.requireMacrosCommentsAbove, "  ")
      outTxt = strConcat(outTxt, "  (:require-macros\n")
    end

    local rmIdx = 0
    while rmIdx < numRequireMacros do
      local rm = ns.requireMacros[rmIdx + 1] -- Lua arrays are 1-based
      local isLastRequireMacroLine = inc(rmIdx) == numRequireMacros
      outTxt = strConcat(outTxt, formatRequireLine(rm, rmIndentation))
      if isStringWithChars(rm.commentAfter) then
        if isLastRequireMacroLine then
          rmLastLineCommentAfter = rm.commentAfter
        else
          outTxt = strConcat3(outTxt, " ", rm.commentAfter)
        end
      end
      if not isLastRequireMacroLine then
        outTxt = strConcat(outTxt, "\n")
      end
      rmIdx = inc(rmIdx)
    end

    if not requireMacrosIsLastMainForm and not wrapRequireMacrosWithReaderConditional then
      outTxt = strConcat(outTxt, ")")
    elseif not requireMacrosIsLastMainForm and wrapRequireMacrosWithReaderConditional then
      outTxt = strConcat(outTxt, "))")
    elseif requireMacrosIsLastMainForm and not wrapRequireMacrosWithReaderConditional then
      outTxt = strConcat(outTxt, "))")
      trailingParensArePrinted = true
    elseif requireMacrosIsLastMainForm and wrapRequireMacrosWithReaderConditional then
      outTxt = strConcat(outTxt, ")))")
      trailingParensArePrinted = true
    end

    if isStringWithChars(rmLastLineCommentAfter) then
      outTxt = strConcat3(outTxt, " ", rmLastLineCommentAfter)
    end
  end

  if numRequires > 0 then
    local closeRequireParenTrail = ")"
    local lastRequireHasComment = false
    local lastRequireComment = nil
    local reqPlatforms = getPlatformsFromArray(ns.requires)
    local numPlatforms = arraySize(reqPlatforms)

    local allRequiresUnderOnePlatform = false
    if numPlatforms == 1 then
      local onePlatformRequires = filterOnPlatform(ns.requires, reqPlatforms[1])
      if numRequires == arraySize(onePlatformRequires) then
        allRequiresUnderOnePlatform = true
      end
    end

    local requireLineIndentation = "   "
    if allRequiresUnderOnePlatform then
      outTxt = strConcat(outTxt, "\n  #?(")
      outTxt = strConcat(outTxt, reqPlatforms[1])

      if isArray(ns.requireCommentsAbove) and arraySize(ns.requireCommentsAbove) > 0 then
        outTxt = strConcat(outTxt, "\n     ")
        outTxt = strConcat(outTxt, strJoin(ns.requireCommentsAbove, "\n     "))
      end

      outTxt = strConcat(outTxt, "\n     (:require")
      if isString(ns.requireCommentAfter) and ns.requireCommentAfter ~= "" then
        outTxt = strConcat3(outTxt, " ", ns.requireCommentAfter)
      end
      outTxt = strConcat(outTxt, "\n")

      requireLineIndentation = "      "
    else
      if isArray(ns.requireCommentsAbove) and arraySize(ns.requireCommentsAbove) > 0 then
        outTxt = strConcat(outTxt, "\n  ")
        outTxt = strConcat(outTxt, strJoin(ns.requireCommentsAbove, "\n  "))
      end
      outTxt = strConcat(outTxt, "\n  (:require\n")
    end

    local requiresIdx = 0
    while requiresIdx < numRequires do
      local req = ns.requires[requiresIdx + 1] -- Lua arrays are 1-based
      -- NOTE: I am not sure this works correctly with reader conditionals
      local isLastRequire1 = inc(requiresIdx) == numRequires

      if not req.platform or allRequiresUnderOnePlatform then
        outTxt = strConcat(outTxt, formatRequireLine(req, requireLineIndentation))

        if req.commentAfter and not isLastRequire1 then
          outTxt = strConcat(outTxt, " ")
          outTxt = strConcat(outTxt, req.commentAfter)
          outTxt = strConcat(outTxt, "\n")
        elseif isLastRequire1 and req.commentAfter and requireIsLastMainForm and not allRequiresUnderOnePlatform then
          closeRequireParenTrail = strConcat(")) ", req.commentAfter)
          trailingParensArePrinted = true
        elseif isLastRequire1 and req.commentAfter and allRequiresUnderOnePlatform then
          lastRequireComment = req.commentAfter
          lastRequireHasComment = true
        elseif isLastRequire1 and req.commentAfter then
          closeRequireParenTrail = strConcat(") ", req.commentAfter)
        elseif isLastRequire1 and not req.commentAfter then
          closeRequireParenTrail = ")"
        else
          outTxt = strConcat(outTxt, "\n")
        end
      end

      requiresIdx = inc(requiresIdx)
    end

    local platformIdx = 0

    local requireBlockHasReaderConditionals = numPlatforms > 0
    local useStandardReaderConditional = onlyOneRequirePerPlatform(ns.requires)

    if not allRequiresUnderOnePlatform then
      -- use standard reader conditional #?(
      if useStandardReaderConditional then
        while platformIdx < numPlatforms do
          local platform = reqPlatforms[platformIdx + 1]

          if platformIdx == 0 then
            outTxt = strTrim(outTxt)
            outTxt = strConcat3(outTxt, "\n   #?(", platform)
            outTxt = strConcat(outTxt, " ")
          else
            outTxt = strConcat(outTxt, "\n      ")
            outTxt = strConcat3(outTxt, platform, " ")
          end

          -- only look at requires for this platform
          local platformRequires = filterOnPlatform(ns.requires, platform)
          local req = platformRequires[1]
          outTxt = strConcat(outTxt, formatRequireLine(req, ""))

          -- FIXME: need to add commentsBefore and commentsAfter here

          platformIdx = inc(platformIdx)
        end
        -- use splicing reader conditional #?@(
      else
        while platformIdx < numPlatforms do
          local platform = reqPlatforms[platformIdx + 1]
          local isLastPlatform = inc(platformIdx) == numPlatforms

          if platformIdx == 0 then
            outTxt = strTrim(outTxt)
            outTxt = strConcat(outTxt, "\n   #?@(")
            outTxt = strConcat3(outTxt, platform, "\n       [")
          else
            outTxt = strConcat(outTxt, "\n\n       ")
            outTxt = strConcat3(outTxt, platform, "\n       [")
          end

          -- only look at requires for this platform
          local platformRequires = filterOnPlatform(ns.requires, platform)
          local numFilteredReqs = arraySize(platformRequires)
          local printedFirstReqLine = false
          local printPlatformClosingBracket = true
          local reqIdx2 = 0
          while reqIdx2 < numFilteredReqs do
            local req = platformRequires[reqIdx2 + 1]
            local isLastRequireForThisPlatform = inc(reqIdx2) == numFilteredReqs

            if printedFirstReqLine then
              outTxt = strConcat(outTxt, formatRequireLine(req, "        "))
            else
              printedFirstReqLine = true
              outTxt = strConcat(outTxt, formatRequireLine(req, ""))
            end

            if req.commentAfter and not isLastRequireForThisPlatform then
              outTxt = strConcat(outTxt, " ")
              outTxt = strConcat(outTxt, req.commentAfter)
              outTxt = strConcat(outTxt, "\n")
            elseif req.commentAfter and isLastRequireForThisPlatform and not isLastPlatform then
              outTxt = strConcat3(outTxt, "] ", req.commentAfter)
              printPlatformClosingBracket = false
            elseif req.commentAfter and isLastRequireForThisPlatform and (isLastPlatform or requireIsLastMainForm) then
              lastRequireHasComment = true
              lastRequireComment = req.commentAfter
            elseif isLastRequireForThisPlatform and req.commentAfter then
              closeRequireParenTrail = strConcat(") ", req.commentAfter)
            elseif isLastRequireForThisPlatform and not req.commentAfter then
              closeRequireParenTrail = "]"
            else
              outTxt = strConcat(outTxt, "\n")
            end

            reqIdx2 = inc(reqIdx2)
          end

          if printPlatformClosingBracket then
            outTxt = strConcat(outTxt, "]")
          end

          platformIdx = inc(platformIdx)
        end
      end
    end

    -- closeRequireParenTrail can be one of six options:
    -- - )             <-- no reader conditional, no comment on the last item, not the last main form
    -- - ) <comment>   <-- no reader conditional, comment on the last itm, not the last main form
    -- - ))            <-- reader conditional, no comment on the last itm, not the last main form
    -- - )) <comment>  <-- reader conditional, comment on last itm, not the last main form
    -- - )))           <-- reader conditional, no comment on last itm, :require is last main form
    -- - ))) <comment> <-- reader conditional, comment on last itm, :require is last main form
    if not requireBlockHasReaderConditionals and not lastRequireHasComment and not requireIsLastMainForm then
      closeRequireParenTrail = ")"
    elseif not requireBlockHasReaderConditionals and lastRequireHasComment and not requireIsLastMainForm then
      closeRequireParenTrail = strConcat(") ", lastRequireComment)
    elseif requireBlockHasReaderConditionals and not lastRequireHasComment and not requireIsLastMainForm then
      closeRequireParenTrail = "))"
    elseif requireBlockHasReaderConditionals and lastRequireHasComment and not requireIsLastMainForm then
      closeRequireParenTrail = strConcat(")) ", lastRequireComment)
    elseif requireBlockHasReaderConditionals and not lastRequireHasComment and requireIsLastMainForm then
      closeRequireParenTrail = ")))"
      trailingParensArePrinted = true
    elseif requireBlockHasReaderConditionals and lastRequireHasComment and requireIsLastMainForm then
      closeRequireParenTrail = strConcat("))) ", lastRequireComment)
      trailingParensArePrinted = true
    end

    outTxt = strTrim(outTxt)
    outTxt = strConcat(outTxt, closeRequireParenTrail)
  end -- end :require printing

  if numImports > 0 then
    -- collect imports that are platform-specific (or not)
    local nonPlatformSpecificImports = filterOnPlatform(ns.imports, false)
    local numNonPlatformSpecificImports = arraySize(nonPlatformSpecificImports)
    local importPlatforms = getPlatformsFromArray(ns.imports)
    local numImportPlatforms = arraySize(importPlatforms)

    local lastImportLineCommentAfter = nil
    local isImportKeywordPrinted = false

    local importsIdx = 0
    while importsIdx < numNonPlatformSpecificImports do
      if not isImportKeywordPrinted then
        outTxt = strConcat(outTxt, "\n  (:import\n")
        isImportKeywordPrinted = true
      end

      local imp = nonPlatformSpecificImports[importsIdx + 1]
      local isLastImport = inc(importsIdx) == numNonPlatformSpecificImports

      outTxt = strConcat3(outTxt, "   (", imp.package)

      local numClasses = arraySize(imp.classes)
      local classNameIdx = 0
      while classNameIdx < numClasses do
        local className = imp.classes[classNameIdx + 1]
        outTxt = strConcat3(outTxt, " ", className)

        classNameIdx = inc(classNameIdx)
      end

      outTxt = strConcat(outTxt, ")")

      if isStringWithChars(imp.commentAfter) then
        outTxt = strConcat3(outTxt, " ", imp.commentAfter)
      end

      if not isLastImport then
        outTxt = strConcat(outTxt, "\n")
      end

      importsIdx = inc(importsIdx)
    end

    local platformIdx = 0
    local isFirstPlatform = true
    local importSectionHasReaderConditionals = numImportPlatforms > 0
    local placeReaderConditionalOutsideOfImport = numImportPlatforms == 1 and numNonPlatformSpecificImports == 0

    while platformIdx < numImportPlatforms do
      local platformStr = importPlatforms[platformIdx + 1]

      if placeReaderConditionalOutsideOfImport then
        outTxt = strConcat(outTxt, "\n  #?(")
        outTxt = strConcat(outTxt, platformStr)
        outTxt = strConcat(outTxt, "\n")
        outTxt = strConcat(outTxt, "     (:import\n")
        outTxt = strConcat(outTxt, "      ")
        isImportKeywordPrinted = true
      elseif isFirstPlatform then
        if not isImportKeywordPrinted then
          outTxt = strConcat(outTxt, "\n  (:import")
          isImportKeywordPrinted = true
        end
        outTxt = strConcat3(outTxt, "\n   #?@(", platformStr)
        outTxt = strConcat(outTxt, "\n       [")
        isFirstPlatform = false
      else
        outTxt = strConcat3(outTxt, "\n\n       ", platformStr)
        outTxt = strConcat(outTxt, "\n       [")
      end

      local importsForThisPlatform = filterOnPlatform(ns.imports, platformStr)
      local idx2 = 0
      local numImports2 = arraySize(importsForThisPlatform)
      while idx2 < numImports2 do
        local imp = importsForThisPlatform[idx2 + 1]
        local isLastImport2 = inc(idx2) == numImports2

        outTxt = strConcat(outTxt, "(")
        outTxt = strConcat(outTxt, imp.package)
        outTxt = strConcat(outTxt, " ")
        outTxt = strConcat(outTxt, strJoin(imp.classes, " "))
        outTxt = strConcat(outTxt, ")")

        if isLastImport2 then
          if not placeReaderConditionalOutsideOfImport then
            outTxt = strConcat(outTxt, "]")
          end
          if isStringWithChars(imp.commentAfter) then
            lastImportLineCommentAfter = imp.commentAfter
          end
        else
          if isStringWithChars(imp.commentAfter) then
            outTxt = strConcat3(outTxt, " ", imp.commentAfter)
          end
          if placeReaderConditionalOutsideOfImport then
            outTxt = strConcat(outTxt, "\n      ")
          else
            outTxt = strConcat(outTxt, "\n        ")
          end
        end

        idx2 = inc(idx2)
      end

      platformIdx = inc(platformIdx)
    end

    local closeImportParenTrail = ")"
    if importsIsLastMainForm and importSectionHasReaderConditionals then
      closeImportParenTrail = ")))"
      trailingParensArePrinted = true
    elseif importsIsLastMainForm and not importSectionHasReaderConditionals then
      closeImportParenTrail = "))"
      trailingParensArePrinted = true
    end

    outTxt = strConcat(outTxt, closeImportParenTrail)

    if isStringWithChars(lastImportLineCommentAfter) then
      outTxt = strConcat3(outTxt, " ", lastImportLineCommentAfter)
    end
  end -- end :import section

  if hasGenClass then
    local genClassIndentationLevel = 2
    outTxt = strConcat(outTxt, "\n")
    local isGenClassBehindReaderConditional = ns.genClass.platform == ":clj"
    if isGenClassBehindReaderConditional then
      outTxt = strConcat(outTxt, "  #?(:clj\n")
      genClassIndentationLevel = 5
    end
    local indentationStr = repeatString(" ", genClassIndentationLevel)
    outTxt = printCommentsAbove(outTxt, ns.genClass.commentsAbove, indentationStr)
    outTxt = strConcat(outTxt, indentationStr)
    outTxt = strConcat(outTxt, "(:gen-class")
    local commentAfterGenClass = nil
    if ns.genClass.isEmpty then
      if isStringWithChars(ns.genClass.commentAfter) then
        commentAfterGenClass = ns.genClass.commentAfter
      end
    else
      if isStringWithChars(ns.genClass.commentAfter) then
        outTxt = strConcat3(outTxt, " ", ns.genClass.commentAfter)
      end
      local genClassValueIndentationLevel = inc(genClassIndentationLevel)
      local indentationStr2 = repeatString(" ", genClassValueIndentationLevel)

      -- print the :gen-class keys in the order in which they appear in the clojure.core.genclass documentation
      -- https://github.com/clojure/clojure/blob/clojure-1.11.1/src/clj/clojure/genclass.clj#L507
      local idx3 = 1
      local numGenClassKeys = arraySize(genClassKeys)
      while idx3 <= numGenClassKeys do
        local genClassKey = genClassKeys[idx3]
        local genClassValue = ns.genClass[genClassKey]
        if genClassValue then
          -- print the comment from the previous line if necessary
          if isStringWithChars(commentAfterGenClass) then
            outTxt = strConcat3(outTxt, " ", commentAfterGenClass)
            commentAfterGenClass = nil
          end
          outTxt = strConcat(outTxt, "\n")
          outTxt = printCommentsAbove(outTxt, genClassValue.commentsAbove, indentationStr2)
          outTxt = strConcat(outTxt, indentationStr2)
          outTxt = strConcat3(outTxt, ":", genClassKey)
          outTxt = strConcat3(outTxt, " ", genClassValue.value)
          if isStringWithChars(genClassValue.commentAfter) then
            commentAfterGenClass = genClassValue.commentAfter
          end
        end
        idx3 = inc(idx3)
      end
    end
    if not isGenClassBehindReaderConditional and not commentAfterGenClass then
      outTxt = strConcat(outTxt, "))")
      trailingParensArePrinted = true
    elseif isGenClassBehindReaderConditional and not commentAfterGenClass then
      outTxt = strConcat(outTxt, ")))")
      trailingParensArePrinted = true
    elseif not isGenClassBehindReaderConditional and isStringWithChars(commentAfterGenClass) then
      outTxt = strConcat3(outTxt, ")) ", commentAfterGenClass)
      trailingParensArePrinted = true
    elseif isGenClassBehindReaderConditional and isStringWithChars(commentAfterGenClass) then
      outTxt = strConcat3(outTxt, "))) ", commentAfterGenClass)
      trailingParensArePrinted = true
    end
  end -- end :gen-class section

  if not trailingParensArePrinted then
    outTxt = strConcat(outTxt, ")")
  end

  if isStringWithChars(commentOutsideNsForm2) then
    outTxt = strConcat3(outTxt, " ", commentOutsideNsForm2)
  end

  return outTxt
end

-- Continuation of the format() function, with the input text parsed into nodes
-- and ns form parsed.
local function formatNodes(nodesArr, parsedNs)
  local numNodes = arraySize(nodesArr)

  local parenNestingDepth = 0
  local idx = 1
  local outTxt = ""
  local outputTxtContainsChars = false
  local lineTxt = ""
  local lineIdx = 0
  local insideNsForm = false
  local lineIdxOfClosingNsForm = -1
  local nsStartStringIdx = -1
  local nsEndStringIdx = -1
  local taggedNodeIdx = -1
  local ignoreNodesStartId = -1
  local ignoreNodesEndId = -1
  local insideTheIgnoreZone = false

  local parenStack = {}
  local nodesWeHavePrintedOnThisLine = {}

  local colIdx = 0
  while idx <= numNodes do
    local node = nodesArr[idx]

    if ignoreNodesStartId > 0 and node.id == ignoreNodesStartId then
      insideTheIgnoreZone = true

      -- dump the current lineTxt when we start the ignore zone
      outTxt = strConcat(outTxt, lineTxt)
      lineTxt = ""
    end

    if insideTheIgnoreZone then
      if isString(node.text) and node.text ~= "" then
        outTxt = strConcat(outTxt, node.text)
      end

      if node.id == ignoreNodesEndId then
        ignoreNodesStartId = -1
        ignoreNodesEndId = -1
        insideTheIgnoreZone = false
      end
    else
      -- record original column indexes for the first line
      if idx == 1 then
        nodesArr = recordOriginalColIndexes(nodesArr, idx)
      end

      if nsStartStringIdx == -1 and parenNestingDepth == 1 and isNsNode(node) then
        insideNsForm = true
        nsStartStringIdx = strLen(strConcat(outTxt, lineTxt))
      end

      local nextTextNode = findNextNodeWithText(nodesArr, inc(idx))
      local isLastNode = idx == numNodes

      local currentNodeIsWhitespace = isWhitespaceNode(node)
      local currentNodeIsNewline = isNewlineNode(node)
      local currentNodeIsTag = isTagNode(node)
      local skipPrintingThisNode = false

      if isStandardCljIgnoreKeyword(node) and idx > 1 then
        local prevNode1 = findPrevNodeWithText(nodesArr, idx, node.id)
        local prevNode2 = nil
        if prevNode1 then
          prevNode2 = findPrevNodeWithText(nodesArr, idx, prevNode1.id)
        end

        local isDiscardMap = prevNode1.name == ".open"
          and prevNode1.text == "{"
          and prevNode2
          and isDiscardNode(prevNode2)

        if isDiscardNode(prevNode1) or (isWhitespaceNode(prevNode1) and isDiscardNode(prevNode2)) then
          -- look forward to find the next node with text
          local nextIgnoreNode = findNextNonWhitespaceNode(nodesArr, inc(idx))

          -- if parens or brackets or something with children, then find the closing node id
          if isArray(nextIgnoreNode.children) and arraySize(nextIgnoreNode.children) > 0 then
            local closingNode = arrayLast(nextIgnoreNode.children)
            ignoreNodesStartId = nextIgnoreNode.id
            ignoreNodesEndId = closingNode.id

          -- if a node without children, then just don't format it
          else
            local nextImmediateNode = nodesArr[inc(idx)]
            ignoreNodesStartId = nextImmediateNode.id
            ignoreNodesEndId = nextIgnoreNode.id
          end
        elseif isDiscardMap then
          -- find the opening { and closing } for this form
          local openingBraceNode = findPrevNodeWithPredicate(nodesArr, idx, isOpeningBraceNode)
          local closingBraceNodeId = openingBraceNode.children[3].id -- Lua arrays are 1-based

          local startIgnoreNode =
            findNextNodeWithPredicateAfterSpecificNode(nodesArr, idx, alwaysTrue, closingBraceNodeId)
          local firstNodeInsideIgnoreZone =
            findNextNodeWithPredicateAfterSpecificNode(nodesArr, idx, alwaysTrue, startIgnoreNode.id)

          -- if parens or brackets or something with children, then find the closing node id
          if isArray(firstNodeInsideIgnoreZone.children) and arraySize(firstNodeInsideIgnoreZone.children) > 0 then
            local closingNode = arrayLast(firstNodeInsideIgnoreZone.children)
            ignoreNodesStartId = startIgnoreNode.id
            ignoreNodesEndId = closingNode.id

          -- if a node without children, then just don't format it
          else
            ignoreNodesStartId = startIgnoreNode.id
            ignoreNodesEndId = firstNodeInsideIgnoreZone.id
          end
        end
      end

      if isParenOpener(node) then
        -- we potentially need to add this opener node to the current openingLineNodes
        -- before we push into the next parenStack
        local topOfTheParenStack = stackPeek(parenStack, 0)
        if topOfTheParenStack then
          local onOpeningLineOfParenStack = lineIdx == topOfTheParenStack._parenOpenerLineIdx
          if onOpeningLineOfParenStack then
            node._colIdx = colIdx
            node._lineIdx = lineIdx
            stackPush(topOfTheParenStack._openingLineNodes, node)
          end
        end

        parenNestingDepth = inc(parenNestingDepth)

        -- attach some extra information to this node and push it onto the parenStack
        local parenStackNode = node
        parenStackNode._colIdx = colIdx
        parenStackNode._nextWithText = nextTextNode
        parenStackNode._parenOpenerLineIdx = lineIdx
        -- an array of nodes on the first line of this parenStack
        -- used to determine if Rule 3 indentation applies
        parenStackNode._openingLineNodes = {}
        parenStackNode._rule3Active = false
        parenStackNode._rule3NumSpaces = 0
        parenStackNode._rule3SearchComplete = false

        stackPush(parenStack, parenStackNode)

        -- remove whitespace after an opener (remove-surrounding-whitespace?)
        if isWhitespaceNode(nextTextNode) then
          -- FIXME: skip this via index instead of modifying the tree like this
          nextTextNode.text = ""
        end
      elseif isParenCloser(node) then
        -- NOTE: this code is duplicated when we look forward to close parenTrails
        parenNestingDepth = dec(parenNestingDepth)
        stackPop(parenStack)

        -- flag the end of the ns form
        if insideNsForm and parenNestingDepth == 0 then
          insideNsForm = false
          nsEndStringIdx = strLen(strConcat(outTxt, lineTxt))
          lineIdxOfClosingNsForm = lineIdx
        end
      end

      -- flag the index of a tagged literal node so we can mark the next one if necessary
      if node.name == ".tag" then
        taggedNodeIdx = idx
      end

      -- add nodes to the top of the parenStack if we are on the opening line
      local topOfTheParenStack = stackPeek(parenStack, 0)
      if topOfTheParenStack and nodeContainsText(node) then
        local onOpeningLineOfParenStack = lineIdx == topOfTheParenStack._parenOpenerLineIdx
        if onOpeningLineOfParenStack then
          if taggedNodeIdx == dec(idx) then
            node._nodeIsTagLiteral = true
          end

          node._colIdx = colIdx
          node._lineIdx = lineIdx
          stackPush(topOfTheParenStack._openingLineNodes, node)
        end
      end

      -- remove whitespace before a closer (remove-surrounding-whitespace?)
      if currentNodeIsWhitespace and not currentNodeIsNewline and isParenCloser(nextTextNode) then
        skipPrintingThisNode = true
      end

      -- do not print a comma at the end of a line
      if currentNodeIsWhitespace and not currentNodeIsNewline and nextTextNode and isCommentNode(nextTextNode) then
        node.text = strReplaceAll(node.text, ",", "")
      end

      -- If we are inside of a parenStack and hit a newline,
      -- look forward to see if we can close the current parenTrail.
      -- ie: slurp closing parens onto the current line
      local parenStackSize = arraySize(parenStack)
      if parenStackSize > 0 and not insideNsForm then
        local isCommentFollowedByNewline = isCommentNode(node) and nextTextNode and isNewlineNode(nextTextNode)
        local isNewline = isNewlineNode(node)
        local hasCommasAfterNewline2 = hasCommasAfterNewline(node)
          or (nextTextNode and hasCommasAfterNewline(nextTextNode))

        local lookForwardToSlurpNodes = false
        if hasCommasAfterNewline2 then
          lookForwardToSlurpNodes = false
        elseif isCommentFollowedByNewline then
          lookForwardToSlurpNodes = true
        elseif isNewline then
          lookForwardToSlurpNodes = true
        end

        if lookForwardToSlurpNodes then
          -- look forward and grab any closers nodes that may be slurped up
          local parenTrailClosers = findForwardClosingParens(nodesArr, inc(idx))

          -- If we have printed a whitespace node just before this, we may need to remove it and then re-print
          local lastNodeWePrinted = arrayLast(nodesWeHavePrintedOnThisLine)
          local lineTxtHasBeenRightTrimmed = false
          if lastNodeWePrinted and isWhitespaceNode(lastNodeWePrinted) then
            lineTxt = removeTrailingWhitespace(lineTxt)
            lineTxtHasBeenRightTrimmed = true
          end

          local parenTrailCloserIdx = 1
          local numParenTrailClosers = arraySize(parenTrailClosers)

          while parenTrailCloserIdx <= numParenTrailClosers do
            local parenTrailCloserNode = parenTrailClosers[parenTrailCloserIdx]

            if isParenCloser(parenTrailCloserNode) then
              -- NOTE: we are adjusting the current line here, but we do not update the nodesWeHavePrintedOnThisLine
              -- because we cannot have a Rule 3 alignment to a closer node
              lineTxt = strConcat(lineTxt, parenTrailCloserNode.text)

              parenTrailCloserNode.text = ""
              parenTrailCloserNode._wasSlurpedUp = true

              parenNestingDepth = dec(parenNestingDepth)
              stackPop(parenStack)
            end

            parenTrailCloserIdx = inc(parenTrailCloserIdx)
          end

          -- re-print the whitespace node if necessary
          if lineTxtHasBeenRightTrimmed then
            lineTxt = strConcat(lineTxt, lastNodeWePrinted.text)
          end
        end
      end

      if currentNodeIsNewline then
        -- record the original column indexes for the next line
        nodesArr = recordOriginalColIndexes(nodesArr, idx)

        local numSpacesOnNextLine = numSpacesAfterNewline(node)

        -- Have we already slurped up everything on the next line?
        local allNextLineNodesWereSlurpedUp = areForwardNodesAlreadySlurped(nodesArr, inc(idx))

        local nextLineContainsOnlyOneComment = isNextLineACommentLine(nodesArr, inc(idx))
        local nextLineCommentColIdx = -1
        if nextLineContainsOnlyOneComment then
          nextLineCommentColIdx = numSpacesOnNextLine
        end

        local isDoubleNewline = strIncludes(node.text, "\n\n")
        local newlineStr = "\n"
        if isDoubleNewline then
          newlineStr = "\n\n"
        end

        -- print the current line and calculate the next line's indentation level
        if outputTxtContainsChars then
          local topOfTheParenStack = stackPeek(parenStack, 0)

          -- Check for Rule 3:
          -- Are we inside of a parenStack that crosses into the next line?
          -- And have not already done a "Rule 3" check for this parenStack?
          if topOfTheParenStack and not topOfTheParenStack._rule3SearchComplete then
            local searchForAlignmentNode = true
            -- NOTE: we can start this index at 2 because we will always want to skip at least the first node
            local openingLineNodeIdx = 2

            -- we must be past the first whitespace node in order to look for Rule 3 alignment nodes
            local pastFirstWhitespaceNode = false

            local numOpeningLineNodes = arraySize(topOfTheParenStack._openingLineNodes)
            if numOpeningLineNodes > 2 then
              while searchForAlignmentNode do
                local openingLineNode = topOfTheParenStack._openingLineNodes[openingLineNodeIdx]

                if openingLineNode then
                  -- Is the first node on this new line vertically aligned with any of the nodes
                  -- on the line above that are in the same paren stack?
                  if
                    pastFirstWhitespaceNode
                    and isNodeWithNonBlankText(openingLineNode)
                    and openingLineNode._origColIdx == numSpacesOnNextLine
                  then
                    -- Rule 3 is activated 👍
                    topOfTheParenStack._rule3Active = true

                    -- NOTE: we use the original _colIdx of this node in order to determine Rule 3 alignment,
                    -- but we use the _printedColIdx of this node to determine the number of leading spaces
                    topOfTheParenStack._rule3NumSpaces = openingLineNode._printedColIdx

                    -- edge case: align tagged literals to the # char
                    if openingLineNode._nodeIsTagLiteral then
                      topOfTheParenStack._rule3NumSpaces = dec(openingLineNode._printedColIdx)
                    end

                    -- we are done searching at this point
                    searchForAlignmentNode = false
                  elseif not pastFirstWhitespaceNode and isWhitespaceNode(openingLineNode) then
                    pastFirstWhitespaceNode = true
                  end
                end

                openingLineNodeIdx = inc(openingLineNodeIdx)
                if openingLineNodeIdx > numOpeningLineNodes then
                  searchForAlignmentNode = false
                end
              end
            end

            -- only check for Rule 3 alignment once per parenStack
            topOfTheParenStack._rule3SearchComplete = true
          end

          -- Do we have a comment line that looks vertically aligned with nodes on the previous line?
          -- NOTE: this is basically "Rule 3" for single line comments
          local colIdxOfSingleLineCommentAlignmentNode = -1
          local commentLooksAlignedWithPreviousForm = false
          if nextLineContainsOnlyOneComment then
            local idx2 = 1
            local numPrevLineNodes = arraySize(nodesWeHavePrintedOnThisLine)
            while idx2 <= numPrevLineNodes do
              local prevLineNode = nodesWeHavePrintedOnThisLine[idx2]
              local prevNode2 = nil
              if idx2 > 1 then
                prevNode2 = nodesWeHavePrintedOnThisLine[dec(idx2)]
              end
              local isPossibleAlignmentNode = false
              if isNodeWithNonBlankText(prevLineNode) then
                if not prevNode2 or (prevNode2 and not isParenOpener(prevNode2)) then
                  isPossibleAlignmentNode = true
                end
              end
              if isPossibleAlignmentNode and nextLineCommentColIdx == prevLineNode._origColIdx then
                colIdxOfSingleLineCommentAlignmentNode = prevLineNode._printedColIdx
                commentLooksAlignedWithPreviousForm = true
                idx2 = inc(numPrevLineNodes) -- exit the loop
              end
              idx2 = inc(idx2)
            end
          end

          local numSpaces = 0
          -- If we are inside a parenStack and Rule 3 has been activated, use that first.
          if topOfTheParenStack and topOfTheParenStack._rule3Active then
            numSpaces = topOfTheParenStack._rule3NumSpaces

          -- Comment lines that are vertically aligned with a node from the line above --> align to that node
          elseif nextLineContainsOnlyOneComment and commentLooksAlignedWithPreviousForm then
            numSpaces = colIdxOfSingleLineCommentAlignmentNode

          -- Comment lines that are outside of a parenStack, and have no obvious relation to lines above them:
          -- keep their current indentation
          elseif nextLineContainsOnlyOneComment and not topOfTheParenStack then
            numSpaces = numSpacesOnNextLine

          -- Else apply regular fixed indentation rules based on the parenStack depth (ie: Tonsky rules)
          else
            numSpaces = numSpacesForIndentation(topOfTheParenStack)
          end

          local indentationStr = repeatString(" ", numSpaces)

          -- If we have slurped up all of the nodes on this line, we can remove it.
          if allNextLineNodesWereSlurpedUp then
            newlineStr = ""
            indentationStr = ""
          end

          if isCommaNode(node) then
            local nextLineCommaTrail = removeLeadingWhitespace(node.text)
            local trimmedCommaTrail = rtrim(nextLineCommaTrail)
            indentationStr = strConcat(indentationStr, trimmedCommaTrail)
          end

          -- add this line to the outTxt and reset lineTxt
          if strTrim(lineTxt) ~= "" then
            outTxt = strConcat(outTxt, lineTxt)
          end
          outTxt = strConcat(outTxt, newlineStr)

          lineTxt = indentationStr
          nodesWeHavePrintedOnThisLine = {}

          -- reset the colIdx
          colIdx = strLen(indentationStr)

          -- increment the lineIdx
          lineIdx = inc(lineIdx)
          if isDoubleNewline then
            lineIdx = inc(lineIdx)
          end
        end

        -- we have taken care of printing this node, skip the "normal" printing step
        skipPrintingThisNode = true
      end -- end currentNodeIsNewline

      if (nodeContainsText(node) or currentNodeIsTag) and not skipPrintingThisNode then
        local isTokenFollowedByOpener = isTokenNode(node) and nextTextNode and isParenOpener(nextTextNode)
        local isParenCloserFollowedByText = isParenCloser(node)
          and nextTextNode
          and (isTokenNode(nextTextNode) or isParenOpener(nextTextNode))
        local addSpaceAfterThisNode = isTokenFollowedByOpener or isParenCloserFollowedByText

        local nodeTxt = node.text
        if currentNodeIsTag then
          nodeTxt = "#"
        elseif isCommentNode(node) then
          if commentNeedsSpaceInside(nodeTxt) then
            nodeTxt = strReplaceFirst(nodeTxt, "^(;+)([^ ])", "%1 %2") -- Lua regex syntax
          end
          if commentNeedsSpaceBefore(lineTxt, nodeTxt) then
            nodeTxt = strConcat(" ", nodeTxt)
          end
        end

        -- if there is a whitespace node as the first or last node, do not print it
        if currentNodeIsWhitespace and (isLastNode or not outputTxtContainsChars) then
          skipPrintingThisNode = true

        -- do not print a comment node on the last line of the ns form
        -- (this is handled by the nsFormat function)
        elseif
          isCommentNode(node)
          and parsedNs.commentOutsideNsForm == node.text
          and lineIdx == lineIdxOfClosingNsForm
        then
          skipPrintingThisNode = true
        elseif currentNodeIsWhitespace and lineIdx == lineIdxOfClosingNsForm then
          skipPrintingThisNode = true
        elseif node._skipPrintingThisNode == true then
          skipPrintingThisNode = true
        end

        -- add the text of this node to the current line
        if not skipPrintingThisNode then
          local lineLengthBeforePrintingNode = strLen(lineTxt)
          lineTxt = strConcat(lineTxt, nodeTxt)

          if lineTxt ~= "" then
            outputTxtContainsChars = true
          end

          -- add the printed colIdx to this node
          node._printedColIdx = lineLengthBeforePrintingNode
          node._printedLineIdx = lineIdx

          stackPush(nodesWeHavePrintedOnThisLine, node)
        end

        if addSpaceAfterThisNode then
          lineTxt = strConcat(lineTxt, " ")
        end

        -- update the colIdx
        colIdx = colIdx + strLen(nodeTxt)
      end
    end -- end !insideTheIgnoreZone

    idx = inc(idx)
  end -- end looping through the nodes

  -- add the last line to outTxt if necessary
  if lineTxt ~= "" then
    outTxt = strConcat(outTxt, lineTxt)
  end

  -- replace the ns form with our formatted version
  if nsStartStringIdx > 0 then
    local headStr = substr(outTxt, 1, nsStartStringIdx)

    local nsStr = nil
    local success, result = pcall(function()
      return formatNs(parsedNs)
    end)

    if not success then
      return {
        status = "error",
        reason = result,
      }
    end
    nsStr = result

    local tailStr = ""
    if nsEndStringIdx > 0 then
      tailStr = substr(outTxt, inc(inc(nsEndStringIdx)), -1)
    end

    outTxt = strConcat3(headStr, nsStr, tailStr)
  end

  -- remove any leading or trailing whitespace
  outTxt = strTrim(outTxt)

  return {
    status = "success",
    out = outTxt,
  }
end

-- Parses inputTxt (Clojure code) and returns a String of it formatted according
-- to Standard Clojure Style.
local function format(inputTxt)
  -- replace any CRLF with LF before we do anything
  inputTxt = crlfToLf(inputTxt)

  -- FIXME: wrap this in try/catch and return error code if found
  local tree = parse(inputTxt)
  local nodesArr = flattenTree(tree)
  local ignoreFile = lookForIgnoreFile(nodesArr)
  if ignoreFile then
    return {
      fileWasIgnored = true,
      status = "success",
      out = inputTxt,
    }
  else
    -- parse the ns data structure from the nodes
    local parsedNs = nil
    local ok, err = pcall(function()
      parsedNs = parseNs(nodesArr)
    end)
    if not ok then
      return {
        status = "error",
        reason = err,
      }
    end
    return formatNodes(nodesArr, parsedNs)
  end
end

function parse(inputTxt)
  return getParser("source").parse(inputTxt, 1)
end

-- -----------------------------------------------------------------------------
-- Public API

M.format = format
M.parse = parse
M.parseNs = parseNs

-- Export internal functions for testing purposes

M._charAt = charAt
M._crlfToLf = crlfToLf
M._isStringWithChars = isStringWithChars
M._repeatString = repeatString
M._rtrim = rtrim
M._stackPeek = stackPeek
M._stackPop = stackPop
M._stackPush = stackPush
M._strEndsWith = strEndsWith
M._strIncludes = strIncludes
M._strJoin = strJoin
M._strReplaceFirst = strReplaceFirst
M._strReplaceAll = strReplaceAll
M._strStartsWith = strStartsWith
M._strTrim = strTrim
M._substr = substr
M._toUpperCase = toUpperCase

M._commentNeedsSpaceBefore = commentNeedsSpaceBefore
M._commentNeedsSpaceInside = commentNeedsSpaceInside
M._removeLeadingWhitespace = removeLeadingWhitespace
M._removeTrailingWhitespace = removeTrailingWhitespace
M._removeCharsUpToNewline = removeCharsUpToNewline
M._txtHasCommasAfterNewline = txtHasCommasAfterNewline

M._AnyChar = AnyChar
M._Char = Char
M._Choice = Choice
M._NotChar = NotChar
M._Pattern = Pattern
M._Repeat = Repeat
M._Seq = Seq
M._String = String

M._flattenTree = flattenTree
M._parseJavaPackageWithClass = parseJavaPackageWithClass

return M
