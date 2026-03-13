defmodule MingaOrg.TodoTest do
  use ExUnit.Case, async: true

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
      assert "* DONE Buy groceries" = Todo.cycle_keyword("* TODO Buy groceries", @default_keywords)
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
end
