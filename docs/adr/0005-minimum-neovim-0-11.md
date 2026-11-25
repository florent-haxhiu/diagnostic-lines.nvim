# ADR-0005: Require Neovim 0.11+

**Status:** Proposed
**Date:** 2026-11-25
**Deciders:** Maintainer

## Context

The plugin is built for personal use first, on a current
Neovim. 0.11 is the release where core's diagnostics gained
`virtual_lines`, and with it the `DiagnosticVirtualLines*` highlight
groups we link to. Supporting older versions means fallbacks and a wider
CI matrix.

## Decision

Support Neovim **0.11 and newer**. Run CI against stable and nightly.

## Options Considered

### Option A: 0.11+

**Pros:** We can rely on `DiagnosticVirtualLines*` highlight groups and
current extmark options (`virt_lines_overflow`, `virt_lines_leftcol`).
CI stays small.
**Cons:** It excludes people stuck on older distro packages.

### Option B: 0.10+

**Pros:** It reaches a few more users.
**Cons:** We'd have to define our own highlight fallbacks and test
another version, for users this plugin isn't aimed at.

## Trade-off Analysis

Reach doesn't matter much for a personal-first plugin, and keeping CI
and code simple does. 0.11 also gives us core's `virtual_lines` to
compare against while building.

## Consequences

- Easier: a simpler code path and highlight groups that already exist.
- Harder: nothing meaningful for the target user.
- Revisit: bump the minimum when a newer release adds something we want.

## Action Items

1. [ ] Check `vim.fn.has("nvim-0.11")` in `plugin/` and warn once if
       unsupported.
2. [ ] CI matrix: stable + nightly.
