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

  @doc "Registers all org-mode keybindings."
  @spec register() :: :ok
  def register do
    bind = &Minga.Keymap.Active.bind/5

    # ── SPC m — local leader (org commands) ──────────────────────────────────

    # SPC m t — cycle TODO state
    bind.(:normal, "SPC m t", :org_cycle_todo, "Cycle TODO", filetype: :org)

    # SPC m x — toggle checkbox
    bind.(:normal, "SPC m x", :org_toggle_checkbox, "Toggle checkbox", filetype: :org)

    # ── M-hjkl — structural editing (evil-org convention) ────────────────────

    # M-h — promote heading (fewer stars)
    bind.(:normal, "M-h", :org_promote_heading, "Promote heading", filetype: :org)

    # M-l — demote heading (more stars)
    bind.(:normal, "M-l", :org_demote_heading, "Demote heading", filetype: :org)

    # M-k — move heading/subtree up
    bind.(:normal, "M-k", :org_move_heading_up, "Move heading up", filetype: :org)

    # M-j — move heading/subtree down
    bind.(:normal, "M-j", :org_move_heading_down, "Move heading down", filetype: :org)

    # ── Links ─────────────────────────────────────────────────────────────────

    # RET / gx — follow link at cursor (Doom Emacs org-open-at-point)
    bind.(:normal, "RET", :org_follow_link, "Follow link", filetype: :org)
    bind.(:normal, "g x", :org_follow_link, "Follow link", filetype: :org)

    # ── Export ────────────────────────────────────────────────────────────────

    # SPC m e h — export to HTML
    bind.(:normal, "SPC m e h", :org_export_html, "Export to HTML", filetype: :org)

    # SPC m e m — export to Markdown
    bind.(:normal, "SPC m e m", :org_export_markdown, "Export to Markdown", filetype: :org)

    # SPC m e p — export to PDF
    bind.(:normal, "SPC m e p", :org_export_pdf, "Export to PDF", filetype: :org)

    # ── Folding ──────────────────────────────────────────────────────────────

    # TAB — toggle fold at heading
    bind.(:normal, "TAB", :org_fold_toggle, "Toggle heading fold", filetype: :org)

    # S-TAB — cycle global fold state (overview / show all)
    bind.(:normal, "S-TAB", :org_fold_cycle_global, "Cycle global folds", filetype: :org)

    :ok
  end
end
