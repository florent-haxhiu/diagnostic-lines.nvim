# ADR-0003: Pure layout core, thin rendering shell

**Status:** Accepted
**Date:** 2026-11-25
**Deciders:** Maintainer

## Context

The hard part of this plugin is layout: ordering diagnostics, drawing
connectors, handling tabs and multibyte text, and wrapping. Checking that
by eye in a running editor is slow and misses edge cases. Neovim API
calls (`nvim_buf_set_extmark`, window queries) are what make code hard
to test outside a UI.

## Decision

Split the code into a **functional core** and an **imperative shell**:

- Pure modules (`config`, `wrap`, `layout`) take plain Lua tables and
  numbers and return plain tables. They make no `vim.api` calls.
  `layout` returns rows of `{ text, hl_group }` chunks, exactly the shape
  `virt_lines` wants.
- Shell modules (`handler`, `render`) talk to Neovim: they read windows
  and buffers, call the pure modules and set extmarks.

## Options Considered

### Option A: Functional core / imperative shell

| Dimension | Assessment |
|---|---|
| Complexity | Low to medium (a bit more upfront structure) |
| Testability | High: layout tests are plain input → output |
| Fit with Neovim conventions | High |

**Pros:** Fast, thorough unit tests. Each module has one reason to change
(single responsibility). The renderer can be swapped later, e.g. for
`virt_text`.
**Cons:** Values like screen columns and window width must be worked out
in the shell and passed in, which adds a little plumbing.

### Option B: One module that computes and draws as it goes

| Dimension | Assessment |
|---|---|
| Complexity | Low at first, high later |
| Testability | Low: needs headless Neovim for every test |
| Fit with Neovim conventions | Medium (it's how core's handler is written) |

**Pros:** Less code up front.
**Cons:** Wrapping logic ends up interleaved with API calls. Edge cases
can only be tested end-to-end.

## Trade-off Analysis

Wrapping is the reason this plugin exists, and it's exactly the logic
most likely to have edge-case bugs. Making it pure turns those bugs into
cheap unit tests. The plumbing cost is small.

Analogy: the layout is the architect drawing the floor plan, and the
renderer is the builder. You can check a floor plan on paper without
pouring any concrete.

## Consequences

- Easier: testing `wrap` and `layout` exhaustively, and refactoring
  rendering without touching layout.
- Harder: anything that needs live editor state (display widths of tab
  characters, window widths) has to be computed by the shell and passed
  in. Wide-character width is the one grey area: `vim.fn.strdisplaywidth`
  is a Neovim call, but it's deterministic, so it's allowed in `wrap`.
- Revisit: if the layout input grows unwieldy, introduce a small
  `LayoutInput` type.

## Action Items

1. [ ] Unit tests for `wrap` and `layout` before wiring up `render`.
2. [ ] LuaLS type annotations for the layout input and output shapes.
