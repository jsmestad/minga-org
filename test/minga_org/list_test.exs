defmodule MingaOrg.ListTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MingaOrg.Generators
  alias MingaOrg.List

  describe "parse_line/1" do
    test "parses unordered list with dash" do
      assert {:list_item, %{indent: "", bullet: "-", style: :unordered, content: "Buy milk"}} =
               List.parse_line("- Buy milk")
    end

    test "parses unordered list with plus" do
      assert {:list_item, %{indent: "", bullet: "+", style: :unordered, content: "Item"}} =
               List.parse_line("+ Item")
    end

    test "rejects star at column 0 as heading, not list item" do
      assert :not_a_list_item = List.parse_line("* Item")
    end

    test "parses indented star as list item" do
      assert {:list_item, %{indent: "  ", bullet: "*", style: :unordered, content: "Item"}} =
               List.parse_line("  * Item")
    end

    test "parses ordered list with dot" do
      assert {:list_item, %{indent: "", bullet: "1.", style: :ordered_dot, content: "First"}} =
               List.parse_line("1. First")
    end

    test "parses ordered list with paren" do
      assert {:list_item, %{indent: "", bullet: "1)", style: :ordered_paren, content: "First"}} =
               List.parse_line("1) First")
    end

    test "parses multi-digit ordered number" do
      assert {:list_item, %{indent: "", bullet: "42.", style: :ordered_dot, content: "Item"}} =
               List.parse_line("42. Item")
    end

    test "preserves leading indentation" do
      assert {:list_item, %{indent: "  ", bullet: "-", style: :unordered, content: "Nested"}} =
               List.parse_line("  - Nested")
    end

    test "preserves deep indentation" do
      assert {:list_item, %{indent: "      ", bullet: "+", style: :unordered, content: "Deep"}} =
               List.parse_line("      + Deep")
    end

    test "parses tab indentation" do
      assert {:list_item, %{indent: "\t", bullet: "-", style: :unordered, content: "Tabbed"}} =
               List.parse_line("\t- Tabbed")
    end

    test "parses empty content (just bullet)" do
      assert {:list_item, %{indent: "", bullet: "-", style: :unordered, content: ""}} =
               List.parse_line("- ")
    end

    test "returns not_a_list_item for plain text" do
      assert :not_a_list_item = List.parse_line("Just some text")
    end

    test "returns not_a_list_item for multi-star headings" do
      assert :not_a_list_item = List.parse_line("** A heading")
    end

    test "returns not_a_list_item for single-star headings" do
      assert :not_a_list_item = List.parse_line("* A heading")
    end

    test "returns not_a_list_item for empty lines" do
      assert :not_a_list_item = List.parse_line("")
    end

    test "returns not_a_list_item for bullet without space" do
      assert :not_a_list_item = List.parse_line("-no space")
    end

    test "parses list item with checkbox content" do
      assert {:list_item, %{indent: "", bullet: "-", style: :unordered, content: "[ ] Task"}} =
               List.parse_line("- [ ] Task")
    end

    test "parses content with unicode" do
      assert {:list_item, %{indent: "", bullet: "-", style: :unordered, content: "Ünïcödé ✓"}} =
               List.parse_line("- Ünïcödé ✓")
    end
  end

  describe "continuation_action/1" do
    test "continues unordered dash list" do
      assert {:continue, "- "} = List.continuation_action("- Buy milk")
    end

    test "continues unordered plus list" do
      assert {:continue, "+ "} = List.continuation_action("+ Item")
    end

    test "passes through on star at column 0 (heading)" do
      assert :passthrough = List.continuation_action("* Item")
    end

    test "continues indented star list" do
      assert {:continue, "  * "} = List.continuation_action("  * Item")
    end

    test "continues ordered dot list with incremented number" do
      assert {:continue, "2. "} = List.continuation_action("1. First")
    end

    test "continues ordered paren list with incremented number" do
      assert {:continue, "4) "} = List.continuation_action("3) Third")
    end

    test "continues with multi-digit number increment" do
      assert {:continue, "100. "} = List.continuation_action("99. Ninety-nine")
    end

    test "preserves indentation in continuation" do
      assert {:continue, "  - "} = List.continuation_action("  - Nested item")
    end

    test "preserves deep indentation in continuation" do
      assert {:continue, "      1. "} = List.continuation_action("      0. Zero-indexed")
    end

    test "exits list on empty unordered bullet" do
      assert :exit_list = List.continuation_action("- ")
    end

    test "exits list on empty ordered bullet" do
      assert :exit_list = List.continuation_action("1. ")
    end

    test "exits list on empty indented bullet" do
      assert :exit_list = List.continuation_action("  - ")
    end

    test "exits list on empty unchecked checkbox" do
      assert :exit_list = List.continuation_action("- [ ]")
    end

    test "exits list on empty checked checkbox" do
      assert :exit_list = List.continuation_action("- [x]")
    end

    test "exits list on empty checkbox with trailing space" do
      assert :exit_list = List.continuation_action("- [ ] ")
    end

    test "passes through on non-list lines" do
      assert :passthrough = List.continuation_action("Just text")
    end

    test "passes through on empty lines" do
      assert :passthrough = List.continuation_action("")
    end

    test "passes through on headings" do
      assert :passthrough = List.continuation_action("** Heading")
    end

    test "continues checkbox list with unchecked checkbox" do
      assert {:continue, "- [ ] "} = List.continuation_action("- [ ] Buy milk")
    end

    test "continues checked checkbox list with unchecked checkbox" do
      assert {:continue, "- [ ] "} = List.continuation_action("- [x] Already done")
    end

    test "continues in-progress checkbox with unchecked checkbox" do
      assert {:continue, "- [ ] "} = List.continuation_action("- [-] In progress")
    end

    test "continues indented checkbox list with unchecked checkbox" do
      assert {:continue, "  + [ ] "} = List.continuation_action("  + [X] Nested task")
    end

    test "continues ordered checkbox list with unchecked checkbox" do
      assert {:continue, "2. [ ] "} = List.continuation_action("1. [ ] First task")
    end
  end

  describe "build_continuation_prefix/1" do
    test "reuses unordered bullet" do
      assert "- " =
               List.build_continuation_prefix(%{
                 indent: "",
                 bullet: "-",
                 style: :unordered,
                 content: "item"
               })
    end

    test "increments ordered dot number" do
      assert "  4. " =
               List.build_continuation_prefix(%{
                 indent: "  ",
                 bullet: "3.",
                 style: :ordered_dot,
                 content: "item"
               })
    end

    test "increments ordered paren number" do
      assert "10) " =
               List.build_continuation_prefix(%{
                 indent: "",
                 bullet: "9)",
                 style: :ordered_paren,
                 content: "item"
               })
    end
  end

  describe "exit_list_replacement/1" do
    test "returns empty string for top-level list" do
      assert "" = List.exit_list_replacement("- ")
    end

    test "returns indentation for nested list" do
      assert "  " = List.exit_list_replacement("  - ")
    end

    test "returns deep indentation" do
      assert "      " = List.exit_list_replacement("      1. ")
    end

    test "returns line unchanged for non-list" do
      assert "hello" = List.exit_list_replacement("hello")
    end
  end

  describe "properties" do
    property "unordered list continuation preserves indent and bullet" do
      check all(line <- Generators.unordered_list_line()) do
        case List.continuation_action(line) do
          {:continue, prefix} ->
            # Continuation prefix should start with the same indent
            original_indent = String.replace(line, ~r/\S.*$/, "")
            assert String.starts_with?(prefix, original_indent)
            # Prefix should end with a space (ready for typing)
            assert String.ends_with?(prefix, " ")

          :exit_list ->
            :ok

          :passthrough ->
            :ok
        end
      end
    end

    property "ordered list continuation advances the number by 1" do
      check all(line <- Generators.ordered_list_line()) do
        case List.continuation_action(line) do
          {:continue, prefix} ->
            # Extract the number from the original line
            [_, orig_num] = Regex.run(~r/(\d+)[.)]/, line)
            # Extract the number from the continuation prefix
            [_, next_num] = Regex.run(~r/(\d+)[.)]/, prefix)
            assert String.to_integer(next_num) == String.to_integer(orig_num) + 1

          :exit_list ->
            :ok

          :passthrough ->
            :ok
        end
      end
    end
  end
end
