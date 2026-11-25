local h = require("tests.helpers")
local eq = h.eq
local wrap = require("diagnostic-lines.wrap")

local T = MiniTest.new_set()

T["wrap()"] = MiniTest.new_set()

T["wrap()"]["text that fits is unchanged"] = function()
  eq(wrap.wrap("hello world", 20), { "hello world" })
end

T["wrap()"]["breaks at spaces"] = function()
  eq(wrap.wrap("hello world", 5), { "hello", "world" })
  eq(wrap.wrap("aaa bbb", 3), { "aaa", "bbb" })
end

T["wrap()"]["hard-breaks a word wider than the width"] = function()
  eq(wrap.wrap("abcdefghij", 4), { "abcd", "efgh", "ij" })
  eq(wrap.wrap("ab cdefghij", 4), { "ab", "cdef", "ghij" })
end

T["wrap()"]["newlines always break"] = function()
  eq(wrap.wrap("a\nb c", 10), { "a", "b c" })
end

T["wrap()"]["measures display width, not bytes"] = function()
  eq(wrap.wrap("héllo wörld", 5), { "héllo", "wörld" })
  eq(wrap.wrap("日本語テキスト", 6), { "日本語", "テキス", "ト" })
end

T["wrap()"]["double space at a break does not leave an empty line"] = function()
  eq(wrap.wrap("aaa  bbb", 3), { "aaa", "bbb" })
end

T["wrap()"]["empty text gives one empty line"] = function()
  eq(wrap.wrap("", 10), { "" })
end

T["wrap()"]["nil width only splits on newlines"] = function()
  eq(wrap.wrap("hello world", nil), { "hello world" })
  eq(wrap.wrap("a\nb", nil), { "a", "b" })
end

return T
