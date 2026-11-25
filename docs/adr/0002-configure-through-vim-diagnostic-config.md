# ADR-0002: Configure through `vim.diagnostic.config()`, no `setup()`

**Status:** Accepted
**Date:** 2026-11-25
**Deciders:** Maintainer

## Context

Most Neovim plugins expose `require("x").setup(opts)`. But a diagnostic
handler already has a config path: whatever the user passes under the
handler's key in `vim.diagnostic.config()` is resolved by core
(including per-namespace overrides and severity filtering) and handed to
`show()` as `opts`.

## Decision

The handler is registered automatically when the plugin loads; doing so
draws nothing. Users enable and configure it like any core handler:

```lua
vim.diagnostic.config({
  virtual_text = false,
  diagnostic_lines = { wrap = true },
})
```

There is no `setup()`.

## Options Considered

### Option A: `vim.diagnostic.config()` only

| Dimension | Assessment |
|---|---|
| Complexity | Low |
| Testability | High: options arrive as a plain table |
| Fit with Neovim conventions | High: same as core's own handlers |

**Pros:** One way to configure. Per-namespace config and `severity`
filtering come for free. Neovim's plugin guidance discourages a
mandatory `setup()`.
**Cons:** It's less familiar to people used to `setup()`, and there's no
place for global, non-diagnostic options (there aren't any yet).

### Option B: `setup(opts)` that calls `vim.diagnostic.config()` for you

| Dimension | Assessment |
|---|---|
| Complexity | Low |
| Testability | Medium |
| Fit with Neovim conventions | Medium |

**Pros:** It's the familiar shape.
**Cons:** That gives two sources of truth. It's also tempting to change the
user's other diagnostic settings, which is an anti-goal in the design.

### Option C: Both

**Cons:** It has the downsides of B, and the docs have to explain which
one wins.

## Trade-off Analysis

A keeps one source of truth and gets core's option resolution for free.
The only thing B adds is familiarity, and the README example covers that.

## Consequences

- Easier: per-buffer or per-namespace config, toggling with
  `vim.diagnostic.config({ diagnostic_lines = false })`.
- Harder: if we ever need truly global settings (e.g. connector
  characters shared across namespaces), we'll need to revisit.
- Our `config` module still merges defaults and validates, but it
  receives its input from `show()`'s `opts`, not from `setup()`.

## Action Items

1. [ ] `config.resolve(opts)` merges defaults and validates with `vim.validate`.
2. [ ] README shows the `vim.diagnostic.config()` example.
