defmodule MingaOrg.TodoTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MingaOrg.Generators
  alias MingaOrg.Todo

  @default_keywords ["TODO", "DONE"]

  describe "heading?/1" do
    test "recognizes headings" do
      assert Todo.heading?("* Heading")
      assert Todo.heading?("** Sub heading")
      assert Todo.heading?("*** Deep heading")
    end

    test "rejects non-headings" do
      refute Todo.heading?("Not a heading")
      refute Todo.heading?("- list item")
      refute Todo.heading?("")
      refute Todo.heading?("*bold text*")
    end
  end

  describe "parse_heading/1" do
    test "parses heading without keyword" do
      assert {:ok, "*", nil, "Buy groceries"} = Todo.parse_heading("* Buy groceries")
    end

    test "parses heading with TODO" do
      assert {:ok, "*", "TODO", "Buy groceries"} = Todo.parse_heading("* TODO Buy groceries")
    end

    test "parses heading with DONE" do
      assert {:ok, "**", "DONE", "Task complete"} = Todo.parse_heading("** DONE Task complete")
    end

    test "parses heading with custom keyword" do
      assert {:ok, "*", "IN-PROGRESS", "Working"} = Todo.parse_heading("* IN-PROGRESS Working")
    end

    test "returns :not_heading for non-headings" do
      assert :not_heading = Todo.parse_heading("Not a heading")
    end
  end

  describe "cycle_keyword/2" do
    test "adds TODO to plain heading" do
      assert "* TODO Buy groceries" = Todo.cycle_keyword("* Buy groceries", @default_keywords)
    end

    test "cycles TODO to DONE" do
      assert "* DONE Buy groceries" =
               Todo.cycle_keyword("* TODO Buy groceries", @default_keywords)
    end

    test "removes DONE (cycles to none)" do
      assert "* Buy groceries" = Todo.cycle_keyword("* DONE Buy groceries", @default_keywords)
    end

    test "works with multi-star headings" do
      assert "*** TODO Deep task" = Todo.cycle_keyword("*** Deep task", @default_keywords)
      assert "*** DONE Deep task" = Todo.cycle_keyword("*** TODO Deep task", @default_keywords)
    end

    test "custom keyword sequence" do
      keywords = ["TODO", "IN-PROGRESS", "DONE"]
      assert "* TODO Task" = Todo.cycle_keyword("* Task", keywords)
      assert "* IN-PROGRESS Task" = Todo.cycle_keyword("* TODO Task", keywords)
      assert "* DONE Task" = Todo.cycle_keyword("* IN-PROGRESS Task", keywords)
      assert "* Task" = Todo.cycle_keyword("* DONE Task", keywords)
    end

    test "unknown keyword cycles to first" do
      assert "* TODO Task" = Todo.cycle_keyword("* WAITING Task", @default_keywords)
    end

    test "returns non-heading unchanged" do
      assert "not a heading" = Todo.cycle_keyword("not a heading", @default_keywords)
    end
  end

  describe "properties" do
    property "cycling through full keyword sequence plus one returns to original" do
      # Use the same keywords the generator can produce so the cycle
      # length is predictable (n keywords + 1 for the "none" state).
      keywords = ["TODO", "DONE", "IN-PROGRESS", "WAITING"]

      check all(line <- Generators.org_heading()) do
        cycled =
          Enum.reduce(1..(length(keywords) + 1), line, fn _i, acc ->
            Todo.cycle_keyword(acc, keywords)
          end)

        assert cycled == line
      end
    end

    property "parse_heading then rebuild produces the original line" do
      check all(line <- Generators.org_heading()) do
        {:ok, stars, keyword, rest} = Todo.parse_heading(line)

        rebuilt =
          case keyword do
            nil -> "#{stars} #{rest}"
            kw -> "#{stars} #{kw} #{rest}"
          end

        assert rebuilt == line
      end
    end
  end
end
