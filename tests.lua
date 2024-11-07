-- tests.lua: tests for the Standard Clojure Style Lua library
--
-- Copyright (c) 2024, Chris Oakman
-- Released under the ISC license
-- https://github.com/oakmac/standard-clojure-style-lua/blob/master/LICENSE.md

local lu = require("libs/luaunit")
local json = require("libs/json")
local inspect = require("libs/inspect")
local scsLib = require("standard-clojure-style")

-- -----------------------------------------------------------------------------
-- Util Functions

local function arraySize(a)
  return #a
end

local function isArray(x)
  -- In Lua, arrays are tables with consecutive integer keys starting at 1
  -- This is a basic implementation that checks if a table appears to be array-like
  if type(x) ~= "table" then
    return false
  end
  local count = 0
  for _ in pairs(x) do
    count = count + 1
  end
  -- Check if all indices from 1 to count exist
  for i = 1, count do
    if x[i] == nil then
      return false
    end
  end
  return true
end

local function isNonBlankString(s)
  return type(s) == "string" and s ~= ""
end

-- https://stackoverflow.com/a/31857671/2137320
local function readFile(path)
  local file = io.open(path, "rb") -- r read mode and b binary mode
  if not file then
    return nil
  end
  local content = file:read("*a") -- *a or *all reads the whole file
  file:close()
  return content
end

local function isString(s)
  return type(s) == "string"
end

local function isInteger(x)
  return type(x) == "number" and x == math.floor(x)
end

local function isPositiveInt(i)
  return isInteger(i) and i >= 0
end

local function repeatString(text, n)
  local result = ""
  local i = 0
  while i < n do
    result = result .. text
    i = i + 1
  end
  return result
end

-- replaces all instances of findStr with replaceStr inside of String s
local function strReplaceAll(s, findStr, replaceStr)
  return string.gsub(s, findStr:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"), replaceStr)
end

local numSpacesPerIndentLevel = 2

local function isWhitespaceNode(n)
  return n and isString(n.name) and (n.name == "whitespace" or n.name == "whitespace:newline")
end

-- returns a String representation of a parsed result
-- NOTE: the parsed result from Standard Clojure Style Lua is 1-indexed based, but
-- we adjust that down here by one in order to compare the test case
local function nodeToString(node, indentLevel)
  -- skip printing whitespace nodes for the parser test suite
  if isWhitespaceNode(node) then
    return ""
  else
    if not isPositiveInt(indentLevel) then
      indentLevel = 0
    end
    local indentationSpaces = repeatString(" ", indentLevel * numSpacesPerIndentLevel)
    local outTxt = ""
    if node.name ~= "source" then
      outTxt = "\n"
    end
    -- NOTE: subtract startIdx and endIdx by one here to match the test case output from Standard Clojure Style JavaScript
    outTxt = outTxt .. indentationSpaces .. "(" .. node.name .. " " .. (node.startIdx - 1) .. ".." .. (node.endIdx - 1)
    if node.text and node.text ~= "" then
      local textWithNewlinesEscaped = strReplaceAll(node.text, "\n", "\\n")
      outTxt = outTxt .. " '" .. textWithNewlinesEscaped .. "'"
    end
    if node.children then
      local i = 1
      local numChildren = arraySize(node.children)
      while i <= numChildren do
        local childNode = node.children[i]
        outTxt = outTxt .. nodeToString(childNode, indentLevel + 1)
        i = i + 1
      end
    end
    outTxt = outTxt .. ")"
    return outTxt
  end
end

-- https://tinyurl.com/p235ckrf
local function deepCompare(t1, t2)
  local ty1 = type(t1)
  local ty2 = type(t2)
  if ty1 ~= ty2 then
    return false
  end

  -- non-table types can be directly compared
  if ty1 ~= "table" and ty2 ~= "table" then
    return t1 == t2
  end

  for k1, v1 in pairs(t1) do
    local v2 = t2[k1]
    if v2 == nil or not deepCompare(v1, v2) then
      return false
    end
  end

  for k2, v2 in pairs(t2) do
    local v1 = t1[k2]
    if v1 == nil or not deepCompare(v1, v2) then
      return false
    end
  end

  return true
end

-- -----------------------------------------------------------------------------
-- Util Functions Tests

TestDeepCompare = {}

function TestDeepCompare:testPrimitiveTypes()
  -- Test numbers
  lu.assertTrue(deepCompare(1, 1))
  lu.assertFalse(deepCompare(1, 2))

  -- Test strings
  lu.assertTrue(deepCompare("hello", "hello"))
  lu.assertFalse(deepCompare("hello", "world"))

  -- Test booleans
  lu.assertTrue(deepCompare(true, true))
  lu.assertFalse(deepCompare(true, false))

  -- Test nil
  lu.assertTrue(deepCompare(nil, nil))
end

function TestDeepCompare:testDifferentTypes()
  lu.assertFalse(deepCompare(1, "1"))
  lu.assertFalse(deepCompare({}, 1))
  lu.assertFalse(deepCompare(true, "true"))
  lu.assertFalse(deepCompare(nil, false))
end

function TestDeepCompare:testSimpleTables()
  -- Test empty tables
  lu.assertTrue(deepCompare({}, {}))

  -- Test simple key-value pairs
  lu.assertTrue(deepCompare({ a = 1, b = 2 }, { a = 1, b = 2 }))
  lu.assertFalse(deepCompare({ a = 1, b = 2 }, { a = 1, b = 3 }))

  -- Test arrays
  lu.assertTrue(deepCompare({ 1, 2, 3 }, { 1, 2, 3 }))
  lu.assertFalse(deepCompare({ 1, 2, 3 }, { 1, 2, 4 }))
  lu.assertFalse(deepCompare({ 1, 2, 3 }, { 1, 2 }))
end

function TestDeepCompare:testNestedTables()
  -- Test nested tables with same structure
  local t1 = { a = { x = 1, y = 2 }, b = { 3, 4 } }
  local t2 = { a = { x = 1, y = 2 }, b = { 3, 4 } }
  lu.assertTrue(deepCompare(t1, t2))

  -- Test nested tables with different values
  local t3 = { a = { x = 1, y = 3 }, b = { 3, 4 } }
  lu.assertFalse(deepCompare(t1, t3))

  -- Test deeply nested tables
  local deep1 = { a = { b = { c = { d = 1 } } } }
  local deep2 = { a = { b = { c = { d = 1 } } } }
  local deep3 = { a = { b = { c = { d = 2 } } } }
  lu.assertTrue(deepCompare(deep1, deep2))
  lu.assertFalse(deepCompare(deep1, deep3))
end

function TestDeepCompare:testMixedTypes()
  -- Test tables with mixed types
  local mixed1 = {
    num = 1,
    str = "hello",
    bool = true,
    tbl = { 1, 2, 3 },
    nested = { a = { b = 2 } },
  }
  local mixed2 = {
    num = 1,
    str = "hello",
    bool = true,
    tbl = { 1, 2, 3 },
    nested = { a = { b = 2 } },
  }
  lu.assertTrue(deepCompare(mixed1, mixed2))

  -- Modify one nested value
  mixed2.nested.a.b = 3
  lu.assertFalse(deepCompare(mixed1, mixed2))
end

function TestDeepCompare:testEdgeCases()
  -- Test tables with nil values
  lu.assertTrue(deepCompare({ a = nil }, { a = nil }))

  -- Test tables with different keys
  lu.assertFalse(deepCompare({ a = 1 }, { b = 1 }))

  -- Test tables with recursive references
  local t1 = { a = 1 }
  local t2 = { a = 1 }
  t1.self = t1
  t2.self = t2
  -- Note: This will cause infinite recursion in the current implementation
  -- Uncomment if recursion protection is added
  -- lu.assertTrue(deepCompare(t1, t2))
end

-- -----------------------------------------------------------------------------
-- LuaUnit Tests

-- NOTE: luaUnit test functions must start with "test*"

TestStringUtil = {}

function TestStringUtil:testCharAt()
  lu.assertEquals(scsLib._charAt("hello", 1), "h")
  lu.assertEquals(scsLib._charAt("hello", 5), "o")
  lu.assertEquals(scsLib._charAt("a", 1), "a")
  lu.assertEquals(scsLib._charAt("", 0), "")
  lu.assertEquals(scsLib._charAt("", 1), "")
  lu.assertEquals(scsLib._charAt("a", 2), "")
  lu.assertEquals(scsLib._charAt("a", -1), "") -- negative index
end

function TestStringUtil:testSubstr()
  lu.assertEquals(scsLib._substr("hello world", 1, 6), "hello")
  lu.assertEquals(scsLib._substr("hello world", 7, 12), "world")
  lu.assertEquals(scsLib._substr("hello world", 1, -1), "hello world")
  lu.assertEquals(scsLib._substr("hello", 3, -1), "llo")
  lu.assertEquals(scsLib._substr("hello", 1, 11), "hello") -- end beyond string length
  lu.assertEquals(scsLib._substr("hello", 11, 16), "") -- start beyond string length
  lu.assertEquals(scsLib._substr("hello", -1, 3), "") -- negative start
end

function TestStringUtil:testRepeatString()
  lu.assertEquals(scsLib._repeatString("abc", 3), "abcabcabc")
  lu.assertEquals(scsLib._repeatString("x", 5), "xxxxx")
  lu.assertEquals(scsLib._repeatString("", 5), "")
  lu.assertEquals(scsLib._repeatString("hello", 0), "")
  lu.assertEquals(scsLib._repeatString("a", -1), "")
end

function TestStringUtil:testStrIncludes()
  lu.assertTrue(scsLib._strIncludes("hello world", "world"))
  lu.assertTrue(scsLib._strIncludes("hello world", "hello"))
  lu.assertFalse(scsLib._strIncludes("hello world", "xyz"))
  lu.assertTrue(scsLib._strIncludes("", ""))
  lu.assertTrue(scsLib._strIncludes("abc", ""))
  lu.assertFalse(scsLib._strIncludes("", "a"))
end

function TestStringUtil:testToUpperCase()
  lu.assertEquals(scsLib._toUpperCase("hello"), "HELLO")
  lu.assertEquals(scsLib._toUpperCase("Hello World!"), "HELLO WORLD!")
  lu.assertEquals(scsLib._toUpperCase(""), "")
  lu.assertEquals(scsLib._toUpperCase("123"), "123")
  -- NOTE: Standard Clojure Style does not need to support this edge case
  -- lu.assertEquals(scsLib._toUpperCase('áéíóú'), 'ÁÉÍÓÚ') -- accented characters
end

function TestStringUtil:testStrJoin()
  lu.assertEquals(scsLib._strJoin({ "a", "b", "c" }, "-"), "a-b-c")
  lu.assertEquals(scsLib._strJoin({ "hello", "world" }, " "), "hello world")
  lu.assertEquals(scsLib._strJoin({}, "-"), "")
  lu.assertEquals(scsLib._strJoin({ "a" }, "-"), "a")
  lu.assertEquals(scsLib._strJoin({ "a", "b" }, ""), "ab")
end

function TestStringUtil:testRtrim()
  lu.assertEquals(scsLib._rtrim("  hello  "), "  hello")
  lu.assertEquals(scsLib._rtrim("hello\n\t  "), "hello")
  lu.assertEquals(scsLib._rtrim(""), "")
  lu.assertEquals(scsLib._rtrim("   "), "")
  lu.assertEquals(scsLib._rtrim("hello"), "hello")
end

function TestStringUtil:testStrTrim()
  lu.assertEquals(scsLib._strTrim("  hello  "), "hello")
  lu.assertEquals(scsLib._strTrim("\n\t hello \t\n"), "hello")
  lu.assertEquals(scsLib._strTrim(""), "")
  lu.assertEquals(scsLib._strTrim("   "), "")
  lu.assertEquals(scsLib._strTrim("hello"), "hello")
end

function TestStringUtil:testStrStartsWith()
  lu.assertTrue(scsLib._strStartsWith("hello world", "hello"))
  lu.assertFalse(scsLib._strStartsWith("hello world", "world"))
  lu.assertTrue(scsLib._strStartsWith("", ""))
  lu.assertTrue(scsLib._strStartsWith("hello", ""))
  lu.assertFalse(scsLib._strStartsWith("", "a"))
end

function TestStringUtil:testStrEndsWith()
  lu.assertTrue(scsLib._strEndsWith("hello world", "world"))
  lu.assertFalse(scsLib._strEndsWith("hello world", "hello"))
  lu.assertTrue(scsLib._strEndsWith("", ""))
  lu.assertTrue(scsLib._strEndsWith("hello", ""))
  lu.assertFalse(scsLib._strEndsWith("", "a"))
end

function TestStringUtil:testIsStringWithChars()
  lu.assertTrue(scsLib._isStringWithChars("hello"))
  lu.assertTrue(scsLib._isStringWithChars("  x  "))
  lu.assertTrue(scsLib._isStringWithChars(" "))
  lu.assertFalse(scsLib._isStringWithChars(""))
  lu.assertFalse(scsLib._isStringWithChars(nil))
end

function TestStringUtil:testStrReplaceFirst()
  lu.assertEquals(scsLib._strReplaceFirst("hello world", "world", "there"), "hello there")
  lu.assertEquals(scsLib._strReplaceFirst("hello hello", "hello", "hi"), "hi hello")
  lu.assertEquals(scsLib._strReplaceFirst("", "a", "b"), "")
  lu.assertEquals(scsLib._strReplaceFirst("hello", "", "x"), "hello")
  lu.assertEquals(scsLib._strReplaceFirst("hello", "x", "y"), "hello")
end

function TestStringUtil:testCrlfToLf()
  lu.assertEquals(scsLib._crlfToLf("hello\r\nworld"), "hello\nworld")
  lu.assertEquals(scsLib._crlfToLf("line1\r\nline2\r\nline3"), "line1\nline2\nline3")
  lu.assertEquals(scsLib._crlfToLf(""), "")
  lu.assertEquals(scsLib._crlfToLf("no crlf"), "no crlf")
  lu.assertEquals(scsLib._crlfToLf("\r\n"), "\n")
end

function TestStringUtil:testStrSplit()
  lu.assertEquals(scsLib._strSplit("a-b-c", "-"), { "a", "b", "c" })
  lu.assertEquals(scsLib._strSplit("hello world", " "), { "hello", "world" })
  lu.assertEquals(scsLib._strSplit("", "-"), { "" })
  lu.assertEquals(scsLib._strSplit("hello", ""), { "h", "e", "l", "l", "o" })
  lu.assertEquals(scsLib._strSplit("a", "x"), { "a" })
  lu.assertEquals(scsLib._strSplit("a-b-", "-"), { "a", "b", "" })
end

-- Test class
TestStackOperations = {}

-- stackPeek tests
function TestStackOperations:testPeekLastElement()
  local arr = { 1, 2, 3, 4 }
  lu.assertEquals(scsLib._stackPeek(arr, 0), 4)
end

function TestStackOperations:testPeekFromBack()
  local arr = { 1, 2, 3, 4 }
  lu.assertEquals(scsLib._stackPeek(arr, 1), 3)
  lu.assertEquals(scsLib._stackPeek(arr, 2), 2)
  lu.assertEquals(scsLib._stackPeek(arr, 3), 1)
end

function TestStackOperations:testPeekOutOfBounds()
  local arr = { 1, 2, 3 }
  lu.assertEquals(scsLib._stackPeek(arr, 3), null)
  lu.assertEquals(scsLib._stackPeek(arr, 4), null)
end

function TestStackOperations:testPeekEmptyArray()
  local arr = {}
  lu.assertEquals(scsLib._stackPeek(arr, 0), null)
end

function TestStackOperations:testPeekSingleElement()
  local arr = { 42 }
  lu.assertEquals(scsLib._stackPeek(arr, 0), 42)
  lu.assertEquals(scsLib._stackPeek(arr, 1), null)
end

-- stackPop tests
function TestStackOperations:testPopLastElement()
  local stack = { 1, 2, 3 }
  lu.assertEquals(scsLib._stackPop(stack), 3)
  lu.assertEquals(arraySize(stack), 2)
  lu.assertEquals(stack[1], 1)
  lu.assertEquals(stack[2], 2)
end

function TestStackOperations:testPopEmptyStack()
  local stack = {}
  lu.assertEquals(scsLib._stackPop(stack), nil)
  lu.assertEquals(arraySize(stack), 0)
end

function TestStackOperations:testPopSingleElement()
  local stack = { 42 }
  lu.assertEquals(scsLib._stackPop(stack), 42)
  lu.assertEquals(arraySize(stack), 0)
end

-- stackPush tests
function TestStackOperations:testPushToStack()
  local stack = { 1, 2 }
  lu.assertEquals(scsLib._stackPush(stack, 3), null)
  lu.assertEquals(arraySize(stack), 3)
  lu.assertEquals(stack[3], 3)
end

function TestStackOperations:testPushToEmptyStack()
  local stack = {}
  lu.assertEquals(scsLib._stackPush(stack, 1), null)
  lu.assertEquals(arraySize(stack), 1)
  lu.assertEquals(stack[1], 1)
end

function TestStackOperations:testPushMultipleItems()
  local stack = {}
  scsLib._stackPush(stack, 1)
  scsLib._stackPush(stack, 2)
  scsLib._stackPush(stack, 3)
  lu.assertEquals(arraySize(stack), 3)
  lu.assertEquals(stack[1], 1)
  lu.assertEquals(stack[2], 2)
  lu.assertEquals(stack[3], 3)
end

function TestStackOperations:testPushDifferentTypes()
  local stack = {}
  scsLib._stackPush(stack, 42)
  scsLib._stackPush(stack, "hello")
  scsLib._stackPush(stack, { key = "value" })
  scsLib._stackPush(stack, { 1, 2, 3 })

  lu.assertEquals(arraySize(stack), 4)
  lu.assertEquals(stack[1], 42)
  lu.assertEquals(stack[2], "hello")
  lu.assertEquals(stack[3].key, "value")
  lu.assertEquals(stack[4][1], 1)
  lu.assertEquals(stack[4][2], 2)
  lu.assertEquals(stack[4][3], 3)
end

-- Integration tests
function TestStackOperations:testIntegration()
  local stack = {}

  -- Push some items
  scsLib._stackPush(stack, 1)
  scsLib._stackPush(stack, 2)
  scsLib._stackPush(stack, 3)

  -- Peek at different positions
  lu.assertEquals(scsLib._stackPeek(stack, 0), 3)
  lu.assertEquals(scsLib._stackPeek(stack, 1), 2)

  -- Pop an item
  lu.assertEquals(scsLib._stackPop(stack), 3)

  -- Peek after pop
  lu.assertEquals(scsLib._stackPeek(stack, 0), 2)

  -- Push new item
  scsLib._stackPush(stack, 4)

  -- Verify final state
  lu.assertEquals(arraySize(stack), 3)
  lu.assertEquals(stack[1], 1)
  lu.assertEquals(stack[2], 2)
  lu.assertEquals(stack[3], 4)
end

function testInternals()
  lu.assertIsFunction(scsLib._charAt, "internals: _charAt is exported")
  -- lu.assertIsFunction(scsLib._commentNeedsSpaceInside)
  lu.assertIsFunction(scsLib._AnyChar, "internals: _AnyChar is exported")
  lu.assertIsFunction(scsLib._flattenTree, "internals: _flattenTree is exported")

  -- charAt
  lu.assertEquals(scsLib._charAt("abc", 1), "a", "internals: _charAt test case 1")
  lu.assertEquals(scsLib._charAt("abc", 3), "c", "internals: _charAt test case 2")

  -- substr
  lu.assertEquals(scsLib._substr("abcdef", 1, 1), "", "internals: _substr test case 1")
  lu.assertEquals(scsLib._substr("abcdef", 1, 3), "ab", "internals: _substr test case 2")
  lu.assertEquals(scsLib._substr("abcdef", 4, 6), "de", "internals: _substr test case 3")
  lu.assertEquals(scsLib._substr("abcdef", 3, -1), "cdef", "internals: _substr test case 4")

  lu.assertTrue(scsLib._commentNeedsSpaceBefore("foo", ";bar"))
  lu.assertTrue(scsLib._commentNeedsSpaceBefore("foo {}", ";bar"))
  lu.assertFalse(scsLib._commentNeedsSpaceBefore("foo ", ";bar"))
  lu.assertFalse(scsLib._commentNeedsSpaceBefore("", ";bar"))
  lu.assertFalse(scsLib._commentNeedsSpaceBefore("foo [", ";bar"))
  lu.assertFalse(scsLib._commentNeedsSpaceBefore("foo (", ";bar"))
  lu.assertFalse(scsLib._commentNeedsSpaceBefore("foo {", ";bar"))

  lu.assertTrue(scsLib._commentNeedsSpaceInside(";foo"))
  lu.assertTrue(scsLib._commentNeedsSpaceInside(";;foo"))
  lu.assertTrue(scsLib._commentNeedsSpaceInside(";;;;;;;foo"))
  lu.assertFalse(scsLib._commentNeedsSpaceInside(";; foo"))
  lu.assertFalse(scsLib._commentNeedsSpaceInside("; foo"))
  lu.assertFalse(scsLib._commentNeedsSpaceInside(";      foo"))
  lu.assertFalse(scsLib._commentNeedsSpaceInside(";"))
  lu.assertFalse(scsLib._commentNeedsSpaceInside(";;"))
  lu.assertFalse(scsLib._commentNeedsSpaceInside(";;;;;;"))

  lu.assertEquals(scsLib._removeLeadingWhitespace("\n ,,"), ",,")
  lu.assertEquals(scsLib._removeLeadingWhitespace(" \n "), "")
  lu.assertEquals(scsLib._removeLeadingWhitespace("  \n\n  "), "")
  lu.assertEquals(scsLib._removeLeadingWhitespace(",, \n "), "")
  lu.assertEquals(scsLib._removeLeadingWhitespace(",, \n\n "), "")
  lu.assertEquals(scsLib._removeLeadingWhitespace(",, \n\n"), "")

  lu.assertTrue(scsLib._txtHasCommasAfterNewline("\n ,,"))
  lu.assertTrue(scsLib._txtHasCommasAfterNewline("\n\n  ,"))
  lu.assertFalse(scsLib._txtHasCommasAfterNewline(" \n "))
  lu.assertFalse(scsLib._txtHasCommasAfterNewline("  \n\n  "))
  lu.assertFalse(scsLib._txtHasCommasAfterNewline(",, \n "))
  lu.assertFalse(scsLib._txtHasCommasAfterNewline(",, \n\n "))
end

TestParsers = {}

function TestParsers:testAnyChar()
  local anyCharTest1 = scsLib._AnyChar({ name = "anychar_test1" })
  lu.assertIsFunction(anyCharTest1.parse)
  lu.assertEquals(anyCharTest1.parse("a", 1).text, "a")
  lu.assertEquals(anyCharTest1.parse("b", 1).text, "b")
  lu.assertEquals(anyCharTest1.parse("b", 1).name, "anychar_test1")
  lu.assertEquals(anyCharTest1.parse(" ", 1).text, " ")
  lu.assertEquals(anyCharTest1.parse("+", 1).text, "+")
  lu.assertEquals(anyCharTest1.parse("!~^", 1).text, "!")
  lu.assertNil(anyCharTest1.parse("", 1))
end

function TestParsers:testChar()
  local charTest1 = scsLib._Char({ char = "a", name = "char_test_a" })
  lu.assertIsFunction(charTest1.parse)
  lu.assertEquals(charTest1.parse("a", 1).name, "char_test_a")
  lu.assertEquals(charTest1.parse("a", 1).text, "a")
  lu.assertEquals(charTest1.parse("a", 1).startIdx, 1)
  lu.assertEquals(charTest1.parse("a", 1).endIdx, 2)
  lu.assertNil(charTest1.parse("=", 1))

  local charTest2 = scsLib._Char({ char = "=", name = "char_test_equals" })
  lu.assertIsFunction(charTest2.parse)
  lu.assertEquals(charTest2.parse("=", 1).name, "char_test_equals")
  lu.assertEquals(charTest2.parse("=", 1).text, "=")
  lu.assertNil(charTest2.parse("a", 1))
end

function TestParsers:testNotChar()
  local notCharTest1 = scsLib._NotChar({ char = "a", name = "notchar_test_a" })

  -- Basic matching
  local result = notCharTest1.parse("b", 1)
  lu.assertEquals(result.name, "notchar_test_a")
  lu.assertEquals(result.text, "b")
  lu.assertEquals(result.startIdx, 1)
  lu.assertEquals(result.endIdx, 2)

  -- -- Failing match
  lu.assertNil(notCharTest1.parse("a", 1))

  -- -- Various characters
  lu.assertEquals(notCharTest1.parse("x", 1).text, "x")
  lu.assertEquals(notCharTest1.parse("1", 1).text, "1")
  lu.assertEquals(notCharTest1.parse(" ", 1).text, " ")
  lu.assertEquals(notCharTest1.parse("!", 1).text, "!")

  -- -- Beyond string length
  lu.assertNil(notCharTest1.parse("xyz", 4))

  -- -- Empty string
  lu.assertNil(notCharTest1.parse("", 1))

  -- -- Special character
  local notCharTest2 = scsLib._NotChar({ char = "$", name = "notchar_test_special" })
  lu.assertEquals(notCharTest2.parse("a", 1).text, "a")
  lu.assertNil(notCharTest2.parse("$", 1))
end

function TestParsers:testString()
  local stringTest1 = scsLib._String({ str = "foo", name = "string_test_foo" })

  -- Basic matching
  local result = stringTest1.parse("foo", 1)
  lu.assertEquals(result.name, "string_test_foo")
  lu.assertEquals(result.text, "foo")
  lu.assertEquals(result.startIdx, 1)
  lu.assertEquals(result.endIdx, 4)

  -- Non-matching
  lu.assertNil(stringTest1.parse("bar", 1))

  -- Partial match
  lu.assertNil(stringTest1.parse("fo", 1))

  -- At end of string
  lu.assertNil(stringTest1.parse("foo", 2))

  -- With leading characters
  local result2 = stringTest1.parse("barfoo", 4)
  lu.assertEquals(result2.name, "string_test_foo")
  lu.assertEquals(result2.startIdx, 4)
  lu.assertEquals(result2.endIdx, 7)
  lu.assertEquals(result2.text, "foo")

  -- With trailing characters
  local result3 = stringTest1.parse("foobar", 1)
  lu.assertEquals(result3.text, "foo")
  lu.assertEquals(result3.endIdx, 4)
end

function TestParsers:testPattern()
  local patternParser1 = scsLib._Pattern({
    pattern = "[cd]+",
    name = "pattern_parser1",
  })

  lu.assertIsFunction(patternParser1.parse)

  -- Test 1: No match at beginning of string
  local patternResult1 = patternParser1.parse("aaacb", 1)
  lu.assertNil(patternResult1)

  -- -- Test 2: Single character match
  local patternResult2 = patternParser1.parse("aaacb", 4)
  lu.assertEquals(patternResult2.name, "pattern_parser1")
  lu.assertEquals(patternResult2.startIdx, 4)
  lu.assertEquals(patternResult2.endIdx, 5)
  lu.assertEquals(patternResult2.text, "c")

  -- -- Test 3: Multiple character match
  local patternResult3 = patternParser1.parse("aaacddb", 4)
  lu.assertEquals(patternResult3.name, "pattern_parser1")
  lu.assertEquals(patternResult3.startIdx, 4)
  lu.assertEquals(patternResult3.endIdx, 7)
  lu.assertEquals(patternResult3.text, "cdd")

  -- -- Test 4: Match starting at different position
  local patternResult4 = patternParser1.parse("aaacddb", 5)
  lu.assertEquals(patternResult4.name, "pattern_parser1")
  lu.assertEquals(patternResult4.startIdx, 5)
  lu.assertEquals(patternResult4.endIdx, 7)
  lu.assertEquals(patternResult4.text, "dd")

  local patternParser2 = scsLib._Pattern({
    pattern = "[^xyz][^xyz]*",
    name = "pattern_parser2",
  })
  local patternResult5 = patternParser2.parse("aaa", 1)
  lu.assertTable(patternResult5)
  lu.assertEquals(patternResult5.startIdx, 1)
  lu.assertEquals(patternResult5.endIdx, 4)
  lu.assertEquals(patternResult5.text, "aaa")

  local patternResult6 = patternParser2.parse("xaa", 1)
  lu.assertNil(patternResult6)
end

function TestParsers:testChoice()
  local choiceTest1 = scsLib._Choice({
    parsers = {
      scsLib._Char({ char = "a", name = ".a" }),
      scsLib._Char({ char = "b", name = ".b" }),
      scsLib._Char({ char = "c", name = ".c" }),
    },
  })

  lu.assertIsFunction(choiceTest1.parse)

  lu.assertEquals(choiceTest1.parse("a", 1).text, "a")
  lu.assertEquals(choiceTest1.parse("b", 1).text, "b")
  lu.assertEquals(choiceTest1.parse("c", 1).text, "c")
  lu.assertNil(choiceTest1.parse("z", 1))
end

function TestParsers:testSeq()
  local testSeq1 = scsLib._Seq({
    name = "seq_test_1",
    parsers = {
      scsLib._Char({ char = "a", name = "AAA" }),
      scsLib._Char({ char = "b", name = "BBB" }),
      scsLib._Char({ char = "c", name = "CCC" }),
    },
  })

  lu.assertIsFunction(testSeq1.parse)

  local seqResult1 = testSeq1.parse("abc", 1)
  lu.assertEquals(seqResult1.startIdx, 1)
  lu.assertEquals(seqResult1.endIdx, 4)
  lu.assertTrue(isArray(seqResult1.children))
  lu.assertEquals(arraySize(seqResult1.children), 3)
  lu.assertEquals(seqResult1.children[1].name, "AAA")
  lu.assertEquals(seqResult1.children[2].name, "BBB")
  lu.assertEquals(seqResult1.children[3].name, "CCC")

  local seqResult2 = testSeq1.parse("aba", 1)
  lu.assertNil(seqResult2)

  local seqResult3 = testSeq1.parse("ab", 1)
  lu.assertNil(seqResult3)

  local seqResult4 = testSeq1.parse("abcd", 1)
  lu.assertEquals(seqResult4.startIdx, 1)
  lu.assertEquals(seqResult4.endIdx, 4)
end

function TestParsers:testRepeat()
  local testRepeat1 = scsLib._Repeat({
    name = "repeat_test_1",
    parser = scsLib._Char({ name = "AAA", char = "a" }),
  })

  local repeatResult1 = testRepeat1.parse("b", 1)
  lu.assertEquals(repeatResult1.startIdx, 1)
  lu.assertEquals(repeatResult1.endIdx, 1)
  lu.assertNil(repeatResult1.name)

  local repeatResult2 = testRepeat1.parse("a", 1)
  lu.assertEquals(repeatResult2.startIdx, 1)
  lu.assertEquals(repeatResult2.endIdx, 2)
  lu.assertEquals(repeatResult2.name, "repeat_test_1")
  lu.assertTrue(isArray(repeatResult2.children))
  lu.assertEquals(arraySize(repeatResult2.children), 1)
  lu.assertEquals(repeatResult2.children[1].startIdx, 1)
  lu.assertEquals(repeatResult2.children[1].endIdx, 2)
  lu.assertEquals(repeatResult2.children[1].text, "a")
  lu.assertEquals(repeatResult2.children[1].name, "AAA")

  local repeatResult3 = testRepeat1.parse("aa", 1)
  lu.assertEquals(repeatResult3.startIdx, 1)
  lu.assertEquals(repeatResult3.endIdx, 3)
  lu.assertEquals(repeatResult3.name, "repeat_test_1")
  lu.assertTrue(isArray(repeatResult3.children))
  lu.assertEquals(arraySize(repeatResult3.children), 2)
  lu.assertEquals(repeatResult3.children[1].startIdx, 1)
  lu.assertEquals(repeatResult3.children[1].endIdx, 2)
  lu.assertEquals(repeatResult3.children[1].text, "a")
  lu.assertEquals(repeatResult3.children[1].name, "AAA")
  lu.assertEquals(repeatResult3.children[2].startIdx, 2)
  lu.assertEquals(repeatResult3.children[2].endIdx, 3)
  lu.assertEquals(repeatResult3.children[2].text, "a")
  lu.assertEquals(repeatResult3.children[2].name, "AAA")

  local repeatResult4 = testRepeat1.parse("baac", 2)
  lu.assertEquals(repeatResult4.startIdx, 2)
  lu.assertEquals(repeatResult4.endIdx, 4)
  lu.assertEquals(repeatResult4.name, "repeat_test_1")
  lu.assertTrue(isArray(repeatResult4.children))
  lu.assertEquals(arraySize(repeatResult4.children), 2)
  lu.assertEquals(repeatResult4.children[1].startIdx, 2)
  lu.assertEquals(repeatResult4.children[1].endIdx, 3)
  lu.assertEquals(repeatResult4.children[1].text, "a")
  lu.assertEquals(repeatResult4.children[1].name, "AAA")
  lu.assertEquals(repeatResult4.children[2].startIdx, 3)
  lu.assertEquals(repeatResult4.children[2].endIdx, 4)
  lu.assertEquals(repeatResult4.children[2].text, "a")
  lu.assertEquals(repeatResult4.children[2].name, "AAA")
end

function TestParsers:testChoice()
  local testChoice1 = scsLib._Choice({
    name = "choice_test_1",
    parsers = {
      scsLib._Char({ name = "A", char = "a" }),
      scsLib._Char({ name = "B", char = "b" }),
      scsLib._Char({ name = "C", char = "c" }),
    },
  })

  -- Test no match case
  local choiceResult1 = testChoice1.parse("x", 1)
  lu.assertNil(choiceResult1)

  -- Test first parser match
  local choiceResult2 = testChoice1.parse("a", 1)
  lu.assertEquals(choiceResult2.startIdx, 1)
  lu.assertEquals(choiceResult2.endIdx, 2)
  lu.assertEquals(choiceResult2.name, "A")
  lu.assertEquals(choiceResult2.text, "a")

  -- Test second parser match
  local choiceResult3 = testChoice1.parse("b", 1)
  lu.assertEquals(choiceResult3.startIdx, 1)
  lu.assertEquals(choiceResult3.endIdx, 2)
  lu.assertEquals(choiceResult3.name, "B")
  lu.assertEquals(choiceResult3.text, "b")

  -- Test third parser match
  local choiceResult4 = testChoice1.parse("c", 1)
  lu.assertEquals(choiceResult4.startIdx, 1)
  lu.assertEquals(choiceResult4.endIdx, 2)
  lu.assertEquals(choiceResult4.name, "C")
  lu.assertEquals(choiceResult4.text, "c")

  -- Test match with offset position
  local choiceResult5 = testChoice1.parse("xab", 2)
  lu.assertEquals(choiceResult5.startIdx, 2)
  lu.assertEquals(choiceResult5.endIdx, 3)
  lu.assertEquals(choiceResult5.name, "A")
  lu.assertEquals(choiceResult5.text, "a")

  -- Test that it stops at first match
  local choiceResult6 = testChoice1.parse("abc", 1)
  lu.assertEquals(choiceResult6.startIdx, 1)
  lu.assertEquals(choiceResult6.endIdx, 2)
  lu.assertEquals(choiceResult6.name, "A")
  lu.assertEquals(choiceResult6.text, "a")
end

-- -----------------------------------------------------------------------------
-- Parser

local parserTestsToSkip = {
  ["String with emoji"] = true,
}

-- NOTE:
-- These test cases come directly from Standard Clojure Style JavaScript, so they are
-- 0-index based. In the nodeToString function we subtract 1 from the parsed result.
local parserTestCases = json.decode(readFile("./test_cases/parser_tests.json"))

function testParser()
  lu.assertTrue(isArray(parserTestCases), "parser_tests.json is not an Array")

  for _key, testCase in pairs(parserTestCases) do
    if not parserTestsToSkip[testCase.name] then
      lu.assertTrue(isNonBlankString(testCase.name), "test case .name is empty")
      lu.assertTrue(isNonBlankString(testCase.input), "test case .input is empty")
      lu.assertTrue(isNonBlankString(testCase.expected), "test case .expected is empty")

      local parsed = scsLib.parse(testCase.input)
      lu.assertTable(parsed, "test parser " .. testCase.name .. " - parsed result is not a table")

      local parsedStr = nodeToString(parsed)
      lu.assertEquals(
        parsedStr,
        testCase.expected,
        "parser test case " .. testCase.name .. " - parsed node string does not match expected"
      )
    end
  end
end

-- -----------------------------------------------------------------------------
-- Parse ns

local parseNsTestsToSkip = {
  -- ["test case here"] = true,
}

local parseNsTestCases = json.decode(readFile("./test_cases/parse_ns_tests.json"))

function testParser()
  lu.assertTrue(isArray(parseNsTestCases), "parse_ns_tests.json is not an Array")

  for _key, testCase in pairs(parseNsTestCases) do
    if not parseNsTestsToSkip[testCase.name] then
      lu.assertTrue(isNonBlankString(testCase.name), "test case .name is empty")
      lu.assertTrue(isNonBlankString(testCase.input), "test case .input is empty")
      lu.assertTrue(isNonBlankString(testCase.expected), "test case .expected is empty")

      -- .expected should be valid JSON
      local expectedStructure = json.decode(testCase.expected)
      lu.assertTable(expectedStructure, "parse_ns test case " .. testCase.name .. " - .expected is invalid JSON")

      local inputNodes = scsLib.parse(testCase.input)
      lu.assertTable(inputNodes, "parse_ns test case " .. testCase.name .. " - inputNodes not a table")
      local flatNodes = scsLib._flattenTree(inputNodes)
      lu.assertTable(flatNodes, "parse_ns test case " .. testCase.name .. " - flatNodes not a table")
      local parsedNs = scsLib.parseNs(flatNodes)
      lu.assertTable(parsedNs, "parse_ns test case " .. testCase.name .. " - parsed result is not a table")

      -- compare the two structures
      local resultIsTheSame = deepCompare(parsedNs, expectedStructure)

      if not resultIsTheSame then
        print("")
        print("parseNs structure does not match: " .. testCase.name)
        print("")
        print("Expected:")
        print(inspect(expectedStructure))
        print("")
        print("Actual:")
        print(inspect(parsedNs))
        print("")
      end

      lu.assertTrue(resultIsTheSame, "parse_ns " .. testCase.name .. " - structure does not match")
    end
  end
end

-- -----------------------------------------------------------------------------
-- Format Tests

local formatTestsToSkip = {
  ["Surrounding newlines removed 3"] = true,
  ["ambiguous import comment"] = true,
}

local formatTestCases = json.decode(readFile("./test_cases/format_tests.json"))

function testParser()
  lu.assertTrue(isArray(formatTestCases), "format_tests.json is not an Array")

  for _key, testCase in pairs(formatTestCases) do
    if not formatTestsToSkip[testCase.name] then
      lu.assertTrue(isNonBlankString(testCase.name), "test case .name is empty")
      lu.assertTrue(isNonBlankString(testCase.input), "test case .input is empty")
      lu.assertTrue(isNonBlankString(testCase.expected), "test case .expected is empty")

      local result = scsLib.format(testCase.input)
      lu.assertTable(result, "format test case " .. testCase.name .. " - format result is not a table")
      lu.assertEquals(
        result.status,
        "success",
        "format test case " .. testCase.name .. " - result.status not 'success'"
      )

      local resultIsTheSame = result.out == testCase.expected

      if not resultIsTheSame then
        print("")
        print("format does not match: " .. testCase.name)
        print("")
        print("Expected:")
        print(testCase.expected)
        print("")
        print("Actual:")
        print(result.out)
        print("")
      end

      lu.assertTrue(resultIsTheSame, "format test case " .. testCase.name .. " - format output does not match")
    end
  end
end

-- -----------------------------------------------------------------------------
-- Run the tests

os.exit(lu.LuaUnit.run())
