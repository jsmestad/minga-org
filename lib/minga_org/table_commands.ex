defmodule MingaOrg.TableCommands do
  @moduledoc """
  Editor commands for org table navigation and alignment.

  Provides TAB and S-TAB handlers for insert-mode table editing:
  re-align the table and move to the next/previous cell.
  """

  alias MingaOrg.Buffer
  alias MingaOrg.Table

  @doc """
  TAB inside a table: re-align and move to the next cell.

  If the cursor is not inside a table row, returns state unchanged
  (letting the global insert-mode TAB handle indentation).
  """
  @spec tab(map()) :: map()
  def tab(state) do
    buf = state.workspace.buffers.active
    {cursor_line, cursor_col} = Buffer.cursor(buf)

    case Buffer.line_at(buf, cursor_line) do
      {:ok, line} ->
        if Table.table_line?(line) do
          align_and_move(buf, cursor_line, cursor_col, :forward)
          state
        else
          state
        end

      _ ->
        state
    end
  end

  @doc """
  S-TAB inside a table: re-align and move to the previous cell.
  """
  @spec shift_tab(map()) :: map()
  def shift_tab(state) do
    buf = state.workspace.buffers.active
    {cursor_line, cursor_col} = Buffer.cursor(buf)

    case Buffer.line_at(buf, cursor_line) do
      {:ok, line} ->
        if Table.table_line?(line) do
          align_and_move(buf, cursor_line, cursor_col, :backward)
          state
        else
          state
        end

      _ ->
        state
    end
  end

  # ── Private ────────────────────────────────────────────────────────────────

  @spec align_and_move(pid(), non_neg_integer(), non_neg_integer(), :forward | :backward) :: :ok
  defp align_and_move(buf, cursor_line, cursor_col, direction) do
    {table_start, table_lines} = find_table_block(buf, cursor_line)
    aligned = Table.align_table(table_lines)
    table_end = table_start + length(table_lines) - 1

    write_aligned_lines(buf, table_start, table_end, table_lines, aligned)

    # Find the cursor's column index in the original line
    relative_line = cursor_line - table_start
    original_line = Enum.at(table_lines, relative_line, "")
    col_index = current_column_index(original_line, cursor_col)

    # Navigate to the target cell in the aligned table
    {target_line, target_col} =
      find_target_cell(aligned, relative_line, col_index, direction)

    Buffer.move_to(buf, {table_start + target_line, target_col})
  end

  @spec find_table_block(pid(), non_neg_integer()) :: {non_neg_integer(), [String.t()]}
  defp find_table_block(buf, cursor_line) do
    total = Buffer.line_count(buf)
    start_line = scan_table_boundary(buf, cursor_line, -1, 0)
    end_line = scan_table_boundary(buf, cursor_line, 1, total - 1)
    lines = Buffer.get_lines(buf, start_line, end_line - start_line + 1)
    {start_line, lines}
  end

  @spec scan_table_boundary(pid(), non_neg_integer(), -1 | 1, non_neg_integer()) ::
          non_neg_integer()
  defp scan_table_boundary(buf, line, direction, limit) do
    next = line + direction

    if past_limit?(next, direction, limit) do
      line
    else
      maybe_extend_boundary(buf, line, next, direction, limit)
    end
  end

  @spec past_limit?(integer(), -1 | 1, non_neg_integer()) :: boolean()
  defp past_limit?(next, -1, limit), do: next < limit
  defp past_limit?(next, 1, limit), do: next > limit

  @spec maybe_extend_boundary(
          pid(),
          non_neg_integer(),
          non_neg_integer(),
          -1 | 1,
          non_neg_integer()
        ) :: non_neg_integer()
  defp maybe_extend_boundary(buf, line, next, direction, limit) do
    with {:ok, text} <- Buffer.line_at(buf, next),
         true <- Table.table_line?(text) do
      scan_table_boundary(buf, next, direction, limit)
    else
      _ -> line
    end
  end

  @spec write_aligned_lines(pid(), non_neg_integer(), non_neg_integer(), [String.t()], [
          String.t()
        ]) :: :ok
  defp write_aligned_lines(buf, table_start, _table_end, original, aligned) do
    edits =
      original
      |> Enum.zip(aligned)
      |> Enum.with_index()
      |> Enum.reject(fn {{old, new}, _idx} -> old == new end)
      |> Enum.map(fn {{old, new}, idx} ->
        line = table_start + idx
        old_len = String.length(old)
        {{line, 0}, {line, old_len}, new}
      end)

    if edits != [] do
      Buffer.apply_text_edits(buf, edits)
    end

    :ok
  end

  @spec current_column_index(String.t(), non_neg_integer()) :: non_neg_integer()
  defp current_column_index(line, cursor_col) do
    case Table.cell_at(line, cursor_col) do
      {:ok, col_index, _start, _end} -> col_index
      :not_in_table -> 0
    end
  end

  @spec find_target_cell([String.t()], non_neg_integer(), non_neg_integer(), :forward | :backward) ::
          {non_neg_integer(), non_neg_integer()}
  defp find_target_cell(lines, current_line, col_index, :forward) do
    target_col = col_index + 1
    find_data_cell(lines, current_line, target_col, :forward)
  end

  defp find_target_cell(lines, current_line, col_index, :backward) do
    target_col = col_index - 1
    find_data_cell(lines, current_line, target_col, :backward)
  end

  @spec find_data_cell([String.t()], non_neg_integer(), integer(), :forward | :backward) ::
          {non_neg_integer(), non_neg_integer()}
  defp find_data_cell(lines, line_idx, col_idx, direction) do
    line = Enum.at(lines, line_idx, "")
    row = Table.parse_row(line)
    max_col = row_column_count(row) - 1

    cond do
      # Valid column in current row
      col_idx >= 0 and col_idx <= max_col and match?({:data, _}, row) ->
        cell_start_col(line, col_idx)
        |> then(&{line_idx, &1})

      # Moved past end: go to first cell of next data row
      direction == :forward ->
        next_data_line(lines, line_idx + 1, :forward)
        |> case do
          {:ok, next_line} -> {next_line, cell_start_col(Enum.at(lines, next_line), 0)}
          :none -> {line_idx, cell_start_col(line, max(max_col, 0))}
        end

      # Moved before start: go to last cell of previous data row
      direction == :backward ->
        next_data_line(lines, line_idx - 1, :backward)
        |> case do
          {:ok, prev_line} ->
            prev_row = Table.parse_row(Enum.at(lines, prev_line))
            prev_max = row_column_count(prev_row) - 1
            {prev_line, cell_start_col(Enum.at(lines, prev_line), max(prev_max, 0))}

          :none ->
            {line_idx, cell_start_col(line, 0)}
        end
    end
  end

  @spec next_data_line([String.t()], integer(), :forward | :backward) ::
          {:ok, non_neg_integer()} | :none
  defp next_data_line(_lines, idx, _dir) when idx < 0, do: :none

  defp next_data_line(lines, idx, _dir) when idx >= length(lines), do: :none

  defp next_data_line(lines, idx, dir) do
    case Table.parse_row(Enum.at(lines, idx)) do
      {:data, _} -> {:ok, idx}
      _ -> next_data_line(lines, idx + if(dir == :forward, do: 1, else: -1), dir)
    end
  end

  @spec row_column_count(Table.row() | :not_table) :: non_neg_integer()
  defp row_column_count({:data, cells}), do: length(cells)
  defp row_column_count(_), do: 0

  @spec cell_start_col(String.t(), non_neg_integer()) :: non_neg_integer()
  defp cell_start_col(line, target_col_index) do
    # Walk through positions to find the cell_at that matches target_col_index
    line_len = String.length(line)
    find_cell_start(line, 0, line_len, target_col_index)
  end

  @spec find_cell_start(String.t(), non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          non_neg_integer()
  defp find_cell_start(_line, pos, len, _target) when pos >= len, do: 0

  defp find_cell_start(line, pos, len, target) do
    case Table.cell_at(line, pos) do
      {:ok, ^target, start, _end} -> start
      _ -> find_cell_start(line, pos + 1, len, target)
    end
  end
end
