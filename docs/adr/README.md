# Architecture Decision Records

Each ADR records one significant decision: the context, the options we
weighed, what we picked and what it costs us. ADRs are never edited to
change a decision. If a decision changes, write a new ADR that
**supersedes** the old one and update the old one's status.

The overall design lives in
[`docs/superpowers/specs/2026-11-25-diagnostic-lines-design.md`](../superpowers/specs/2026-11-25-diagnostic-lines-design.md);
ADRs zoom in on the individual decisions behind it.

## Index

| # | Title | Status |
|---|---|---|
| [0001](0001-custom-diagnostic-handler.md) | Build as a custom `vim.diagnostic` handler | Accepted |
| [0002](0002-configure-through-vim-diagnostic-config.md) | Configure through `vim.diagnostic.config()`, no `setup()` | Proposed |
| [0003](0003-pure-layout-core.md) | Pure layout core, thin rendering shell | Proposed |
| [0004](0004-wrap-to-narrowest-window.md) | Wrap to the narrowest window showing the buffer | Proposed |
| [0005](0005-minimum-neovim-0-11.md) | Require Neovim 0.11+ | Proposed |

## Writing a new ADR

Copy [`template.md`](template.md), give it the next number, and add it
to the index.
