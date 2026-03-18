defmodule MingaOrg.Heading do
  @moduledoc """
  Heading operations for org-mode: promote, demote, move up/down.

  Promote decreases the star count (e.g., `*** Heading` -> `** Heading`).
  Demote increases it. Move up/down swaps the heading (and its subtree)
  with the sibling above or below.
  """

  alias MingaOrg.Buffer

  @doc """
  Promotes the current heading (decreases star count by one).

  A single-star heading cannot be promoted further.
  """
  @spec promote(map()) :: map()
  def promote(state) do
    transform_heading(state, fn stars, rest ->
      if String.length(stars) > 1 do
        {String.slice(stars, 1..-1//1), rest}
      else
        {stars, rest}
      end
    end)
  end

  @doc """
  Demotes the current heading (increases star count by one).
  """
  @spec demote(map()) :: map()
  def demote(state) do
    transform_heading(state, fn stars, rest ->
      {"*" <> stars, rest}
    end)
  end

  @doc """
  Moves the current heading (with its subtree) up one sibling position.

  If the heading is already the first sibling at its level, or if the
  cursor is not on a heading, returns state unchanged.
  """
  @spec move_up(map()) :: map()
  def move_up(state) do
    swap_heading(state, :up)
  end

  @doc """
  Moves the current heading (with its subtree) down one sibling position.

  If the heading is already the last sibling at its level, or if the
  cursor is not on a heading, returns state unchanged.
  """
  @spec move_down(map()) :: map()
  def move_down(state) do
    swap_heading(state, :down)
  end

  # ── Private: transform ───────────────────────────────────────────────────────

  @spec transform_heading(map(), (String.t(), String.t() -> {String.t(), String.t()})) :: map()
  defp transform_heading(state, transform_fn) do
    buf = state.buffers.active
    {line_num, _col} = Buffer.cursor(buf)

    case Buffer.line_at(buf, line_num) do
      {:ok, line_text} ->
        case MingaOrg.Todo.parse_heading(line_text) do
          {:ok, stars, keyword, rest} ->
            {new_stars, new_rest} = transform_fn.(stars, rest)
            new_line = build_heading(new_stars, keyword, new_rest)
            replace_line(buf, line_num, line_text, new_line)
            state

          :not_heading ->
            state
        end

      _ ->
        state
    end
  end

  # ── Private: swap headings ─────────────────────────────────────────────────

  @spec swap_heading(map(), :up | :down) :: map()
  defp swap_heading(state, direction) do
    buf = state.buffers.active
    {line_num, _col} = Buffer.cursor(buf)
    total = Buffer.line_count(buf)

    case Buffer.line_at(buf, line_num) do
      {:ok, line_text} ->
        case heading_level(line_text) do
          nil ->
            state

          level ->
            subtree_end = find_subtree_end(buf, line_num, level, total)
            do_swap(state, buf, direction, line_num, subtree_end, level, total)
        end

      _ ->
        state
    end
  end

  @spec do_swap(
          map(),
          pid(),
          :up | :down,
          non_neg_integer(),
          non_neg_integer(),
          pos_integer(),
          non_neg_integer()
        ) :: map()
  defp do_swap(state, buf, :up, line_num, subtree_end, level, _total) do
    case find_prev_sibling(buf, line_num, level) do
      nil ->
        state

      prev_start ->
        prev_end = line_num - 1
        swap_ranges(buf, prev_start, prev_end, line_num, subtree_end)
        Buffer.move_to(buf, {prev_start, 0})
        state
    end
  end

  defp do_swap(state, buf, :down, line_num, subtree_end, level, total) do
    next_start = subtree_end + 1

    if next_start >= total do
      state
    else
      case Buffer.line_at(buf, next_start) do
        {:ok, next_line} ->
          case heading_level(next_line) do
            ^level ->
              next_end = find_subtree_end(buf, next_start, level, total)
              swap_ranges(buf, line_num, subtree_end, next_start, next_end)
              offset = next_end - next_start + 1
              Buffer.move_to(buf, {line_num + offset, 0})
              state

            _ ->
              state
          end

        _ ->
          state
      end
    end
  end

  @spec find_subtree_end(pid(), non_neg_integer(), pos_integer(), non_neg_integer()) ::
          non_neg_integer()
  defp find_subtree_end(buf, start_line, level, total) do
    find_subtree_end_loop(buf, start_line + 1, level, total)
  end

  @spec find_subtree_end_loop(pid(), non_neg_integer(), pos_integer(), non_neg_integer()) ::
          non_neg_integer()
  defp find_subtree_end_loop(buf, current, level, total) when current < total do
    case Buffer.line_at(buf, current) do
      {:ok, line} ->
        case heading_level(line) do
          nil -> find_subtree_end_loop(buf, current + 1, level, total)
          found_level when found_level <= level -> current - 1
          _deeper -> find_subtree_end_loop(buf, current + 1, level, total)
        end

      _ ->
        current - 1
    end
  end

  defp find_subtree_end_loop(_buf, _current, _level, total), do: total - 1

  @spec find_prev_sibling(pid(), non_neg_integer(), pos_integer()) :: non_neg_integer() | nil
  defp find_prev_sibling(buf, line_num, level) do
    find_prev_sibling_loop(buf, line_num - 1, level)
  end

  @spec find_prev_sibling_loop(pid(), non_neg_integer(), pos_integer()) :: non_neg_integer() | nil
  defp find_prev_sibling_loop(_buf, line_num, _level) when line_num < 0, do: nil

  defp find_prev_sibling_loop(buf, line_num, level) do
    case Buffer.line_at(buf, line_num) do
      {:ok, line} ->
        case heading_level(line) do
          nil -> find_prev_sibling_loop(buf, line_num - 1, level)
          ^level -> line_num
          found when found < level -> nil
          _deeper -> find_prev_sibling_loop(buf, line_num - 1, level)
        end

      _ ->
        nil
    end
  end

  @spec swap_ranges(
          pid(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok
  defp swap_ranges(buf, a_start, a_end, b_start, b_end) do
    a_lines = read_lines(buf, a_start, a_end)
    b_lines = read_lines(buf, b_start, b_end)

    a_text = Enum.join(a_lines, "\n")
    b_text = Enum.join(b_lines, "\n")

    a_end_col = String.length(List.last(a_lines) || "")
    b_end_col = String.length(List.last(b_lines) || "")

    edits = [
      {{b_start, 0}, {b_end, b_end_col}, a_text},
      {{a_start, 0}, {a_end, a_end_col}, b_text}
    ]

    Buffer.apply_text_edits(buf, edits)
  end

  @spec read_lines(pid(), non_neg_integer(), non_neg_integer()) :: [String.t()]
  defp read_lines(buf, from, to) do
    Enum.map(from..to, fn n ->
      case Buffer.line_at(buf, n) do
        {:ok, text} -> text
        _ -> ""
      end
    end)
  end

  # ── Private: helpers ─────────────────────────────────────────────────────────

  @spec heading_level(String.t()) :: pos_integer() | nil
  defp heading_level(line) do
    case Regex.run(~r/^(\*+) /, line) do
      [_match, stars] -> String.length(stars)
      nil -> nil
    end
  end

  @spec build_heading(String.t(), String.t() | nil, String.t()) :: String.t()
  defp build_heading(stars, nil, rest), do: "#{stars} #{rest}"
  defp build_heading(stars, keyword, rest), do: "#{stars} #{keyword} #{rest}"

  @spec replace_line(pid(), non_neg_integer(), String.t(), String.t()) :: :ok
  defp replace_line(buf, line_num, old_line, new_line) do
    old_len = String.length(old_line)
    Buffer.apply_text_edit(buf, line_num, 0, line_num, old_len, new_line)
  end
end
