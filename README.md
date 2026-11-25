# diagnostic-lines.nvim

Show every LSP diagnostic as **virtual lines underneath the line that
caused it**, with connectors pointing at the exact column, and **long
messages wrapped to fit the window**.

```
local x = foo(bar, baz)
          │   └──── W: unused local 'bar'
          └──────── E: undefined global 'foo'
```

Neovim 0.11 ships a similar `virtual_lines` handler. The difference is
wrapping: core lets long messages run off the edge of the window, while
this plugin wraps them, keeping the connectors running down the side.

```
local x = foo(bar, baz)
          │   └──── W: this is a very long message that would
          │            otherwise run off the edge of the window
          └──────── E: undefined global 'foo'
```

## Requirements

- Neovim **0.11+**

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "florent-haxhiu/diagnostic-lines.nvim",
  lazy = false,
  config = function()
    vim.diagnostic.config({
      virtual_text = false,
      diagnostic_lines = true,
    })
  end,
}
```

Without a plugin manager:

```sh
git clone https://github.com/florent-haxhiu/diagnostic-lines.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/diagnostic-lines.nvim
```

## Configuration

There's no `setup()`. The plugin registers a diagnostic handler called
`diagnostic_lines`, and you turn it on and configure it the same way as
core's `virtual_text` or `virtual_lines`:

```lua
vim.diagnostic.config({
  virtual_text = false,     -- your choice; this plugin never changes it
  diagnostic_lines = {
    wrap = true,
  },
})
```

Because it's a normal handler, per-namespace config and `severity`
filtering work as they do for core handlers.

| Option | Default | Meaning |
|---|---|---|
| `wrap` | `true` | Wrap long messages to fit the window. |
| `format` | `nil` | `function(diagnostic): string?` that replaces the message text. Return `nil` to hide that diagnostic, as with core's `format`. |

Toggle it off and on:

```lua
vim.diagnostic.config({ diagnostic_lines = false })
vim.diagnostic.config({ diagnostic_lines = true })
```

**Pick one display.** If you also enable core's `virtual_lines` (or
`virtual_text`), you'll see both. Turn off the ones you don't want.

## Highlights

The plugin uses core's own groups, so colourschemes work out of the box:

| Severity | Group |
|---|---|
| Error | `DiagnosticVirtualLinesError` |
| Warning | `DiagnosticVirtualLinesWarn` |
| Info | `DiagnosticVirtualLinesInfo` |
| Hint | `DiagnosticVirtualLinesHint` |

## How it behaves

- **Several diagnostics on one line:** the rightmost is drawn first, and
  connectors run down for the rest. Diagnostics at the same column stack,
  most severe first.
- **Multi-line messages** (common with rust-analyzer and TypeScript):
  each line gets its own row.
- **Splits:** virtual lines belong to the buffer, not the window, so the
  same file open in two splits shares one layout. Messages wrap to the
  **narrowest** split, so they fit in all of them; the wider split wraps a
  little early. Resizing rewraps.
- **Very narrow windows:** if there's less than 10 columns left for the
  message, wrapping turns off rather than drawing a few characters per row.
- **`nowrap` and horizontal scrolling:** the virtual lines scroll with the
  text, so connectors stay under the right characters.

## Development

```sh
make test                              # whole suite, headless
make test FILE=tests/test_layout.lua   # one file
```

Tests use [mini.test](https://github.com/echasnovski/mini.test), which
`make` clones into `deps/`. Design notes live in `docs/`: the design spec
and one ADR per key decision in `docs/adr/`.

## License

Apache 2.0, see [LICENSE](LICENSE).
