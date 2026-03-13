defmodule MingaOrg.Folding do
  @moduledoc """
  Heading-based folding for org-mode files.

  Computes fold ranges from org headings and provides TAB/S-TAB cycling.
  Each heading (line starting with `* `) creates a fold range spanning
  from the heading line to the line before the next same-or-higher-level
  heading (or end of file).

  ## TAB behavior

  TAB on a heading line toggles the fold at that heading.
  TAB on a non-heading line is a no-op.

  ## S-TAB behavior (global cycling)

  Cycles between two states:
  1. **OVERVIEW** — all headings folded
  2. **SHOW ALL** — everything unfolded
  """

  alias MingaOrg.Buffer

  @doc """
  Computes fold ranges for all headings in the buffer.

  Each heading creates a fold range from its line to the line before the
  next heading at the same or higher level (or end of file). Single-line
  headings with no body are excluded.
  """
  @spec fold_ranges_for_buffer(pid()) :: [struct()]
  def fold_ranges_for_buffer(buf) do
    total = Buffer.line_count(buf)
    headings = collect_headings(buf, 0, total, [])
    build_ranges(headings, total)
  end

  @doc """
  Toggles the fold at the cursor line.

  If the cursor is on a heading, toggles that heading's fold.
  If the cursor is inside a heading's body, toggles the containing
  heading's fold. Receives and returns editor state.
  """
  @spec toggle_at_cursor(map()) :: map()
  def toggle_at_cursor(state) do
    buf = state.buffers.active
    {line_num, _col} = Buffer.cursor(buf)

    case find_heading_at_or_above(buf, line_num) do
      nil ->
        state

      heading_line ->
        ranges = fold_ranges_for_buffer(buf)

        state
        |> ensure_fold_ranges(ranges)
        |> toggle_fold_at_line(heading_line)
    end
  end

  @doc """
  Cycles global fold state: if any folds are active, unfold all;
  otherwise fold all headings.
  """
  @spec cycle_global(map()) :: map()
  def cycle_global(state) do
    buf = state.buffers.active
    ranges = fold_ranges_for_buffer(buf)
    state = ensure_fold_ranges(state, ranges)

    win = active_window(state)

    if win != nil and Minga.Editor.Window.has_folds?(win) do
      update_active_window(state, &Minga.Editor.Window.unfold_all/1)
    else
      update_active_window(state, &Minga.Editor.Window.fold_all/1)
    end
  end

  # ── Private: heading parsing ───────────────────────────────────────────────

  @spec collect_headings(pid(), non_neg_integer(), non_neg_integer(), [{non_neg_integer(), pos_integer()}]) ::
          [{non_neg_integer(), pos_integer()}]
  defp collect_headings(_buf, line, total, acc) when line >= total do
    Enum.reverse(acc)
  end

  defp collect_headings(buf, line, total, acc) do
    case Buffer.line_at(buf, line) do
      {:ok, text} ->
        case heading_level(text) do
          nil -> collect_headings(buf, line + 1, total, acc)
          level -> collect_headings(buf, line + 1, total, [{line, level} | acc])
        end

      :error ->
        collect_headings(buf, line + 1, total, acc)
    end
  end

  @spec build_ranges([{non_neg_integer(), pos_integer()}], non_neg_integer()) :: [struct()]
  defp build_ranges([], _total), do: []

  defp build_ranges(headings, total) do
    headings
    |> Enum.with_index()
    |> Enum.flat_map(fn {{start_line, level}, idx} ->
      end_line = find_heading_end(headings, idx, level, total)

      if end_line > start_line do
        [Minga.Editor.FoldRange.new!(start_line, end_line)]
      else
        []
      end
    end)
  end

  @spec find_heading_end([{non_neg_integer(), pos_integer()}], non_neg_integer(), pos_integer(), non_neg_integer()) ::
          non_neg_integer()
  defp find_heading_end(headings, idx, level, total) do
    rest = Enum.drop(headings, idx + 1)

    case Enum.find(rest, fn {_line, l} -> l <= level end) do
      {next_line, _} -> next_line - 1
      nil -> total - 1
    end
  end

  @spec find_heading_at_or_above(pid(), non_neg_integer()) :: non_neg_integer() | nil
  defp find_heading_at_or_above(_buf, line) when line < 0, do: nil

  defp find_heading_at_or_above(buf, line) do
    case Buffer.line_at(buf, line) do
      {:ok, text} ->
        if heading_level(text), do: line, else: find_heading_at_or_above(buf, line - 1)

      :error ->
        find_heading_at_or_above(buf, line - 1)
    end
  end

  @spec heading_level(String.t()) :: pos_integer() | nil
  defp heading_level(line) do
    case Regex.run(~r/^(\*+) /, line) do
      [_match, stars] -> String.length(stars)
      nil -> nil
    end
  end

  # ── Private: state manipulation ────────────────────────────────────────────

  @spec ensure_fold_ranges(map(), [struct()]) :: map()
  defp ensure_fold_ranges(state, ranges) do
    update_active_window(state, &Minga.Editor.Window.set_fold_ranges(&1, ranges))
  end

  @spec toggle_fold_at_line(map(), non_neg_integer()) :: map()
  defp toggle_fold_at_line(state, line) do
    update_active_window(state, &Minga.Editor.Window.toggle_fold(&1, line))
  end

  @spec active_window(map()) :: struct() | nil
  defp active_window(state) do
    Minga.Editor.State.active_window_struct(state)
  end

  @spec update_active_window(map(), (struct() -> struct())) :: map()
  defp update_active_window(state, fun) do
    case active_window(state) do
      nil -> state
      %{id: id} -> Minga.Editor.State.update_window(state, id, fun)
    end
  end
end
