defmodule MingaOrg do
  @moduledoc """
  Org-mode support for the Minga editor.

  Provides syntax highlighting, heading folding, TODO cycling, checkbox
  toggling, and org-specific keybindings. Install via your Minga config:

      extension :minga_org, git: "https://github.com/jsmestad/minga-org",
        conceal: true,
        pretty_bullets: true,
        heading_bullets: ["◉", "○", "◈", "◇"],
        todo_keywords: ["TODO", "DONE"]

  All keybindings are scoped to `SPC m` and only active when editing
  `.org` files.
  """

  use Minga.Extension

  # ── Options ──────────────────────────────────────────────────────────────────

  option :conceal, :boolean,
    default: true,
    description: "Hide markup delimiters and show styled content"

  option :pretty_bullets, :boolean,
    default: true,
    description: "Replace heading stars with Unicode bullets"

  option :heading_bullets, :string_list,
    default: ["◉", "○", "◈", "◇"],
    description: "Unicode bullets for heading levels (cycles when depth exceeds list length)"

  option :list_bullet, :string,
    default: "•",
    description: "Replacement character for list item bullets"

  option :todo_keywords, :string_list,
    default: ["TODO", "DONE"],
    description: "TODO keyword cycle sequence"

  option :tag_colors, :any,
    default: nil,
    description: "Map of tag name to hex color for pill annotations (nil uses auto-palette)"

  option :capture_templates, :any,
    default: nil,
    description: "Capture template definitions (nil uses built-in defaults)"

  # ── Commands ─────────────────────────────────────────────────────────────────

  command(:org_capture, "Quick capture", execute: {MingaOrg.CapturePicker, :open})

  command(:org_cycle_todo, "Cycle TODO keyword",
    execute: {MingaOrg.Todo, :cycle},
    requires_buffer: true
  )

  command(:org_toggle_checkbox, "Toggle checkbox",
    execute: {MingaOrg.Checkbox, :toggle},
    requires_buffer: true
  )

  command(:org_promote_heading, "Promote heading (decrease level)",
    execute: {MingaOrg.Heading, :promote},
    requires_buffer: true
  )

  command(:org_demote_heading, "Demote heading (increase level)",
    execute: {MingaOrg.Heading, :demote},
    requires_buffer: true
  )

  command(:org_move_heading_up, "Move heading/subtree up",
    execute: {MingaOrg.Heading, :move_up},
    requires_buffer: true
  )

  command(:org_move_heading_down, "Move heading/subtree down",
    execute: {MingaOrg.Heading, :move_down},
    requires_buffer: true
  )

  command(:org_fold_toggle, "Toggle fold at heading",
    execute: {MingaOrg.Folding, :toggle_at_cursor},
    requires_buffer: true
  )

  command(:org_fold_cycle_global, "Cycle global fold state",
    execute: {MingaOrg.Folding, :cycle_global},
    requires_buffer: true
  )

  command(:org_follow_link, "Follow link at cursor",
    execute: {MingaOrg.LinkFollow, :follow},
    requires_buffer: true
  )

  command(:org_jump_to_tag, "Jump to tag",
    execute: {MingaOrg.TagPicker, :open},
    requires_buffer: true
  )

  command(:org_table_tab, "Table: next cell",
    execute: {MingaOrg.TableCommands, :tab},
    requires_buffer: true
  )

  command(:org_table_shift_tab, "Table: previous cell",
    execute: {MingaOrg.TableCommands, :shift_tab},
    requires_buffer: true
  )

  command(:org_export, "Export org file",
    execute: {MingaOrg.ExportPicker, :open},
    requires_buffer: true
  )

  # ── Keybindings ──────────────────────────────────────────────────────────────

  # SPC X — quick capture (global, not filetype-scoped)
  keybind(:normal, "SPC X", :org_capture, "Quick capture")

  # SPC m — local leader (org commands)
  keybind(:normal, "SPC m t", :org_cycle_todo, "Cycle TODO", filetype: :org)
  keybind(:normal, "SPC m x", :org_toggle_checkbox, "Toggle checkbox", filetype: :org)

  # M-hjkl — structural editing (evil-org convention)
  keybind(:normal, "M-h", :org_promote_heading, "Promote heading", filetype: :org)
  keybind(:normal, "M-l", :org_demote_heading, "Demote heading", filetype: :org)
  keybind(:normal, "M-k", :org_move_heading_up, "Move heading up", filetype: :org)
  keybind(:normal, "M-j", :org_move_heading_down, "Move heading down", filetype: :org)

  # Links
  keybind(:normal, "RET", :org_follow_link, "Follow link", filetype: :org)
  keybind(:normal, "g x", :org_follow_link, "Follow link", filetype: :org)

  # Tags
  keybind(:normal, "SPC m T", :org_jump_to_tag, "Jump to tag", filetype: :org)

  # Export
  keybind(:normal, "SPC m e", :org_export, "Export org file", filetype: :org)

  # Folding
  keybind(:normal, "TAB", :org_fold_toggle, "Toggle heading fold", filetype: :org)
  keybind(:normal, "S-TAB", :org_fold_cycle_global, "Cycle global folds", filetype: :org)

  # Table navigation (insert mode)
  keybind(:insert, "TAB", :org_table_tab, "Table: next cell", filetype: :org)
  keybind(:insert, "S-TAB", :org_table_shift_tab, "Table: previous cell", filetype: :org)

  # ── Callbacks ────────────────────────────────────────────────────────────────

  @impl true
  @spec name() :: :minga_org
  def name, do: :minga_org

  @impl true
  @spec description() :: String.t()
  def description, do: "Org-mode support: syntax highlighting, headings, TODOs, checkboxes"

  @impl true
  @spec version() :: String.t()
  def version, do: "0.1.0"

  @impl true
  @spec init(keyword()) :: {:ok, map()} | {:error, term()}
  def init(_config) do
    MingaOrg.Grammar.register()
    MingaOrg.Advice.register()

    {:ok, %{}}
  end
end
