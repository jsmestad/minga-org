# minga-org

**Org-mode for the [Minga](https://github.com/jsmestad/minga) editor.**

[API Docs](https://jsmestad.github.io/minga-org/) | [Minga Extension API](https://jsmestad.github.io/minga/extension-api.html) | [Issue Tracker](https://github.com/jsmestad/minga-org/issues)

minga-org brings the core org-mode workflow to Minga: headings, folding, TODO states, checkboxes, lists, links, tables, code blocks, capture, export, and pretty rendering. If you use Doom Emacs for org-mode, the keybindings will feel familiar.

## Quick start

Add to your Minga config (`~/.config/minga/config.exs`):

```elixir
extension :minga_org, git: "https://github.com/jsmestad/minga-org"
```

Press `SPC h r` to reload. Open any `.org` file. That's it.

## What you get

### Editing

Press `SPC m` in an org file to see all available commands. The which-key popup shows everything; you don't need to memorize the table below.

| Key | What it does |
|-----|-------------|
| `SPC m t` | Cycle TODO keyword (TODO → DONE → none) |
| `SPC m x` | Toggle checkbox (`[ ]` ↔ `[x]`) |
| `M-h` / `M-l` | Promote / demote heading |
| `M-k` / `M-j` | Move heading + subtree up / down |
| `TAB` / `S-TAB` | Fold heading / cycle all folds |
| `RET` or `g x` | Follow link at cursor |
| `SPC m T` | Jump to heading by tag |
| `SPC m e` | Export via pandoc (HTML, PDF, Markdown, etc.) |
| `SPC X` | Quick capture (works from any file) |

In insert mode, `TAB` inside a table re-aligns columns and jumps to the next cell. `S-TAB` goes backward.

### Rendering

Org markup renders inline as you'd expect. `*bold*` shows **bold**, `/italic/` shows *italic*, `~code~` shows `code`. The delimiters hide on non-cursor lines so the text reads cleanly, then reappear when you move your cursor to that line for editing.

Heading stars (`*`, `**`, `***`) are replaced with Unicode bullets (◉, ○, ◈, ◇) via the conceal system. List bullets get the same treatment.

Links show their description text with the URL hidden: `[[https://example.com][Example]]` displays as underlined "Example".

### Smart lists

Hit Enter on a list item and the next line continues the list automatically. Unordered bullets reuse the same marker. Ordered lists increment the number. If you hit Enter on an empty bullet (just the marker, no text), the list ends and the bullet is removed.

### Capture

`SPC X` from anywhere in the editor. A picker shows your capture templates (TODO, Note, Journal by default). Select one, type a title, and the entry lands in the right file under the right heading. Configure your own templates:

```elixir
extension :minga_org, git: "https://github.com/jsmestad/minga-org",
  capture_templates: [
    %{key: "t", name: "TODO", target: "~/org/inbox.org", template: "* TODO %{title}"},
    %{key: "m", name: "Meeting", target: "~/org/work.org", heading: "Meetings",
      template: "* %{date} %{title}\n%{body}"}
  ]
```

## Configuration

All options go in your extension declaration. Defaults are shown:

```elixir
extension :minga_org, git: "https://github.com/jsmestad/minga-org",
  conceal: true,                           # hide markup delimiters
  pretty_bullets: true,                    # replace stars with Unicode bullets
  heading_bullets: ["◉", "○", "◈", "◇"],  # bullets per heading depth
  list_bullet: "•",                        # replacement for list markers
  todo_keywords: ["TODO", "DONE"]          # keyword cycle sequence
```

Set `conceal: false` to always show raw delimiters. Set `pretty_bullets: false` to keep plain `*` stars.

## Requirements

- **Minga** with extension support and runtime grammar loading
- **A C compiler** (`cc`, `gcc`, or `clang`) for first-time grammar compilation

The tree-sitter-org grammar is vendored in this repo. Minga compiles it into a shared library on first load and caches it at `~/.local/share/minga/grammars/`. Subsequent starts skip compilation.

## Development

```bash
git clone https://github.com/jsmestad/minga-org.git
cd minga-org
mix deps.get
mix test
```

The extension compiles standalone for testing. `Minga.*` modules are available as a dev/test dependency for type checking and behaviour validation, but Minga's app doesn't start during tests.

```bash
mix lint          # format + credo + compile + dialyzer
mix test          # 310+ tests including property-based tests
mix dialyzer      # full type checking across the Minga boundary
```

### Architecture

All org-mode features follow the same pattern: a pure-logic module (text parsing, transformation) paired with a thin editor integration layer (buffer reads/writes, command registration). The pure logic is tested extensively. The buffer integration uses an in-memory stub (`MingaOrg.Buffer.Stub`) that actually applies text edits, so integration tests verify real read-after-write sequences.

For details, see the [API docs](https://jsmestad.github.io/minga-org/).

## License

MIT
