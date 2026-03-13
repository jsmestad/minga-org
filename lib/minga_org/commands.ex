defmodule MingaOrg.Commands do
  @moduledoc """
  Registers org-mode commands with the Minga command registry.

  Commands are registered at init time and execute as state -> state
  functions within the editor.
  """

  alias MingaOrg.Checkbox
  alias MingaOrg.Folding
  alias MingaOrg.Heading
  alias MingaOrg.Todo

  @doc "Registers all org-mode commands with the given TODO keyword sequence."
  @spec register([String.t()]) :: :ok
  def register(todo_keywords) do
    registry = Minga.Command.Registry

    registry.register(
      registry,
      :org_cycle_todo,
      "Cycle TODO keyword",
      &Todo.cycle(&1, todo_keywords)
    )

    registry.register(
      registry,
      :org_toggle_checkbox,
      "Toggle checkbox",
      &Checkbox.toggle/1
    )

    registry.register(
      registry,
      :org_promote_heading,
      "Promote heading (decrease level)",
      &Heading.promote/1
    )

    registry.register(
      registry,
      :org_demote_heading,
      "Demote heading (increase level)",
      &Heading.demote/1
    )

    registry.register(
      registry,
      :org_move_heading_up,
      "Move heading/subtree up",
      &Heading.move_up/1
    )

    registry.register(
      registry,
      :org_move_heading_down,
      "Move heading/subtree down",
      &Heading.move_down/1
    )

    registry.register(
      registry,
      :org_fold_toggle,
      "Toggle fold at heading",
      &Folding.toggle_at_cursor/1
    )

    registry.register(
      registry,
      :org_fold_cycle_global,
      "Cycle global fold state",
      &Folding.cycle_global/1
    )

    :ok
  end
end
