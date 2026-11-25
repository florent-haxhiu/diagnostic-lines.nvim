# ADR-0004: Wrap to the narrowest window showing the buffer

**Status:** Accepted
**Date:** 2026-11-25
**Deciders:** Maintainer

## Context

Wrapping needs a width, but extmarks (and their `virt_lines`) belong to
a **buffer**, not a window. If the same buffer is open in two splits of
different widths, both show the same virtual lines. So there's one wrap
width per buffer, and we need a rule for picking it.

The usable width of a window is its width minus the gutter (sign,
number and fold columns): `getwininfo(win)[1].textoff`.

## Decision

Wrap to the **narrowest** window currently displaying the buffer.
Recompute and redraw on `WinResized` and `VimResized`. If the available
width for a message drops under about 10 columns, stop wrapping and let
it overflow.

## Options Considered

### Option A: Narrowest window

| Dimension | Assessment |
|---|---|
| Complexity | Low |
| Testability | High: "min of widths" is easy to test |
| Fit with Neovim conventions | High |

**Pros:** Nothing ever overflows, in any split.
**Cons:** In the wider split, text wraps earlier than it needs to.

### Option B: Current window only

| Dimension | Assessment |
|---|---|
| Complexity | Low |
| Testability | Medium: depends on focus |
| Fit with Neovim conventions | Medium |

**Pros:** It's perfect in the window you're looking at.
**Cons:** It overflows in narrower splits. The layout also changes every
time focus moves between splits, which would need redraws on `WinEnter`
and could flicker.

### Option C: Per-window rendering via a decoration provider

| Dimension | Assessment |
|---|---|
| Complexity | High |
| Testability | Low |
| Fit with Neovim conventions | Uncertain |

**Pros:** It would give a correct width in every window.
**Cons:** It means redrawing in `nvim_set_decoration_provider` callbacks
on every screen update. It's unverified whether ephemeral `virt_lines`
are supported there, and performance risk works against the no-lag
anti-goal.

## Trade-off Analysis

A wraps a little early in the wide window. B overflows or flickers. C
might be perfect, but it's speculative and risky. Early wrapping is the
smallest cost, and it never breaks the "fits the window" promise.

## Consequences

- Easier: a single width per buffer keeps `layout` simple.
- Harder: the handler must track which windows show which buffer.
  `vim.fn.win_findbuf(bufnr)` gives that.
- Revisit: if early wrapping in wide splits is annoying in daily use,
  spike Option C. Status would then move to Superseded.

## Action Items

1. [ ] `handler` computes `min(textwidth)` over `win_findbuf(bufnr)`.
2. [ ] Autocmds on `WinResized` / `VimResized` redraw affected buffers
       from remembered diagnostics.
3. [ ] Test: two splits of different widths wrap to the narrower one.
