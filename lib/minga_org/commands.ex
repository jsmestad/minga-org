defmodule MingaOrg.Commands do
  @moduledoc """
  Registers org-mode commands with the Minga command registry.

  Commands are registered at init time and execute as state -> state
  functions within the editor.
  """

  alias MingaOrg.Checkbox
  alias MingaOrg.Folding
  alias MingaOrg.Heading
  alias MingaOrg.LinkFollow
  alias MingaOrg.TableCommands
  alias MingaOrg.Todo

  @typedoc "A command definition: {name, description, function}."
  @type command_def :: {atom(), String.t(), (map() -> map())}

  @doc """
  Returns the list of org-mode command definitions.

  Each tuple is `{name, description, function}`. The `todo_keywords`
  list is closed over by the TODO cycling command.
  """
  @spec command_definitions([String.t()]) :: [command_def()]
  def command_definitions(todo_keywords) do
    [
      {:org_capture, "Quick capture",
       fn state -> Minga.Editor.PickerUI.open(state, MingaOrg.CapturePicker) end},
      {:org_cycle_todo, "Cycle TODO keyword", &Todo.cycle(&1, todo_keywords)},
      {:org_toggle_checkbox, "Toggle checkbox", &Checkbox.toggle/1},
      {:org_promote_heading, "Promote heading (decrease level)", &Heading.promote/1},
      {:org_demote_heading, "Demote heading (increase level)", &Heading.demote/1},
      {:org_move_heading_up, "Move heading/subtree up", &Heading.move_up/1},
      {:org_move_heading_down, "Move heading/subtree down", &Heading.move_down/1},
      {:org_fold_toggle, "Toggle fold at heading", &Folding.toggle_at_cursor/1},
      {:org_fold_cycle_global, "Cycle global fold state", &Folding.cycle_global/1},
      {:org_follow_link, "Follow link at cursor", &LinkFollow.follow/1},
      {:org_jump_to_tag, "Jump to tag",
       fn state -> Minga.Editor.PickerUI.open(state, MingaOrg.TagPicker) end},
      {:org_table_tab, "Table: next cell", &TableCommands.tab/1},
      {:org_table_shift_tab, "Table: previous cell", &TableCommands.shift_tab/1},
      {:org_export, "Export org file",
       fn state -> Minga.Editor.PickerUI.open(state, MingaOrg.ExportPicker) end}
    ]
  end

  @doc "Registers all org-mode commands with the given TODO keyword sequence."
  @spec register([String.t()]) :: :ok
  def register(todo_keywords) do
    registry = Minga.Command.Registry

    for {name, description, fun} <- command_definitions(todo_keywords) do
      registry.register(registry, name, description, fun)
    end

    :ok
  end
end
