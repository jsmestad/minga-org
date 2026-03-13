defmodule MingaOrg.Keybindings do
  @moduledoc """
  Registers org-mode keybindings under `SPC m` for the `:org` filetype.

  All bindings are scoped to `.org` files via the `filetype:` option
  and only appear in which-key when an org buffer is focused.
  """

  @doc "Registers all org-mode keybindings."
  @spec register() :: :ok
  def register do
    bind = &Minga.Keymap.Active.bind/5

    # SPC m t — cycle TODO state
    bind.(:normal, "SPC m t", :org_cycle_todo, "Cycle TODO", filetype: :org)

    # SPC m x — toggle checkbox
    bind.(:normal, "SPC m x", :org_toggle_checkbox, "Toggle checkbox", filetype: :org)

    # SPC m h — promote heading (fewer stars)
    bind.(:normal, "SPC m h", :org_promote_heading, "Promote heading", filetype: :org)

    # SPC m l — demote heading (more stars)
    bind.(:normal, "SPC m l", :org_demote_heading, "Demote heading", filetype: :org)

    # SPC m k — move heading up
    bind.(:normal, "SPC m k", :org_move_heading_up, "Move heading up", filetype: :org)

    # SPC m j — move heading down
    bind.(:normal, "SPC m j", :org_move_heading_down, "Move heading down", filetype: :org)

    :ok
  end
end
