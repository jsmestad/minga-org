# minga-org

Org-mode support for the [Minga](https://github.com/jsmestad/minga) editor.

## Features

- **Syntax highlighting** via tree-sitter (headings, TODO keywords, tags, timestamps, code blocks, comments, properties, checkboxes, tables)
- **TODO cycling** (`SPC m t`): cycles heading keyword through `TODO` -> `DONE` -> (none), with configurable keyword sequences
- **Checkbox toggling** (`SPC m x`): toggles `- [ ]` <-> `- [x]` on the current line
- **Heading promotion/demotion** (`SPC m h` / `SPC m l`): decrease/increase star count
- **Heading reordering** (`SPC m k` / `SPC m j`): move heading and its subtree up/down

## Installation

Add to your Minga config (`~/.config/minga/init.exs`):

```elixir
# From git (latest)
extension :minga_org, git: "https://github.com/jsmestad/minga-org"

# From Hex (pinned version)
extension :minga_org, hex: "minga_org", version: "~> 0.1"
```

Restart Minga or run `:ExtReload` to load the extension.

## Configuration

### Custom TODO keywords

```elixir
extension :minga_org, git: "https://github.com/jsmestad/minga-org",
  todo_keywords: ["TODO", "IN-PROGRESS", "BLOCKED", "DONE"]
```

The keyword sequence cycles in order, then back to no keyword.

## Keybindings

All bindings are under `SPC m` and only active in `.org` files:

| Key | Command | Description |
|-----|---------|-------------|
| `SPC m t` | `:org_cycle_todo` | Cycle TODO keyword |
| `SPC m x` | `:org_toggle_checkbox` | Toggle checkbox |
| `SPC m h` | `:org_promote_heading` | Promote heading (fewer stars) |
| `SPC m l` | `:org_demote_heading` | Demote heading (more stars) |
| `SPC m k` | `:org_move_heading_up` | Move heading/subtree up |
| `SPC m j` | `:org_move_heading_down` | Move heading/subtree down |

## Requirements

- Minga editor with extension support (#211) and runtime grammar loading (#427)
- A C compiler (`cc`, `gcc`, or `clang`) for first-time grammar compilation

The tree-sitter-org grammar is vendored in this repo and compiled into a shared library on first load. The compiled library is cached at `~/.local/share/minga/grammars/org.{dylib,so}`.

## Development

```bash
git clone https://github.com/jsmestad/minga-org.git
cd minga-org
mix deps.get
mix test
```

Tests cover the pure logic (TODO cycling, checkbox toggling, heading promotion/demotion). Integration tests that require a running Minga instance are in the main Minga repo.

## Grammar

This extension vendors [tree-sitter-org](https://github.com/emiasims/tree-sitter-org) (language version 14). The highlight query maps org-mode constructs to standard tree-sitter capture names supported by Minga's theme system.

## License

MIT
