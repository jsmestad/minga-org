defmodule MingaOrg.CommandsTest do
  use ExUnit.Case, async: true

  alias MingaOrg.Commands

  @default_keywords ["TODO", "DONE"]

  describe "command_definitions/1" do
    test "returns all expected command names" do
      defs = Commands.command_definitions(@default_keywords)
      names = Enum.map(defs, &elem(&1, 0))

      assert :org_cycle_todo in names
      assert :org_toggle_checkbox in names
      assert :org_promote_heading in names
      assert :org_demote_heading in names
      assert :org_move_heading_up in names
      assert :org_move_heading_down in names
      assert :org_fold_toggle in names
      assert :org_fold_cycle_global in names
      assert :org_follow_link in names
      assert :org_table_tab in names
      assert :org_table_shift_tab in names
      assert :org_export in names
    end

    test "every definition is a {atom, string, function} tuple" do
      for {name, description, fun} <- Commands.command_definitions(@default_keywords) do
        assert is_atom(name), "expected atom name, got: #{inspect(name)}"
        assert is_binary(description), "expected string description for #{name}"
        assert is_function(fun, 1), "expected arity-1 function for #{name}"
      end
    end

    test "all command names are prefixed with :org_" do
      for {name, _desc, _fun} <- Commands.command_definitions(@default_keywords) do
        assert name |> Atom.to_string() |> String.starts_with?("org_"),
               "#{name} should start with org_"
      end
    end

    test "command names are unique" do
      names = Enum.map(Commands.command_definitions(@default_keywords), &elem(&1, 0))
      assert length(names) == length(Enum.uniq(names))
    end
  end
end
