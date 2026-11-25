# diagnostic-lines.nvim v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `vim.diagnostic` handler that draws every diagnostic as virtual lines under its line, with connector layout and wrapping to the window width.

**Architecture:** Functional core / imperative shell (ADR-0003). Pure modules (`config`, `wrap`, `layout`) turn plain tables into `virt_lines` rows; shell modules (`render`, `handler`) read buffers/windows and set extmarks. Registered as `vim.diagnostic.handlers.diagnostic_lines` and configured only through `vim.diagnostic.config()` (ADR-0001, ADR-0002).

**Tech Stack:** Lua (LuaJIT, Neovim 0.11+ API), [mini.test](https://github.com/echasnovski/mini.test) for tests (dev-only), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-25-diagnostic-lines-design.md`, plus ADRs in `docs/adr/`.

## Global Constraints

- Neovim **0.11+**: `plugin/` warns once and does nothing if `vim.fn.has("nvim-0.11") == 0`.
- Pure Lua, **no runtime dependencies**. mini.test is cloned to `deps/` by `make` and gitignored.
- Handler key is `diagnostic_lines`. **No `setup()` function.**
- Never change the user's other diagnostic settings (e.g. don't touch `virtual_text`).
- `config.lua`, `wrap.lua`, `layout.lua` make **no `vim.api` calls**. Allowed: `vim.fn.strdisplaywidth`, `vim.fn.strcharpart`, `vim.fn.strchars`, `vim.split`, `vim.validate`, `vim.tbl_*`.
- Highlight groups: `DiagnosticVirtualLinesError` / `Warn` / `Info` / `Hint` (severity 1–4). Prefixes: `E` / `W` / `I` / `H`.
- Connector characters are fixed: `│ └ ├ ─`.
- Message prefix starts at display column `max_col + 6`; message text starts at `max_col + 9` (`max_col` = rightmost diagnostic column on that line).
- `MIN_WRAP_WIDTH = 10`: below this available width, don't wrap.
- Docs are about the plugin, not the person: no personal names or motivations (public repo).
- Every commit ends with the session's `Co-Authored-By` / `Claude-Session` trailers.

## Review Focus

1. **Multi-line messages** (`"\n"` inside a diagnostic, common with rust-analyzer and TypeScript): each line is its own row; nothing is drawn as a literal newline. Tested in Task 2 and Task 4.
2. **Stale line numbers** (diagnostic `lnum` past the end of the buffer after lines are deleted): no error; the diagnostic is drawn under the last line. Tested in Task 3.
3. **Several LSP clients on one buffer** (several diagnostic namespaces): each is drawn, and hiding one leaves the others. Tested in Task 3.
4. **Hidden buffer** (diagnostics arrive for a buffer in no window): drawn without wrapping, rewrapped when it's shown. Tested in Task 6.
5. **Tabs and multibyte text before the diagnostic column**: the connector sits under the right character. Tested in Task 3.

## Delivery

Each PR goes up for review; the next one branches from `main` after merge.

| PR | Tasks | Spec build step |
|---|---|---|
| 1 | 1–3 | Steps 1–2: diagnostics visible, connector layout |
| 2 | 4–6 | Step 3: wrapping + resize |
| 3 | 7 | Step 4: docs |

## File Structure

| Path | Responsibility |
|---|---|
| `plugin/diagnostic-lines.lua` | Version check; register handler; create autocmds. |
| `lua/diagnostic-lines/config.lua` | Defaults, merge, validate. |
| `lua/diagnostic-lines/wrap.lua` | Split text into display-width-limited pieces. |
| `lua/diagnostic-lines/layout.lua` | Items for one line → `virt_lines` rows. |
| `lua/diagnostic-lines/render.lua` | Namespaces and extmarks. |
| `lua/diagnostic-lines/handler.lua` | `show` / `hide`, per-buffer state, width, refresh. |
| `tests/minimal_init.lua` | Test runtime: rtp, mini.test, load plugin. |
| `tests/helpers.lua` | `row_text(row)`, `hl_at(row, col)`, `rows_text(rows)`. |
| `tests/test_*.lua` | One file per module. |
| `Makefile` | `deps`, `test`, `test FILE=…`. |
| `.github/workflows/test.yml` | CI on stable + nightly. |
| `README.md`, `doc/diagnostic-lines.txt` | User docs. |

---

### Task 1: Test harness and `config`

**Files:**
- Create: `Makefile`, `tests/minimal_init.lua`, `tests/helpers.lua`, `.github/workflows/test.yml`, `lua/diagnostic-lines/config.lua`, `tests/test_config.lua`
- Modify: `.gitignore` (add `deps/`)

**Interfaces:**
- Produces:
  ```lua
  ---@class DiagnosticLines.Config
  ---@field wrap boolean
  ---@field format? fun(d: vim.Diagnostic): string
  config.defaults  -- { wrap = true }
  config.resolve(user: boolean|table|nil): DiagnosticLines.Config
  ```
  `tests/helpers.lua`:
  - `row_text(row: Chunk[]): string` concatenates chunk texts.
  - `rows_text(rows: Chunk[][]): string[]` maps that over rows.
  - `hl_at(row: Chunk[], col: integer): string|nil` is the highlight of the chunk covering 0-based display column `col`.
  - `eq = MiniTest.expect.equality` and `expect = MiniTest.expect`. Every test file starts with `local h = require("tests.helpers")` and these locals.

- [ ] **Step 1: Harness.** `Makefile`:
  - `deps/mini.test` clones `https://github.com/echasnovski/mini.test` with `--depth 1`.
  - `test` runs `nvim --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run()"`.
  - `test` with `FILE=…` uses `MiniTest.run_file('$(FILE)')` instead.

  `minimal_init.lua` prepends `.` and `deps/mini.test` to `runtimepath`, calls `require('mini.test').setup()`, and runs `runtime plugin/diagnostic-lines.lua`. CI uses `rhysd/action-setup-vim@v1` with `neovim: true`, matrix `version: [stable, nightly]`, then `make test`. If `nvim` isn't on PATH locally, install the latest stable release tarball first.

- [ ] **Step 2: Write failing tests** in `tests/test_config.lua`:
  ```lua
  eq(config.resolve(nil),  { wrap = true })
  eq(config.resolve(true), { wrap = true })
  eq(config.resolve({ wrap = false }).wrap, false)
  local f = function() return "x" end
  eq(config.resolve({ format = f }).format, f)
  expect.error(function() config.resolve({ wrap = "yes" }) end, "wrap")
  expect.error(function() config.resolve({ format = 1 }) end, "format")
  -- resolve must not mutate defaults
  config.resolve({ wrap = false }); eq(config.defaults.wrap, true)
  ```
  Also test `helpers.hl_at` on `{ {"ab","A"}, {"cd","B"} }`: col 1 → `"A"`, col 2 → `"B"`, col 9 → `nil`.

- [ ] **Step 3: Run** `make test FILE=tests/test_config.lua`. Expected: failures, because `diagnostic-lines.config` isn't found.

- [ ] **Step 4: Implement** `config.resolve` with `vim.tbl_extend("force", {}, defaults, user_table)` and `vim.validate`. Use `true`/`nil` → defaults.

- [ ] **Step 5: Run** `make test`. Expected: exit 0, `Fails (0)`.

- [ ] **Step 6: Commit** `chore: test harness and CI` + `feat: config resolution`. Two commits are fine; one is also fine.

---

### Task 2: `layout` (connectors, no width wrapping)

**Files:**
- Create: `lua/diagnostic-lines/layout.lua`, `tests/test_layout.lua`

**Interfaces:**
- Produces:
  ```lua
  ---@class DiagnosticLines.Item
  ---@field col integer       -- 0-based DISPLAY column on the source line
  ---@field severity integer  -- vim.diagnostic.severity (1..4)
  ---@field message string    -- already formatted; may contain "\n"
  ---@alias DiagnosticLines.Chunk { [1]: string, [2]: string? }
  ---@alias DiagnosticLines.Row DiagnosticLines.Chunk[]
  layout.HL             -- { [1]="DiagnosticVirtualLinesError", [2]="...Warn", [3]="...Info", [4]="...Hint" }
  layout.PREFIX         -- { "E", "W", "I", "H" }
  layout.MIN_WRAP_WIDTH -- 10
  layout.build(items: DiagnosticLines.Item[], width: integer|nil): DiagnosticLines.Row[]
  ```
  `width` is ignored until Task 5.

**Layout algorithm** (not determined by the signature):
1. Sort items by `col` descending, then `severity` ascending; keep input order for ties (stable).
2. `prefix_col = max_col + 6`, `text_col = prefix_col + 3`.
3. For item `k`, the *pending* columns are the columns of items after `k`. Each gets `│` in the highlight of the first later item at that column.
4. First row of item `k`:
   - spaces and pending `│` for columns `0 .. col-1`
   - `├` if a later item shares `col`, else `└`
   - `─` × `(prefix_col - col - 2)`
   - one space
   - `PREFIX[sev] .. ": " .. line1`
   - Glyph, arm and text all use the item's highlight.
5. Each further message line (split on `"\n"`, plain): pending `│`s (including at `col` when a later item shares it) and spaces up to `text_col`, then the line in the item's highlight.
6. Spaces carry no highlight (`{ "   " }`). Chunking is free; tests use the helpers.

- [ ] **Step 1: Write failing tests** (assert with `rows_text`, plus `hl_at` where noted):
  ```lua
  -- empty
  eq(layout.build({}, nil), {})
  -- single
  eq(rows_text(layout.build({ {col=4, severity=1, message="boom"} })),
     { "    └──── E: boom" })
  -- two columns (spec §2 sketch)
  local rows = layout.build({
    { col=10, severity=1, message="undefined global 'foo'" },
    { col=14, severity=2, message="unused local 'bar'" } })
  eq(rows_text(rows), {
    "          │   └──── W: unused local 'bar'",
    "          └──────── E: undefined global 'foo'" })
  eq(hl_at(rows[1], 10), "DiagnosticVirtualLinesError")
  eq(hl_at(rows[1], 14), "DiagnosticVirtualLinesWarn")
  eq(hl_at(rows[1], 9), nil)
  -- same column: most severe first
  eq(rows_text(layout.build({ {col=4,severity=2,message="a"}, {col=4,severity=1,message="b"} })),
     { "    ├──── E: b", "    └──── W: a" })
  -- multi-line message with a pending connector (Review Focus 1)
  eq(rows_text(layout.build({ {col=0,severity=1,message="x"}, {col=2,severity=1,message="first\nsecond"} })),
     { "│ └──── E: first", "│          second", "└────── E: x" })
  -- empty message
  eq(rows_text(layout.build({ {col=0,severity=4,message=""} })), { "└──── H: " })
  ```

- [ ] **Step 2: Run** `make test FILE=tests/test_layout.lua`. Expected: FAIL (module missing).
- [ ] **Step 3: Implement** `layout.build` per the algorithm above.
- [ ] **Step 4: Run** `make test`. Expected: `Fails (0)`.
- [ ] **Step 5: Commit** `feat: layout diagnostics with connectors`.

---

### Task 3: `render`, `handler`, plugin registration

**Files:**
- Create: `lua/diagnostic-lines/render.lua`, `lua/diagnostic-lines/handler.lua`, `plugin/diagnostic-lines.lua`, `tests/test_handler.lua`

**Interfaces:**
- Consumes: `config.resolve`, `layout.build`, `layout.HL`.
- Produces:
  ```lua
  render.namespace_for(source_ns: integer): integer  -- cached nvim_create_namespace("diagnostic_lines." .. source_ns)
  render.draw(source_ns, bufnr, lnum: integer, rows: DiagnosticLines.Row[])  -- one extmark at (lnum, 0), virt_lines = rows, virt_lines_leftcol = false
  render.clear(source_ns, bufnr)
  handler.show(namespace, bufnr, diagnostics, opts)  -- opts.diagnostic_lines is the handler's user config
  handler.hide(namespace, bufnr)
  handler.text_width(bufnr): integer|nil  -- returns nil in this task; real in Task 6
  ```
  `plugin/`: version guard (`vim.notify(..., WARN)` once), then `vim.diagnostic.handlers.diagnostic_lines = require("diagnostic-lines.handler")`.

**`show` behaviour:**
- Return if the buffer isn't loaded.
- Clear this source namespace, then group diagnostics by `lnum`. Clamp `lnum` to `line_count - 1` (Review Focus 2).
- Convert each byte `col` to a display column with `vim.fn.strdisplaywidth(line:sub(1, col))` inside `nvim_buf_call(bufnr, …)` so the buffer's `tabstop` applies.
- Then clamp it to `max(strdisplaywidth(line) - 1, 0)`. Clamping the display column, not the byte column, never lands mid-character.
- Use the message from `cfg.format(d)` if set, else `d.message`.
- Call `layout.build(items, handler.text_width(bufnr))`, then `render.draw`.
- Store `{ diagnostics, opts }` in `state[bufnr][namespace]` for Task 6. `hide` clears and drops that entry.

- [ ] **Step 1: Write failing tests.** Before each case:
  - create a scratch buffer and show it in the current window
  - `vim.diagnostic.config({ virtual_text = false, virtual_lines = false, diagnostic_lines = true })`
  - make a fresh source namespace `ns`

  After each case, wipe the buffer and `vim.diagnostic.reset()`. Helper:
  ```lua
  local function virt(ns, buf)  -- { [row] = rows_text(virt_lines) }
    local out = {}
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, render.namespace_for(ns), 0, -1, { details = true })) do
      out[m[2]] = rows_text(m[4].virt_lines)
    end
    return out
  end
  ```
  Cases (E = severity ERROR):
  ```lua
  -- two diagnostics on "local x = foo(bar, baz)" at cols 10 (E) and 14 (W)
  eq(virt(ns, buf), { [0] = {
    "          │   └──── W: unused local 'bar'",
    "          └──────── E: undefined global 'foo'" } })
  -- lines 0 and 2 → keys 0 and 2
  -- vim.diagnostic.hide(ns, buf) → eq(virt(ns, buf), {})
  -- vim.diagnostic.config({ diagnostic_lines = false }) then set → {}
  -- diagnostic_lines = { format = function() return "X" end } → row "└──── E: X"
  -- "abc", col = 50 → { "  └──── E: m" }                        (clamp)
  -- tabstop=4, line "\tx = 1", col = 1 → "    └──── E: m"          (Review Focus 5)
  -- line "é = x", col = 5 → "    └──── E: m"                       (Review Focus 5)
  -- 1-line buffer, lnum = 5 → no error, key 0                       (Review Focus 2)
  -- ns1 and ns2 both set on line 0 → both drawn; hide(ns1) leaves ns2  (Review Focus 3)
  ```
- [ ] **Step 2: Run** `make test FILE=tests/test_handler.lua`. Expected: FAIL.
- [ ] **Step 3: Implement** `render`, `handler`, `plugin/diagnostic-lines.lua`.
- [ ] **Step 4: Run** `make test`. Expected: `Fails (0)`.
- [ ] **Step 5: Manual check.** Open a Lua file with a deliberate error under `lua_ls`, with the config from the spec §8.1. Lines appear and disappear as you fix the error.
- [ ] **Step 6: Commit** `feat: render diagnostics as virtual lines`. Open **PR 1**.

---

### Task 4: `wrap`

**Files:**
- Create: `lua/diagnostic-lines/wrap.lua`, `tests/test_wrap.lua`

**Interfaces:**
- Produces: `wrap.wrap(text: string, width: integer|nil): string[]`

Behaviour:
1. Split on `"\n"` first.
2. If `width` is nil, return those pieces.
3. Otherwise fill each piece greedily word by word, measuring with `vim.fn.strdisplaywidth`, and drop the space at a break.
4. A word wider than `width` is hard-broken by characters (`strcharpart`), never mid-character.

- [ ] **Step 1: Write failing tests:**
  ```lua
  eq(wrap.wrap("hello world", 20), { "hello world" })
  eq(wrap.wrap("hello world", 5),  { "hello", "world" })
  eq(wrap.wrap("aaa bbb", 3),      { "aaa", "bbb" })
  eq(wrap.wrap("abcdefghij", 4),   { "abcd", "efgh", "ij" })
  eq(wrap.wrap("a\nb c", 10),      { "a", "b c" })             -- Review Focus 1
  eq(wrap.wrap("héllo wörld", 5),  { "héllo", "wörld" })
  eq(wrap.wrap("日本語テキスト", 6), { "日本語", "テキス", "ト" })
  eq(wrap.wrap("", 10),            { "" })
  eq(wrap.wrap("hello world", nil), { "hello world" })
  eq(wrap.wrap("a\nb", nil),       { "a", "b" })
  ```
- [ ] **Step 2: Run** `make test FILE=tests/test_wrap.lua`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `make test`. Expected: `Fails (0)`.
- [ ] **Step 5: Commit** `feat: display-width aware text wrapping`.

---

### Task 5: Wrapping in `layout`

**Files:**
- Modify: `lua/diagnostic-lines/layout.lua`, `tests/test_layout.lua`

**Interfaces:**
- Consumes: `wrap.wrap`.
- Changes: `layout.build(items, width)` now honours `width`, the window's text-area width. Available width is `width - text_col`. If `width` is nil or the available width is under `MIN_WRAP_WIDTH`, call `wrap.wrap(msg, nil)`; otherwise call `wrap.wrap(msg, available)`. Continuation rows reuse Task 2's rule 5 unchanged.

- [ ] **Step 1: Write failing tests:**
  ```lua
  eq(rows_text(layout.build({ {col=0,severity=1,message="aaa bbb ccc ddd"} }, 19)),
     { "└──── E: aaa bbb", "         ccc ddd" })
  -- under MIN_WRAP_WIDTH → no wrap
  eq(rows_text(layout.build({ {col=0,severity=1,message="aaa bbb ccc ddd"} }, 15)),
     { "└──── E: aaa bbb ccc ddd" })
  -- spec §2 wrapped sketch
  eq(rows_text(layout.build({
      { col=10, severity=1, message="undefined global 'foo'" },
      { col=14, severity=2, message="this is a very long message that would otherwise run off the edge of the window" } }, 63)),
     { "          │   └──── W: this is a very long message that would",
       "          │            otherwise run off the edge of the window",
       "          └──────── E: undefined global 'foo'" })
  ```
- [ ] **Step 2: Run** `make test FILE=tests/test_layout.lua`. Expected: the new cases FAIL; Task 2 cases still pass.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `make test`. Expected: `Fails (0)`.
- [ ] **Step 5: Commit** `feat: wrap long messages to the available width`.

---

### Task 6: Narrowest-window width and refresh

**Files:**
- Modify: `lua/diagnostic-lines/handler.lua`, `lua/diagnostic-lines/config.lua`, `plugin/diagnostic-lines.lua`, `tests/test_handler.lua`

**Interfaces:**
- Produces:
  ```lua
  handler.text_width(bufnr): integer|nil
  -- min over vim.fn.win_findbuf(bufnr) of nvim_win_get_width(w) - vim.fn.getwininfo(w)[1].textoff; nil if none
  handler.refresh(bufnr?)
  -- re-run show() for every stored namespace of bufnr (all tracked buffers if nil)
  ```
- `show` passes `nil` width when `cfg.wrap == false`.
- Autocmds in augroup `diagnostic_lines`:
  - `WinResized` refreshes buffers of `vim.v.event.windows`, or all tracked buffers if that's empty
  - `VimResized` refreshes all tracked buffers
  - `BufWinEnter` refreshes `args.buf`
  - `BufWipeout` drops the state for `args.buf`

- [ ] **Step 1: Write failing tests:**
  ```lua
  -- buf's window next to an unrelated `vnew` window (a lone window can't be resized), width 40, number on
  vim.cmd("vnew | wincmd p"); vim.api.nvim_win_set_width(0, 40); vim.wo.number = true
  eq(handler.text_width(buf), 40 - vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].textoff)
  -- two splits on buf (30 and 50, no number) → 30
  -- buffer in no window → nil
  -- long message: set diagnostic, shrink window, handler.refresh(buf) → row count increases
  -- vim.api.nvim_exec_autocmds("VimResized", {}) also rewraps
  -- hidden buffer (Review Focus 4): set diagnostics while hidden → single unwrapped row;
  --   show it in a 30-wide window → BufWinEnter rewraps to more rows
  -- diagnostic_lines = { wrap = false } in a 30-wide window → single row
  ```
- [ ] **Step 2: Run** `make test FILE=tests/test_handler.lua`. Expected: new cases FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `make test`. Expected: `Fails (0)`.
- [ ] **Step 5: Manual check.** Use `:vsplit` on a file with a long diagnostic. Messages wrap to the narrower split, and resizing with `<C-w><` rewraps.
- [ ] **Step 6: Commit** `feat: wrap to narrowest window and refresh on resize`. Open **PR 2**.

---

### Task 7: Docs

**Files:**
- Modify: `README.md`
- Create: `doc/diagnostic-lines.txt`

Contents for both:
- what it does, in one paragraph
- the spec §2 sketches
- requirements (Neovim 0.11+)
- install with lazy.nvim and a plain `packpath` clone
- the config example from spec §8.1
- options: `wrap`, `format`
- toggling with `vim.diagnostic.config({ diagnostic_lines = false })`
- highlight groups
- a note to disable core `virtual_lines` / `virtual_text` and pick one
- behaviour in splits (ADR-0004)
- behaviour with `nowrap` horizontal scrolling

The help file has tags `diagnostic-lines`, `diagnostic-lines-config` and `diagnostic-lines-highlights`. No personal names (Global Constraints).

- [ ] **Step 1:** Write both files.
- [ ] **Step 2: Verify** with `nvim --headless -c "helptags doc" -c q`. Expected: exit 0, `doc/tags` created with the three tags. Delete `doc/tags` and add it to `.gitignore`.
- [ ] **Step 3: Commit** `docs: README and :help`. Open **PR 3**.
