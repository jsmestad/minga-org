defmodule MingaOrg.KeybindingsTest do
  use ExUnit.Case, async: true

  alias MingaOrg.Commands
  alias MingaOrg.Keybindings

  describe "binding_definitions/0" do
    test "filetype-scoped bindings have filetype: :org" do
      for {_mode, _key, cmd, _desc, opts} <- Keybindings.binding_definitions(),
          opts != [] do
        assert Keyword.get(opts, :filetype) == :org,
               "#{cmd} should be scoped to filetype: :org"
      end
    end

    test "global bindings have empty opts" do
      global =
        Keybindings.binding_definitions()
        |> Enum.filter(fn {_mode, _key, _cmd, _desc, opts} -> opts == [] end)

      assert length(global) == 1
      [{_mode, _key, cmd, _desc, _opts}] = global
      assert cmd == :org_capture
    end

    test "every binding is a {atom, string, atom, string, keyword} tuple" do
      for {mode, key, command, description, opts} <- Keybindings.binding_definitions() do
        assert is_atom(mode), "expected atom mode, got: #{inspect(mode)}"
        assert is_binary(key), "expected string key for #{command}"
        assert is_atom(command), "expected atom command, got: #{inspect(command)}"
        assert is_binary(description), "expected string description for #{command}"
        assert is_list(opts), "expected keyword opts for #{command}"
      end
    end

    test "every keybinding command maps to a registered command" do
      command_names =
        Commands.command_definitions(["TODO", "DONE"])
        |> Enum.map(&elem(&1, 0))
        |> MapSet.new()

      for {_mode, _key, command, _desc, _opts} <- Keybindings.binding_definitions() do
        assert MapSet.member?(command_names, command),
               "keybinding references #{command} which is not in command_definitions"
      end
    end

    test "key strings are unique per mode" do
      grouped =
        Keybindings.binding_definitions()
        |> Enum.group_by(fn {mode, key, _cmd, _desc, _opts} -> {mode, key} end)

      for {{mode, key}, bindings} <- grouped do
        assert length(bindings) == 1,
               "duplicate binding for #{mode} #{key}: #{inspect(bindings)}"
      end
    end
  end
end
