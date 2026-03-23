defmodule MingaOrg.KeybindingsTest do
  use ExUnit.Case, async: true

  describe "__keybind_schema__/0" do
    test "filetype-scoped bindings have filetype: :org" do
      for {_mode, _key, cmd, _desc, opts} <- MingaOrg.__keybind_schema__(),
          opts != [] do
        assert Keyword.get(opts, :filetype) == :org,
               "#{cmd} should be scoped to filetype: :org"
      end
    end

    test "global bindings have empty opts" do
      global =
        MingaOrg.__keybind_schema__()
        |> Enum.filter(fn {_mode, _key, _cmd, _desc, opts} -> opts == [] end)

      assert length(global) == 1
      [{_mode, _key, cmd, _desc, _opts}] = global
      assert cmd == :org_capture
    end

    test "every binding has {mode, key_string, command, description, opts} shape" do
      for {mode, key, command, description, opts} <- MingaOrg.__keybind_schema__() do
        assert is_atom(mode), "expected atom mode, got: #{inspect(mode)}"
        assert is_binary(key), "expected string key for #{command}"
        assert is_atom(command), "expected atom command, got: #{inspect(command)}"
        assert is_binary(description), "expected string description for #{command}"
        assert is_list(opts), "expected keyword opts for #{command}"
      end
    end

    test "every keybinding command maps to a declared command" do
      command_names =
        MingaOrg.__command_schema__()
        |> Enum.map(&elem(&1, 0))
        |> MapSet.new()

      for {_mode, _key, command, _desc, _opts} <- MingaOrg.__keybind_schema__() do
        assert MapSet.member?(command_names, command),
               "keybinding references #{command} which is not in __command_schema__"
      end
    end

    test "key strings are unique per mode" do
      grouped =
        MingaOrg.__keybind_schema__()
        |> Enum.group_by(fn {mode, key, _cmd, _desc, _opts} -> {mode, key} end)

      for {{mode, key}, bindings} <- grouped do
        assert length(bindings) == 1,
               "duplicate binding for #{mode} #{key}: #{inspect(bindings)}"
      end
    end
  end
end
