defmodule MingaOrg.Buffer.Stub do
  @moduledoc """
  In-memory buffer backend for testing.

  Agent-based stub that holds lines, cursor position, and filetype.
  Text edits are actually applied to the line array so sequential
  read-after-write operations return correct data.
  """

  use Agent

  @behaviour MingaOrg.Buffer

  @typedoc "Options for starting a stub buffer."
  @type start_opts :: [
          lines: [String.t()],
          cursor: {non_neg_integer(), non_neg_integer()},
          filetype: atom()
        ]

  @doc "Starts a stub buffer process."
  @spec start_link(start_opts()) :: Agent.on_start()
  def start_link(opts \\ []) do
    lines = Keyword.get(opts, :lines, [""])
    cursor = Keyword.get(opts, :cursor, {0, 0})
    filetype = Keyword.get(opts, :filetype, :org)

    Agent.start_link(fn ->
      %{lines: lines, cursor: cursor, filetype: filetype, decorations: nil}
    end)
  end

  # ── Behaviour callbacks ──────────────────────────────────────────────────

  @impl true
  def line_at(buf, line_num) do
    Agent.get(buf, fn state ->
      case Enum.at(state.lines, line_num) do
        nil -> :error
        line -> {:ok, line}
      end
    end)
  end

  @impl true
  def cursor(buf) do
    Agent.get(buf, & &1.cursor)
  end

  @impl true
  def insert_char(buf, text) do
    Agent.update(buf, fn state ->
      {line_num, col} = state.cursor
      current_line = Enum.at(state.lines, line_num, "")

      {before, after_text} = String.split_at(current_line, col)
      new_content = before <> text <> after_text

      # Split on newlines to handle multi-line inserts (e.g. "\nprefix")
      new_lines = String.split(new_content, "\n")
      last_new_line = List.last(new_lines)
      new_cursor_line = line_num + length(new_lines) - 1
      new_cursor_col = String.length(last_new_line) - String.length(after_text)

      lines =
        state.lines
        |> List.replace_at(line_num, nil)
        |> List.flatten()
        |> then(fn lines ->
          before_lines = Enum.take(lines, line_num)
          after_lines = Enum.drop(lines, line_num + 1)
          before_lines ++ new_lines ++ after_lines
        end)

      %{state | lines: lines, cursor: {new_cursor_line, max(new_cursor_col, 0)}}
    end)
  end

  @impl true
  def filetype(buf) do
    Agent.get(buf, & &1.filetype)
  end

  @impl true
  def get_lines(buf, start_line, count) do
    Agent.get(buf, fn state ->
      Enum.slice(state.lines, start_line, count)
    end)
  end

  @impl true
  def line_count(buf) do
    Agent.get(buf, fn state -> length(state.lines) end)
  end

  @impl true
  def move_to(buf, pos) do
    Agent.update(buf, fn state -> %{state | cursor: pos} end)
  end

  @impl true
  def apply_text_edit(buf, start_line, start_col, end_line, end_col, new_text) do
    Agent.update(buf, fn state ->
      lines = do_apply_text_edit(state.lines, start_line, start_col, end_line, end_col, new_text)
      %{state | lines: lines}
    end)
  end

  @impl true
  def batch_decorations(buf, fun) when is_function(fun, 1) do
    Agent.update(buf, fn state ->
      decs = fun.(state.decorations)
      %{state | decorations: decs}
    end)
  end

  @impl true
  def apply_text_edits(buf, edits) do
    Agent.update(buf, fn state ->
      lines =
        Enum.reduce(edits, state.lines, fn
          {{start_line, start_col}, {end_line, end_col}, text}, lines ->
            do_apply_text_edit(lines, start_line, start_col, end_line, end_col, text)

          {start_line, start_col, end_line, end_col, text}, lines ->
            do_apply_text_edit(lines, start_line, start_col, end_line, end_col, text)
        end)

      %{state | lines: lines}
    end)
  end

  # ── Test helpers ─────────────────────────────────────────────────────────

  @doc "Returns all lines in the buffer (test inspection)."
  @spec lines(pid()) :: [String.t()]
  def lines(buf), do: Agent.get(buf, & &1.lines)

  # ── Private ──────────────────────────────────────────────────────────────

  @spec do_apply_text_edit(
          [String.t()],
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t()
        ) :: [String.t()]
  defp do_apply_text_edit(lines, start_line, start_col, end_line, end_col, new_text) do
    # Get the text before the edit region on the start line
    start_line_text = Enum.at(lines, start_line, "")
    {before, _} = String.split_at(start_line_text, start_col)

    # Get the text after the edit region on the end line
    end_line_text = Enum.at(lines, end_line, "")
    {_, after_text} = String.split_at(end_line_text, end_col)

    # Build the replacement content
    replacement = before <> new_text <> after_text
    new_lines = String.split(replacement, "\n")

    # Splice into the line array
    before_lines = Enum.take(lines, start_line)
    after_lines = Enum.drop(lines, end_line + 1)

    before_lines ++ new_lines ++ after_lines
  end
end
