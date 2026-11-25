local h = require("tests.helpers")
local eq, expect = h.eq, h.expect
local config = require("diagnostic-lines.config")

local T = MiniTest.new_set()

T["resolve()"] = MiniTest.new_set()

T["resolve()"]["nil gives defaults"] = function()
  eq(config.resolve(nil), { wrap = true })
end

T["resolve()"]["true gives defaults"] = function()
  eq(config.resolve(true), { wrap = true })
end

T["resolve()"]["user values override defaults"] = function()
  eq(config.resolve({ wrap = false }).wrap, false)
end

T["resolve()"]["keeps format function"] = function()
  local f = function()
    return "x"
  end
  eq(config.resolve({ format = f }).format, f)
end

T["resolve()"]["rejects non-boolean wrap"] = function()
  expect.error(function()
    config.resolve({ wrap = "yes" })
  end, "wrap")
end

T["resolve()"]["rejects non-function format"] = function()
  expect.error(function()
    config.resolve({ format = 1 })
  end, "format")
end

T["resolve()"]["does not mutate defaults"] = function()
  config.resolve({ wrap = false })
  eq(config.defaults.wrap, true)
end

T["helpers.hl_at()"] = function()
  local row = { { "ab", "A" }, { "cd", "B" } }
  eq(h.hl_at(row, 1), "A")
  eq(h.hl_at(row, 2), "B")
  eq(h.hl_at(row, 9), nil)
end

return T
