local h = require("tests.helpers")
local eq, rows_text, hl_at = h.eq, h.rows_text, h.hl_at
local layout = require("diagnostic-lines.layout")

local ERROR, WARN, HINT = 1, 2, 4

local T = MiniTest.new_set()

T["build()"] = MiniTest.new_set()

T["build()"]["no items gives no rows"] = function()
  eq(layout.build({}, nil), {})
end

T["build()"]["single diagnostic"] = function()
  eq(rows_text(layout.build({ { col = 4, severity = ERROR, message = "boom" } })), {
    "    └──── E: boom",
  })
end

T["build()"]["two columns: rightmost first, connector for the left one"] = function()
  local rows = layout.build({
    { col = 10, severity = ERROR, message = "undefined global 'foo'" },
    { col = 14, severity = WARN, message = "unused local 'bar'" },
  })
  eq(rows_text(rows), {
    "          │   └──── W: unused local 'bar'",
    "          └──────── E: undefined global 'foo'",
  })
  eq(hl_at(rows[1], 10), "DiagnosticVirtualLinesError")
  eq(hl_at(rows[1], 14), "DiagnosticVirtualLinesWarn")
  eq(hl_at(rows[1], 9), nil)
end

T["build()"]["same column stacks most severe first"] = function()
  eq(
    rows_text(layout.build({
      { col = 4, severity = WARN, message = "a" },
      { col = 4, severity = ERROR, message = "b" },
    })),
    { "    ├──── E: b", "    └──── W: a" }
  )
end

T["build()"]["multi-line message keeps pending connectors"] = function()
  eq(
    rows_text(layout.build({
      { col = 0, severity = ERROR, message = "x" },
      { col = 2, severity = ERROR, message = "first\nsecond" },
    })),
    { "│ └──── E: first", "│          second", "└────── E: x" }
  )
end

T["build()"]["empty message still gets a prefix"] = function()
  eq(rows_text(layout.build({ { col = 0, severity = HINT, message = "" } })), { "└──── H: " })
end

T["build() wrapping"] = MiniTest.new_set()

T["build() wrapping"]["wraps to the space left after the prefix"] = function()
  -- text starts at column 9, so width 19 leaves exactly MIN_WRAP_WIDTH (10)
  eq(rows_text(layout.build({ { col = 0, severity = ERROR, message = "aaa bbb ccc ddd" } }, 19)), {
    "└──── E: aaa bbb",
    "         ccc ddd",
  })
end

T["build() wrapping"]["does not wrap below MIN_WRAP_WIDTH"] = function()
  eq(rows_text(layout.build({ { col = 0, severity = ERROR, message = "aaa bbb ccc ddd" } }, 18)), {
    "└──── E: aaa bbb ccc ddd",
  })
  eq(rows_text(layout.build({ { col = 0, severity = ERROR, message = "aaa bbb ccc ddd" } }, 15)), {
    "└──── E: aaa bbb ccc ddd",
  })
end

T["build() wrapping"]["pending connectors continue through wrapped lines"] = function()
  eq(
    rows_text(layout.build({
      { col = 10, severity = ERROR, message = "undefined global 'foo'" },
      {
        col = 14,
        severity = WARN,
        message = "this is a very long message that would otherwise run off the edge of the window",
      },
    }, 63)),
    {
      "          │   └──── W: this is a very long message that would",
      "          │            otherwise run off the edge of the window",
      "          └──────── E: undefined global 'foo'",
    }
  )
end

return T
