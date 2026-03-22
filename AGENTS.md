# minga-org — Agent & Developer Guide

## Project Overview

minga-org is an extension for the [Minga editor](https://github.com/jsmestad/minga) that adds org-mode support: syntax highlighting, heading folding, TODO cycling, checkbox toggling, list continuation, inline markup, and org-specific keybindings.

The extension compiles and runs standalone for testing but depends on `Minga.*` modules at runtime when loaded into the editor. Compilation warnings about missing `Minga.*` modules are expected.

## Tech Stack

- **Elixir 1.19** / OTP 28
- **ExUnit** for testing
- **tree-sitter-org** vendored grammar (compiled at runtime by Minga's `TreeSitter.register_grammar/3`)
- Pinned versions in `.tool-versions`

## Project Structure

```
lib/
  minga_org.ex                # Root module, extension callbacks (init, name, version)
  minga_org/
    buffer.ex                 # Thin wrapper around Minga.Buffer.Server
    checkbox.ex               # Checkbox toggling ([ ] <-> [x])
    commands.ex               # Command registration with Minga.Command.Registry
    folding.ex                # Heading fold/unfold with TAB/S-TAB cycling
    grammar.ex                # Grammar compilation and filetype registration
    heading.ex                # Heading promote/demote/move
    keybindings.ex            # SPC m keybinding registration
    todo.ex                   # TODO keyword cycling

queries/
  org/
    highlights.scm            # Tree-sitter highlight query for org syntax

vendor/
  tree-sitter-org/
    src/                      # Vendored grammar C sources (parser.c, scanner.c)

test/                         # Mirrors lib/ structure
```

## Epic Tracker

All org-mode work is tracked under [#1 (Epic: Org-mode support)](https://github.com/jsmestad/minga-org/issues/1) with child tickets #2 through #13.

## Git Branching

**`main` is protected.** All changes go through feature branches and pull requests. Never commit directly to main.

- Always create a feature branch before making changes. Use descriptive names: `feat/smart-list-continuation`, `fix/checkbox-toggle-indent`, `chore/ci-setup`.
- Check your current branch before starting work: `git branch --show-current`.
- Push your branch and open a PR when the work is ready. CI must pass before merging.

## Coding Standards

### Elixir Types (mandatory)

Elixir 1.19's set-theoretic type system catches real bugs at compile time. Help it by being explicit:

- **`@spec`** on every public function, no exceptions
- **`@type` / `@typep`** for all custom types in every module
- **`@enforce_keys`** on structs for required fields
- **Guards** in function heads where they aid type inference
- **Pattern matching** over `if/cond`. Use multi-clause functions with pattern matching and guards instead of `cond` blocks
- **No `cond` blocks.** Extract a private helper with multiple `defp` clauses instead. `cond` defeats BEAM JIT optimizations and hides control flow
- **Bulk text operations.** When inserting or replacing multi-character text in a buffer, always use `Buffer.apply_text_edit/6` or `Buffer.apply_text_edits/2`. Never decompose a string into graphemes and loop
- `mix compile` must pass clean (warnings about missing `Minga.*` modules are expected and acceptable)

### Module Aliases (convention, not linted)

Prefer fully qualified module names by default. Aliases add indirection that hurts LLM comprehension: when reading a snippet or diff, the alias block at the top of the file may not be visible, and `Document.insert_text(...)` is ambiguous where `Minga.Buffer.Document.insert_text(...)` is not. Fully qualified names also make grep/search reliable across the codebase.

**Alias when the module path is 4+ segments deep** (e.g., `Minga.Agent.Tools.FileOperations`). At that depth, the fully qualified name eats enough line width to obscure the actual logic. Aliasing to `FileOperations` is a reasonable tradeoff.

**For 2-3 segments** (`Minga.Motion`, `Minga.Buffer.Document`), use the fully qualified name. It's short enough to carry everywhere without readability cost.

**Exception:** if a 3-segment module appears 8+ times in one file and the repetition genuinely hurts human readability, aliasing is fine. But that frequency is also a signal the function may be doing too much or the modules are too tightly coupled.

The `Credo.Check.Design.AliasUsage` lint is disabled. This is a judgment call, not an automated rule.

### Common Elixir Footguns

- **Lists don't support index access.** `mylist[0]` doesn't work. Use `Enum.at(mylist, 0)`, `hd/1`, or pattern matching.
- **Bind the result of block expressions.** Variables can't be rebound inside `if`/`case`/`with` and leak out. Always bind: `state = if condition, do: new_state, else: state`.
- **Never nest multiple modules in one file.** One `defmodule` per `.ex` file.
- **Don't use `String.to_atom/1` on user input.** Atoms are never garbage collected.
- **Predicate functions end in `?`, not `is_`.** Reserve `is_` for guard-compatible functions only.
- **Don't use map access syntax on structs.** `my_struct[:field]` doesn't work. Use `my_struct.field` or pattern match.

### Testing

- Test files mirror `lib/` structure: `lib/minga_org/checkbox.ex` -> `test/minga_org/checkbox_test.exs`
- **Descriptive names**: `"checks an unchecked checkbox"` not `"test toggle/1"`
- **Edge cases always tested**: empty state, boundaries, unicode, nested structures
- **Pure-logic tests preferred.** Since `Minga.*` modules aren't available in the test environment, test the pure logic functions (text parsing, transformation, pattern matching) directly. Functions that call `Buffer.*` are tested via integration tests in the main Minga repo.
- **Every new feature must include tests.** If a module has pure logic that can be tested standalone, it must have tests before merging.

Running tests:

```bash
mix test                              # Full suite
mix test test/minga_org/checkbox_test.exs  # Single file
mix test test/minga_org/checkbox_test.exs:10  # Single test (line number)
mix test --failed                     # Re-run only failures
```

### Commit Messages

```
type(scope): short description

Longer body if needed.
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`
Scopes: `checkbox`, `todo`, `heading`, `folding`, `list`, `markup`, `grammar`, `keybindings`

Examples:
- `feat(list): smart continuation on Enter for unordered lists`
- `fix(checkbox): preserve indentation when toggling nested items`
- `test(todo): add edge cases for custom keyword sequences`
- `chore(ci): add GitHub Actions workflow`

## Build It Right or Don't Build It

Never scope foundational infrastructure to a "V1" that deliberately skips known requirements. If a data structure needs to handle deeply nested org trees, build it with the right algorithm from the start. If a system needs to handle all org list types, don't ship only unordered and plan to "add ordered later."

This applies to internal infrastructure like parsers, text manipulation helpers, and data structures. It does not apply to user-facing features, where shipping a subset (e.g., checkbox toggle before smart continuation) is a legitimate scoping choice.

## Extension Architecture

minga-org follows the Minga extension contract:

1. **`MingaOrg.init/1`** is the entry point. It registers the grammar, keybindings, and commands.
2. **Grammar registration** (`MingaOrg.Grammar`) compiles the vendored tree-sitter-org sources and registers the `.org` filetype.
3. **Command registration** (`MingaOrg.Commands`) registers all org commands with `Minga.Command.Registry`.
4. **Keybinding registration** (`MingaOrg.Keybindings`) binds keys under `SPC m`, scoped to the `:org` filetype.
5. **`MingaOrg.Buffer`** wraps `Minga.Buffer.Server` calls. All buffer interaction goes through this module so if the Minga API changes, only one file needs updating.

When adding a new feature:
1. Create a new module in `lib/minga_org/` with the pure logic
2. Register its command(s) in `MingaOrg.Commands`
3. Add keybinding(s) in `MingaOrg.Keybindings`
4. Write tests for the pure logic in `test/minga_org/`
