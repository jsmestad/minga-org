defmodule MingaOrg.Keybindings do
  @moduledoc """
  Registers org-mode keybindings for the `:org` filetype.

  Follows Doom Emacs `evil-org` / `evil-collection` conventions:
  - `SPC m` prefix for org-specific commands (local leader)
  - `M-hjkl` (Alt+hjkl) for structural editing (promote/demote/move)
  - `TAB` / `S-TAB` for folding

  All bindings are scoped to `.org` files via the `filetype:` option
  and only appear in which-key when an org buffer is focused.
  """

  @typedoc "A keybinding definition: {mode, key_string, command, description, opts}."
  @type binding_def :: {atom(), String.t(), atom(), String.t(), keyword()}

  @doc """
  Returns the list of org-mode keybinding definitions.

  Each tuple is `{mode, key_string, command, description, opts}`.
  """
  @spec binding_definitions() :: [binding_def()]
  def binding_definitions do
    [
      # SPC m — local leader (org commands)
      {:normal, "SPC m t", :org_cycle_todo, "Cycle TODO", filetype: :org},
      {:normal, "SPC m x", :org_toggle_checkbox, "Toggle checkbox", filetype: :org},

      # M-hjkl — structural editing (evil-org convention)
      {:normal, "M-h", :org_promote_heading, "Promote heading", filetype: :org},
      {:normal, "M-l", :org_demote_heading, "Demote heading", filetype: :org},
      {:normal, "M-k", :org_move_heading_up, "Move heading up", filetype: :org},
      {:normal, "M-j", :org_move_heading_down, "Move heading down", filetype: :org},

      # Links
      {:normal, "RET", :org_follow_link, "Follow link", filetype: :org},
      {:normal, "g x", :org_follow_link, "Follow link", filetype: :org},

      # Export
      {:normal, "SPC m e h", :org_export_html, "Export to HTML", filetype: :org},
      {:normal, "SPC m e m", :org_export_markdown, "Export to Markdown", filetype: :org},
      {:normal, "SPC m e p", :org_export_pdf, "Export to PDF", filetype: :org},

      # Folding
      {:normal, "TAB", :org_fold_toggle, "Toggle heading fold", filetype: :org},
      {:normal, "S-TAB", :org_fold_cycle_global, "Cycle global folds", filetype: :org}
    ]
  end

  @doc "Registers all org-mode keybindings."
  @spec register() :: :ok
  def register do
    bind = &Minga.Keymap.Active.bind/5

    for {mode, key, command, description, opts} <- binding_definitions() do
      bind.(mode, key, command, description, opts)
    end

    :ok
  end
end
