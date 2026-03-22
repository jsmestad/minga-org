defmodule MingaOrgTest do
  use ExUnit.Case, async: true

  describe "__option_schema__/0" do
    test "returns all expected options" do
      schema = MingaOrg.__option_schema__()
      names = Enum.map(schema, &elem(&1, 0))

      assert :conceal in names
      assert :pretty_bullets in names
      assert :heading_bullets in names
      assert :list_bullet in names
      assert :todo_keywords in names
      assert :capture_templates in names
    end

    test "every option is a {name, type, default, description} tuple" do
      for {name, type, _default, description} <- MingaOrg.__option_schema__() do
        assert is_atom(name), "expected atom name, got: #{inspect(name)}"
        assert is_atom(type) or is_tuple(type), "expected type spec for #{name}"
        assert is_binary(description), "expected string description for #{name}"
      end
    end

    test "boolean options have boolean defaults" do
      schema = MingaOrg.__option_schema__()

      for {name, :boolean, default, _desc} <- schema do
        assert is_boolean(default), "#{name} default should be boolean, got: #{inspect(default)}"
      end
    end

    test "string_list options have list defaults" do
      schema = MingaOrg.__option_schema__()

      for {name, :string_list, default, _desc} <- schema do
        assert is_list(default), "#{name} default should be list, got: #{inspect(default)}"
      end
    end

    test "option names are unique" do
      names = Enum.map(MingaOrg.__option_schema__(), &elem(&1, 0))
      assert length(names) == length(Enum.uniq(names))
    end
  end
end
