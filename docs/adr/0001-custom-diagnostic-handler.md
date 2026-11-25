# ADR-0001: Build as a custom `vim.diagnostic` handler

**Status:** Accepted
**Date:** 2026-11-25
**Deciders:** Maintainer

## Context

The goal is to show every diagnostic as virtual lines under the line
that caused it. Neovim 0.11 already ships a `virtual_lines` handler that
does this, so the plugin needs a reason to exist: core's handler lets
long messages run off the edge of the window, and that can't be
configured. Wrapping them is the feature core lacks.

`vim.diagnostic.handlers` is a public extension point: any table with
`show(namespace, bufnr, diagnostics, opts)` and `hide(namespace, bufnr)`
registered there becomes a display that core drives.

## Decision

Write our own handler from scratch, registered as
`vim.diagnostic.handlers.diagnostic_lines`, then add wrapping on top.

## Options Considered

### Option A: Own handler, rebuilt from scratch, then add wrapping

| Dimension | Assessment |
|---|---|
| Complexity | Medium |
| Control over layout | Full |
| Testability | High, if layout is kept pure (see ADR-0003) |
| Fit with Neovim conventions | High: uses the official extension point |

**Pros:** We own the layout code, so wrapping is possible. The structure
is ours to design. No dependency on core internals.
**Cons:** It re-does work core has already done. Bugs core has fixed may
need fixing again.

### Option B: Thin wrapper around core's `virtual_lines`

| Dimension | Assessment |
|---|---|
| Complexity | Low |
| Control over layout | None |
| Testability | Low (little logic of our own) |
| Fit with Neovim conventions | High |

**Pros:** Quick. Behaviour matches core exactly.
**Cons:** It can't add wrapping, because core's layout can't be changed
from outside.

### Option C: Copy core's handler source and modify it

| Dimension | Assessment |
|---|---|
| Complexity | Medium |
| Control over layout | Full |
| Testability | Low: core's code isn't structured for unit tests |
| Fit with Neovim conventions | Medium |

**Pros:** It starts from working code.
**Cons:** It inherits core's structure, where layout and rendering are
tangled. Upstream changes would need to be merged in by hand.

## Trade-off Analysis

B can't deliver wrapping, so it's out. A and C both own the layout code,
but C inherits core's structure, which works against testability
(ADR-0003). A costs more effort up front but ends with code designed
around the feature that justifies the plugin.

The handler interface is the Strategy pattern: core is the context, and
`virtual_text`, `virtual_lines` and ours are interchangeable strategies.
Core never changes to accept ours, which is open/closed in action.

## Consequences

- Easier: adding features core lacks (wrapping first).
- Harder: matching core's polish. Edge cases like tabs, multibyte text
  and end-of-line columns are ours to handle.
- Revisit: if core ever adds wrapping, decide whether this plugin is
  still worth keeping.

## Action Items

1. [ ] Register the handler in `plugin/diagnostic-lines.lua`.
2. [ ] Implement `show` / `hide` in `lua/diagnostic-lines/handler.lua`.
