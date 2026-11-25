# diagnostic-lines.nvim — Design

**Date:** 2026-11-25
**Status:** Approved (PR #1)

> The key decisions behind this design are recorded as ADRs in
> [`docs/adr/`](../../adr/README.md). This doc is the overview; each ADR
> has the options and trade-offs for one decision.

## 1. Intent

A Neovim plugin that shows every LSP diagnostic (errors, warnings, info,
hints) as **virtual lines underneath the line that caused it**, always on,
for the whole buffer.

Neovim 0.11 already ships a `virtual_lines` diagnostic handler that does
something similar. This plugin exists to do the one thing core can't:
core's handler lets long messages run off the right edge of the window,
and that can't be configured through `vim.diagnostic.config()`. This
plugin's end goal is to **wrap long messages** so they always fit the
window.

It is built for personal use first. Publishing it for others is fine but
not a driver.

## 2. What it looks like

Several diagnostics on one line, drawn rightmost-first, with connectors
for the ones still waiting to be drawn:

```
local x = foo(bar, baz)
          │   └──── W: unused local 'bar'
          └──────── E: undefined global 'foo'
```

The end goal: a long message wraps, and continuation lines line up with
the start of the message text. Connectors for diagnostics further left
keep going down through the continuation lines:

```
local x = foo(bar, baz)
          │   └──── W: this is a very long message that would
          │            otherwise run off the edge of the window
          └──────── E: undefined global 'foo'
```

## 3. Goals

- Every diagnostic in the buffer is shown under its line, as virtual
  lines, whenever diagnostics are shown.
- Several diagnostics on one line are all shown, with the connector
  layout above.
- Long messages wrap to fit the window (the milestone that makes this
  plugin worth having over core).
- Configured the idiomatic way, through `vim.diagnostic.config()`, so it
  works with per-namespace config and severity filtering like core
  handlers do.
- Code is structured so the layout logic can be unit-tested without a
  UI.

## 4. Non-goals (for now)

- A "current line only" mode. Core already has one; it can come later.
- Floating windows, hover, code actions, or a diagnostics list.
- Supporting Neovim older than 0.11.
- Matching every option core's `virtual_lines` has.

## 5. Anti-goals (failure even if it "works")

- Visible lag or flicker while typing in a normal-sized file.
- Silently changing the user's other diagnostic settings (e.g. turning
  off `virtual_text` behind their back).
- Layout logic tangled up with `nvim_buf_set_extmark` calls, so that it
  can't be tested on its own.
- Wrapped lines that still overflow the window in a common case (e.g. a
  vertical split).

## 6. Constraints

- Neovim **0.11+**.
- Pure Lua, no external dependencies at runtime.
- Extmarks (and therefore `virt_lines`) belong to a **buffer**, not a
  window. The same buffer open in two windows of different widths gets
  one set of virtual lines. This shapes the wrapping design (see §8.4).

## 7. Approaches considered

| Approach | Trade-off |
|---|---|
| **A. Own diagnostic handler, rebuilt from scratch, then add wrapping** *(chosen)* | Full control of layout; ends with a feature core lacks. More work than B. |
| B. Thin wrapper around core's `virtual_lines` (toggles, presets) | Quick and useful, but can't add wrapping. |
| C. Use core for a week first, design around annoyances | Zero code, but there were no specific annoyances to design around yet, so it gives no direction. Can still run in parallel. |

Chosen: **A** ([ADR-0001](../../adr/0001-custom-diagnostic-handler.md)).

Other decisions: [ADR-0002](../../adr/0002-configure-through-vim-diagnostic-config.md)
(config via `vim.diagnostic.config()`),
[ADR-0003](../../adr/0003-pure-layout-core.md) (pure layout core),
[ADR-0004](../../adr/0004-wrap-to-narrowest-window.md) (narrowest-window
wrapping), [ADR-0005](../../adr/0005-minimum-neovim-0-11.md) (Neovim 0.11+).

## 8. Design

### 8.1 How it plugs in

Neovim's diagnostics have a handler interface: any table with `show` and
`hide` functions registered in `vim.diagnostic.handlers` becomes a
diagnostic display, enabled through `vim.diagnostic.config()`. This is the
Strategy pattern (and open/closed): core doesn't change, we just add a
new strategy.

- `plugin/diagnostic-lines.lua` registers the handler as
  `vim.diagnostic.handlers.diagnostic_lines` on startup. Registering does
  nothing visible on its own.
- The user turns it on, and passes options, the same way as any core
  handler:

  ```lua
  vim.diagnostic.config({
    virtual_text = false,     -- user's choice; we don't touch it
    diagnostic_lines = {
      wrap = true,
    },
  })
  ```

- No `setup()` function. One way to configure, the core way.

### 8.2 Modules

Each module has one job. Only `render` and `handler` talk to the Neovim
UI API.

| Module | Job | Pure? |
|---|---|---|
| `diagnostic-lines.config` | Defaults, merging user options, validating them (`vim.validate`). | Yes |
| `diagnostic-lines.wrap` | Split one message into pieces that fit a given display width. Must use display width (`vim.fn.strdisplaywidth` or equivalent), not byte length, so multibyte and wide characters are right. Breaks at spaces where possible; hard-breaks a word that's longer than the width. | Yes |
| `diagnostic-lines.layout` | Given the diagnostics for one line, the options, and an available width, return the rows to draw: a list of rows, each a list of `{text, highlight_group}` chunks (the shape `virt_lines` takes). Owns connector drawing, ordering and wrapping (via `wrap`). | Yes |
| `diagnostic-lines.render` | Turn layout output into extmarks in the plugin's namespace; clear them. | No |
| `diagnostic-lines.handler` | The `{ show, hide }` table. Groups diagnostics by line, works out width, calls `layout` and `render`. Remembers the last diagnostics/options per buffer so it can redraw on resize. | No |

### 8.3 Layout rules

- Diagnostics on a line are grouped by start column.
- Drawn **rightmost column first** (top row), so connectors for columns to
  the left run straight down past it, as in the §2 sketch.
- Several diagnostics at the same column: stacked, most severe first.
- The message prefix shows severity (`E:`, `W:`, `I:`, `H:`), and the
  user can replace the whole message text with a `format(diagnostic)`
  option, like core.
- A diagnostic whose column is past the end of the line (common at end of
  line) is clamped to the line's last column.
- Leading indentation of the source line is respected: connectors start
  at the diagnostic's screen column, which accounts for tabs
  (`virtcol`-style), not its byte column.
- A diagnostic spanning several lines is anchored to its **start** line
  (`lnum`, `col`). *(Claude's call.)*
- Highlights link to core's existing groups
  (`DiagnosticVirtualLinesError`, `...Warn`, `...Info`, `...Hint`) so
  colourschemes work out of the box.

### 8.4 Wrapping (the end goal)

- Window text width = window width minus the sign/number/fold columns
  (`getwininfo(win)[1].textoff`), because virtual lines start at the
  text area, not the gutter.
- Available width for a message = window text width − the message's
  starting screen column.
- Continuation lines start at the same column as the first character of
  the message text (after the `E: ` prefix), and pending connectors to
  the left carry on through them.
- **Which window's width?** Because virtual lines belong to the buffer
  (§6), we use the **narrowest window currently showing the buffer**, so
  nothing overflows in any of them. In a wider window the wrap will be a
  bit earlier than necessary; that's the accepted trade-off.
  *(Open to change.)*
- Redraw on `WinResized` and `VimResized` for affected buffers, using the
  remembered diagnostics, so resizing a split rewraps.
- If the available width gets silly-small (e.g. under 10 columns), stop
  wrapping and let it overflow rather than draw one character per row.
- `wrap = false` gives core-like behaviour (no wrapping).

### 8.5 Options (initial)

| Option | Default | Meaning |
|---|---|---|
| `wrap` | `true` | Wrap long messages to fit the window. |
| `format` | `nil` | `function(diagnostic) -> string` to replace message text. |
| `severity` | (core handles it) | Standard core severity filter, applied before our handler runs. |

Connector characters are fixed for v1 (`│`, `└`, `─`).
*(Claude's call: make them configurable later if wanted.)*

## 9. Build order (working back from the end goal)

The end goal is wrapping. To get there, in order:

1. Handler registered, one diagnostic per line drawn as a single virtual
   line under it. (Proves the plumbing.)
2. Multiple diagnostics per line with the connector layout.
3. Wrapping, plus redraw on resize.
4. Docs: README with install + config example, and `doc/diagnostic-lines.txt`
   for `:help`.

## 10. Testing

- `wrap` and `layout` are pure, so they get thorough unit tests: multiple
  columns, same-column stacking, clamping, tabs, multibyte text,
  wrapping at word boundaries and inside long words, tiny widths.
- `render`/`handler` get a few integration tests in headless Neovim:
  set diagnostics with `vim.diagnostic.set`, then check
  `nvim_buf_get_extmarks(..., { details = true })`.
- Tests run in GitHub Actions against Neovim stable.

## 11. Left to the builder

- Test framework choice (e.g. `mini.test`, or busted via `nlua`), as long
  as tests run headless and in CI.
- Exact internal function signatures and file layout under `lua/`.
- How `hide` and re-`show` are debounced, if at all, as long as the
  "no visible lag" anti-goal holds.
- Lua type annotations (LuaLS `---@class` etc.): encouraged.
- Behaviour with `nowrap` + horizontal scrolling (`leftcol`): pick
  whichever extmark options (`virt_lines_leftcol`, `virt_lines_overflow`)
  keep connectors lined up with the text, and note it in the README.

## 12. Notes

- Insert mode and update timing are handled by core
  (`update_in_insert`): core simply doesn't call our `show` when it
  shouldn't. Nothing to build.
- If the user enables both core `virtual_lines` and `diagnostic_lines`,
  they'll see both. We don't fight that; the README says to pick one.
