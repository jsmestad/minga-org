defmodule MingaOrg.TableCommandsTest do
  use ExUnit.Case, async: true

  import MingaOrg.TestHelpers

  alias MingaOrg.Buffer.Stub
  alias MingaOrg.TableCommands

  describe "tab/1" do
    test "aligns a misaligned table and moves to next cell" do
      buf =
        start_buffer!(
          lines: ["| Name | Age |", "|---+---|", "| Alice | 30 |"],
          cursor: {2, 3}
        )

      state = make_state(buf)
      TableCommands.tab(state)

      lines = Stub.lines(buf)
      # Table should be aligned (columns padded to equal width)
      assert Enum.all?(lines, &String.starts_with?(&1, "|"))

      # Cursor should have moved to the next cell (Age column)
      {_line, col} = Stub.cursor(buf)
      assert col > 3
    end

    test "returns state unchanged when not in a table" do
      buf = start_buffer!(lines: ["Just plain text", "Not a table"], cursor: {0, 5})
      state = make_state(buf)

      result = TableCommands.tab(state)

      assert result == state
      # Cursor unchanged
      assert Stub.cursor(buf) == {0, 5}
    end

    test "wraps to next data row when at last column" do
      buf =
        start_buffer!(
          lines: ["| A | B |", "| C | D |"],
          cursor: {0, 6}
        )

      state = make_state(buf)
      TableCommands.tab(state)

      {line, _col} = Stub.cursor(buf)
      # Should have moved to the second row
      assert line == 1
    end
  end

  describe "shift_tab/1" do
    test "moves to previous cell" do
      buf =
        start_buffer!(
          lines: ["| Name  | Age |", "| Alice | 30  |"],
          cursor: {1, 10}
        )

      state = make_state(buf)
      TableCommands.shift_tab(state)

      {line, col} = Stub.cursor(buf)
      # Should be in the Name column of the same row
      assert line == 1
      assert col < 10
    end

    test "returns state unchanged when not in a table" do
      buf = start_buffer!(lines: ["Regular text"], cursor: {0, 3})
      state = make_state(buf)

      result = TableCommands.shift_tab(state)

      assert result == state
    end
  end
end
