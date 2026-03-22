defmodule MingaOrg.Table do
  @moduledoc """
  Org table parsing, alignment, and cell navigation.

  Org tables are pipe-delimited:

      | Name  | Age |
      |-------+-----|
      | Alice | 30  |
      | Bob   | 25  |

  This module provides pure functions for:
  - Parsing table rows into cells
  - Computing column widths and generating aligned table text
  - Generating horizontal separator rules
  - Navigating between cells (next/previous)

  All public functions are pure (text in, data out).
  """

  @typedoc "A parsed table row."
  @type row :: {:data, [String.t()]} | {:separator, non_neg_integer()}

  @doc """
  Parses a line as a table row.

  Returns `{:data, cells}` for data rows, `{:separator, col_count}` for
  horizontal rules, or `:not_table` for non-table lines.

  ## Examples

      iex> MingaOrg.Table.parse_row("| Alice | 30 |")
      {:data, ["Alice", "30"]}

      iex> MingaOrg.Table.parse_row("|---+---|")
      {:separator, 2}

      iex> MingaOrg.Table.parse_row("Not a table")
      :not_table
  """
  @spec parse_row(String.t()) ::
          {:data, [String.t()]} | {:separator, non_neg_integer()} | :not_table
  def parse_row(line) do
    trimmed = String.trim(line)

    if String.starts_with?(trimmed, "|") do
      if separator_row?(trimmed) do
        cols = trimmed |> String.split("+") |> length()
        {:separator, cols}
      else
        cells =
          trimmed
          |> String.trim_leading("|")
          |> String.trim_trailing("|")
          |> String.split("|")
          |> Enum.map(&String.trim/1)

        {:data, cells}
      end
    else
      :not_table
    end
  end

  @doc """
  Returns true if the line is a table row (data or separator).
  """
  @spec table_line?(String.t()) :: boolean()
  def table_line?(line) do
    parse_row(line) != :not_table
  end

  @doc """
  Computes the maximum width for each column across all data rows.

  Uses `String.length/1` (codepoint count) for width calculation.
  """
  @spec column_widths([row()]) :: [non_neg_integer()]
  def column_widths(rows) do
    data_rows = Enum.filter(rows, &match?({:data, _}, &1))
    compute_widths(data_rows)
  end

  @spec compute_widths([{:data, [String.t()]}]) :: [non_neg_integer()]
  defp compute_widths([]), do: []

  defp compute_widths(data_rows) do
    max_cols = data_rows |> Enum.map(fn {:data, cells} -> length(cells) end) |> Enum.max()

    Enum.map(0..(max_cols - 1), fn col_idx ->
      data_rows
      |> Enum.map(fn {:data, cells} ->
        cell = Enum.at(cells, col_idx) || ""
        String.length(cell)
      end)
      |> Enum.max()
      |> max(1)
    end)
  end

  @doc """
  Formats a data row with cells padded to the given column widths.

  ## Examples

      iex> MingaOrg.Table.format_data_row(["Alice", "30"], [5, 3])
      "| Alice | 30  |"
  """
  @spec format_data_row([String.t()], [non_neg_integer()]) :: String.t()
  def format_data_row(cells, widths) do
    padded =
      Enum.zip_with([cells, widths], fn
        [cell, width] -> String.pad_trailing(cell, width)
      end)

    "| " <> Enum.join(padded, " | ") <> " |"
  end

  @doc """
  Formats a separator row for the given column widths.

  ## Examples

      iex> MingaOrg.Table.format_separator([5, 3])
      "|-------+-----|"
  """
  @spec format_separator([non_neg_integer()]) :: String.t()
  def format_separator(widths) do
    dashes = Enum.map(widths, fn w -> String.duplicate("-", w + 2) end)
    "|" <> Enum.join(dashes, "+") <> "|"
  end

  @doc """
  Aligns an entire table (list of raw line strings).

  Returns a list of formatted line strings with all columns aligned.
  """
  @spec align_table([String.t()]) :: [String.t()]
  def align_table(lines) do
    rows = Enum.map(lines, &parse_row/1)
    widths = column_widths(rows)

    if widths == [] do
      lines
    else
      Enum.map(rows, fn
        {:data, cells} ->
          # Pad cells list to match the expected number of columns
          padded_cells = pad_cells(cells, length(widths))
          format_data_row(padded_cells, widths)

        {:separator, _} ->
          format_separator(widths)

        :not_table ->
          ""
      end)
    end
  end

  @doc """
  Returns the column index (0-based) and cell boundaries for the cursor
  position within a table row.

  Returns `{:ok, col_index, cell_start, cell_end}` or `:not_in_table`.
  Positions are codepoint offsets.
  """
  @spec cell_at(String.t(), non_neg_integer()) ::
          {:ok, non_neg_integer(), non_neg_integer(), non_neg_integer()} | :not_in_table
  def cell_at(line, cursor_col) do
    if table_line?(line) do
      graphemes = String.graphemes(line)
      find_cell(graphemes, 0, 0, cursor_col)
    else
      :not_in_table
    end
  end

  @doc """
  Creates a new empty row matching the column count of the given widths.
  """
  @spec new_row([non_neg_integer()]) :: String.t()
  def new_row(widths) do
    cells = Enum.map(widths, fn _ -> "" end)
    format_data_row(cells, widths)
  end

  # ── Private ────────────────────────────────────────────────────────────────

  @spec separator_row?(String.t()) :: boolean()
  defp separator_row?(trimmed) do
    # A separator is | followed by dashes, +, and |
    String.match?(trimmed, ~r/^\|[-+|]+\|$/)
  end

  @spec pad_cells([String.t()], non_neg_integer()) :: [String.t()]
  defp pad_cells(cells, expected) when length(cells) >= expected, do: Enum.take(cells, expected)

  defp pad_cells(cells, expected) do
    cells ++ List.duplicate("", expected - length(cells))
  end

  @spec find_cell([String.t()], non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          {:ok, non_neg_integer(), non_neg_integer(), non_neg_integer()} | :not_in_table
  defp find_cell([], _pos, _col_idx, _cursor), do: :not_in_table

  defp find_cell(["|" | rest], pos, col_idx, cursor) do
    # Find the end of this cell (next | or end)
    cell_start = pos + 1
    cell_end = find_next_pipe(rest, cell_start)

    if cursor >= cell_start and cursor < cell_end do
      {:ok, col_idx, cell_start, cell_end}
    else
      find_cell(rest, pos + 1, col_idx + 1, cursor)
    end
  end

  defp find_cell([_ | rest], pos, col_idx, cursor) do
    find_cell(rest, pos + 1, col_idx, cursor)
  end

  @spec find_next_pipe([String.t()], non_neg_integer()) :: non_neg_integer()
  defp find_next_pipe([], pos), do: pos

  defp find_next_pipe(["|" | _], pos), do: pos

  defp find_next_pipe([_ | rest], pos) do
    find_next_pipe(rest, pos + 1)
  end
end
