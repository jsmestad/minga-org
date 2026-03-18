defmodule MingaOrg.TableTest do
  use ExUnit.Case, async: true

  alias MingaOrg.Table

  describe "parse_row/1" do
    test "parses data row" do
      assert {:data, ["Alice", "30"]} = Table.parse_row("| Alice | 30 |")
    end

    test "parses data row with extra spaces" do
      assert {:data, ["Name", "Age"]} = Table.parse_row("|  Name  |  Age  |")
    end

    test "parses single column" do
      assert {:data, ["Only"]} = Table.parse_row("| Only |")
    end

    test "parses empty cells" do
      assert {:data, ["", ""]} = Table.parse_row("|  |  |")
    end

    test "parses separator row" do
      assert {:separator, 2} = Table.parse_row("|---+---|")
    end

    test "parses separator with varying dash counts" do
      assert {:separator, 3} = Table.parse_row("|-------+-----+--|")
    end

    test "returns not_table for plain text" do
      assert :not_table = Table.parse_row("Not a table")
    end

    test "returns not_table for empty string" do
      assert :not_table = Table.parse_row("")
    end

    test "returns not_table for heading" do
      assert :not_table = Table.parse_row("* Heading")
    end

    test "parses row with unicode content" do
      assert {:data, ["café", "naïve"]} = Table.parse_row("| café | naïve |")
    end
  end

  describe "column_widths/1" do
    test "computes widths from data rows" do
      rows = [{:data, ["Alice", "30"]}, {:data, ["Bob", "100"]}]
      assert [5, 3] = Table.column_widths(rows)
    end

    test "ignores separator rows" do
      rows = [{:data, ["A", "B"]}, {:separator, 2}, {:data, ["CC", "DDD"]}]
      assert [2, 3] = Table.column_widths(rows)
    end

    test "minimum width is 1" do
      rows = [{:data, ["", ""]}]
      assert [1, 1] = Table.column_widths(rows)
    end

    test "returns empty for no data rows" do
      assert [] = Table.column_widths([{:separator, 2}])
    end

    test "handles uneven column counts" do
      rows = [{:data, ["A", "B", "C"]}, {:data, ["D", "E"]}]
      assert [1, 1, 1] = Table.column_widths(rows)
    end
  end

  describe "format_data_row/2" do
    test "pads cells to column widths" do
      assert "| Alice | 30  |" = Table.format_data_row(["Alice", "30"], [5, 3])
    end

    test "handles single column" do
      assert "| X |" = Table.format_data_row(["X"], [1])
    end
  end

  describe "format_separator/1" do
    test "generates separator for widths" do
      assert "|-------+-----|" = Table.format_separator([5, 3])
    end

    test "single column separator" do
      assert "|---|" = Table.format_separator([1])
    end
  end

  describe "align_table/1" do
    test "aligns simple table" do
      lines = ["| Name | Age |", "|---+---|", "| Alice | 30 |", "| Bob | 100 |"]
      aligned = Table.align_table(lines)

      assert aligned == [
               "| Name  | Age |",
               "|-------+-----|",
               "| Alice | 30  |",
               "| Bob   | 100 |"
             ]
    end

    test "aligns table with uneven cells" do
      lines = ["| A | B |", "| CC | DDD |"]
      aligned = Table.align_table(lines)

      assert aligned == [
               "| A  | B   |",
               "| CC | DDD |"
             ]
    end

    test "handles table with only separator" do
      # No data rows, returns input unchanged
      lines = ["|---+---|"]
      assert ["|---+---|"] = Table.align_table(lines)
    end
  end

  describe "table_line?/1" do
    test "true for data row" do
      assert Table.table_line?("| A | B |")
    end

    test "true for separator" do
      assert Table.table_line?("|---+---|")
    end

    test "false for plain text" do
      refute Table.table_line?("plain text")
    end
  end

  describe "cell_at/2" do
    test "finds cell at cursor position" do
      # "| Alice | 30 |"
      #  01234567890123
      # Cell 0: positions 1-7 (space A l i c e space), cell 1: 8-12
      assert {:ok, 0, 1, 8} = Table.cell_at("| Alice | 30 |", 3)
    end

    test "finds second cell" do
      assert {:ok, 1, 9, 13} = Table.cell_at("| Alice | 30 |", 10)
    end

    test "returns not_in_table for non-table line" do
      assert :not_in_table = Table.cell_at("Not a table", 5)
    end
  end

  describe "new_row/1" do
    test "creates empty row with correct widths" do
      assert "| " <> _ = Table.new_row([5, 3])
      row = Table.new_row([5, 3])
      {:data, cells} = Table.parse_row(row)
      assert length(cells) == 2
    end
  end
end
