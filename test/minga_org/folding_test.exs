defmodule MingaOrg.FoldingTest do
  use ExUnit.Case, async: true

  # Tests for the pure heading parsing and range computation logic.
  # The buffer/window integration (toggle_at_cursor, cycle_global)
  # requires a running Minga editor and is tested via integration tests.

  describe "heading_ranges/1" do
    test "computes ranges for simple headings" do
      lines = ["* Heading 1", "some content", "more content", "* Heading 2", "last line"]
      ranges = heading_ranges(lines)

      assert ranges == [{0, 2}, {3, 4}]
    end

    test "handles nested headings" do
      lines = ["* Top", "body", "** Sub", "sub body", "* Next top", ""]
      ranges = heading_ranges(lines)

      assert ranges == [{0, 3}, {2, 3}, {4, 5}]
    end

    test "skips single-line headings with no body" do
      lines = ["* Heading 1", "* Heading 2", "* Heading 3"]
      ranges = heading_ranges(lines)

      assert ranges == []
    end

    test "handles no headings" do
      lines = ["just some text", "no headings here"]
      ranges = heading_ranges(lines)

      assert ranges == []
    end

    test "handles empty input" do
      assert heading_ranges([]) == []
    end

    test "heading at end of file gets range to last line" do
      lines = ["* First", "body 1", "* Last", "body 2", "body 3"]
      ranges = heading_ranges(lines)

      assert ranges == [{0, 1}, {2, 4}]
    end

    test "deeply nested headings create proper ranges" do
      lines = ["* H1", "** H2", "*** H3", "deep body", "** H2b", "body"]
      ranges = heading_ranges(lines)

      # H1 spans 0..5 (entire file)
      # H2 spans 1..3 (until H2b at same level)
      # H3 spans 2..3 (until H2b at higher level)
      # H2b spans 4..5
      assert ranges == [{0, 5}, {1, 3}, {2, 3}, {4, 5}]
    end

    test "non-heading lines with stars are ignored" do
      lines = ["* Real heading", "not *a* heading", "body"]
      ranges = heading_ranges(lines)

      assert ranges == [{0, 2}]
    end
  end

  describe "find_heading_at_or_above/2" do
    test "returns line number when cursor is on a heading" do
      lines = ["* Heading", "body"]
      assert find_heading(lines, 0) == 0
    end

    test "returns containing heading when cursor is in body" do
      lines = ["* Heading", "body line 1", "body line 2"]
      assert find_heading(lines, 2) == 0
    end

    test "returns nearest heading above" do
      lines = ["* H1", "body", "** H2", "sub body"]
      assert find_heading(lines, 3) == 2
    end

    test "returns nil when no heading above" do
      lines = ["no heading", "still no heading"]
      assert find_heading(lines, 1) == nil
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  # Pure computation: parse headings from lines and build ranges.
  # Mirrors the logic in MingaOrg.Folding without needing a buffer.

  @spec heading_ranges([String.t()]) :: [{non_neg_integer(), non_neg_integer()}]
  defp heading_ranges(lines) do
    total = length(lines)
    headings = collect_headings(lines, 0, [])
    build_ranges(headings, total)
  end

  @spec collect_headings([String.t()], non_neg_integer(), [{non_neg_integer(), pos_integer()}]) ::
          [{non_neg_integer(), pos_integer()}]
  defp collect_headings([], _idx, acc), do: Enum.reverse(acc)

  defp collect_headings([line | rest], idx, acc) do
    case heading_level(line) do
      nil -> collect_headings(rest, idx + 1, acc)
      level -> collect_headings(rest, idx + 1, [{idx, level} | acc])
    end
  end

  @spec build_ranges([{non_neg_integer(), pos_integer()}], non_neg_integer()) ::
          [{non_neg_integer(), non_neg_integer()}]
  defp build_ranges([], _total), do: []

  defp build_ranges(headings, total) do
    headings
    |> Enum.with_index()
    |> Enum.flat_map(fn {{start_line, level}, idx} ->
      rest = Enum.drop(headings, idx + 1)

      end_line =
        case Enum.find(rest, fn {_line, l} -> l <= level end) do
          {next_line, _} -> next_line - 1
          nil -> total - 1
        end

      if end_line > start_line, do: [{start_line, end_line}], else: []
    end)
  end

  @spec find_heading([String.t()], non_neg_integer()) :: non_neg_integer() | nil
  defp find_heading(_lines, line) when line < 0, do: nil

  defp find_heading(lines, line) do
    text = Enum.at(lines, line)

    if text != nil and heading_level(text) do
      line
    else
      find_heading(lines, line - 1)
    end
  end

  @spec heading_level(String.t()) :: pos_integer() | nil
  defp heading_level(line) do
    case Regex.run(~r/^(\*+) /, line) do
      [_match, stars] -> String.length(stars)
      nil -> nil
    end
  end
end
