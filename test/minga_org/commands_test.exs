defmodule MingaOrg.CommandsTest do
  use ExUnit.Case, async: true

  describe "__command_schema__/0" do
    test "returns all expected command names" do
      names = MingaOrg.__command_schema__() |> Enum.map(&elem(&1, 0))

      assert :org_capture in names
      assert :org_cycle_todo in names
      assert :org_toggle_checkbox in names
      assert :org_promote_heading in names
      assert :org_demote_heading in names
      assert :org_move_heading_up in names
      assert :org_move_heading_down in names
      assert :org_fold_toggle in names
      assert :org_fold_cycle_global in names
      assert :org_follow_link in names
      assert :org_jump_to_tag in names
      assert :org_table_tab in names
      assert :org_table_shift_tab in names
      assert :org_export in names
    end

    test "every definition has {name, description, opts} shape with execute MFA" do
      for {name, description, opts} <- MingaOrg.__command_schema__() do
        assert is_atom(name), "expected atom name, got: #{inspect(name)}"
        assert is_binary(description), "expected string description for #{name}"
        {mod, fun} = Keyword.fetch!(opts, :execute)
        assert is_atom(mod), "expected atom module in execute for #{name}"
        assert is_atom(fun), "expected atom function in execute for #{name}"
      end
    end

    test "all command names are prefixed with :org_" do
      for {name, _desc, _opts} <- MingaOrg.__command_schema__() do
        assert name |> Atom.to_string() |> String.starts_with?("org_"),
               "#{name} should start with org_"
      end
    end

    test "command names are unique" do
      names = MingaOrg.__command_schema__() |> Enum.map(&elem(&1, 0))
      assert length(names) == length(Enum.uniq(names))
    end
  end
end
