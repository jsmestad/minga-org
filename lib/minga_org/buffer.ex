defmodule MingaOrg.Buffer do
  @moduledoc """
  Thin wrapper around `Minga.Buffer.Server` for minga-org.

  Provides convenience functions that match the API the extension
  modules expect. This isolates all Buffer.Server call sites to one
  module, making it easy to adapt if the Minga API changes.
  """

  @doc "Returns the text of a single line, or `:error` if out of range."
  @spec line_at(pid(), non_neg_integer()) :: {:ok, String.t()} | :error
  def line_at(buf, line_num) do
    case Minga.Buffer.Server.get_lines(buf, line_num, 1) do
      [line] -> {:ok, line}
      [] -> :error
    end
  end

  @doc "Returns the cursor position as `{line, col}`."
  @spec cursor(pid()) :: {non_neg_integer(), non_neg_integer()}
  def cursor(buf) do
    Minga.Buffer.Server.cursor(buf)
  end

  @doc "Inserts text at the cursor position."
  @spec insert_char(pid(), String.t()) :: :ok
  def insert_char(buf, text) do
    Minga.Buffer.Server.insert_char(buf, text)
  end

  @doc "Returns the detected filetype atom for this buffer."
  @spec filetype(pid()) :: atom()
  def filetype(buf) do
    Minga.Buffer.Server.filetype(buf)
  end

  @doc "Returns a range of lines as a list of strings."
  @spec get_lines(pid(), non_neg_integer(), non_neg_integer()) :: [String.t()]
  def get_lines(buf, start_line, count) do
    Minga.Buffer.Server.get_lines(buf, start_line, count)
  end

  @doc "Returns the total number of lines in the buffer."
  @spec line_count(pid()) :: non_neg_integer()
  def line_count(buf) do
    Minga.Buffer.Server.line_count(buf)
  end

  @doc "Moves the cursor to the given position."
  @spec move_to(pid(), {non_neg_integer(), non_neg_integer()}) :: :ok
  def move_to(buf, pos) do
    Minga.Buffer.Server.move_to(buf, pos)
  end

  @doc "Replaces a range of text with new text."
  @spec apply_text_edit(
          pid(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t()
        ) :: :ok
  def apply_text_edit(buf, start_line, start_col, end_line, end_col, new_text) do
    Minga.Buffer.Server.apply_text_edit(buf, start_line, start_col, end_line, end_col, new_text)
  end

  @doc "Executes a batch of decoration operations atomically."
  @spec batch_decorations(pid(), (struct() -> struct())) :: :ok
  def batch_decorations(buf, fun) when is_function(fun, 1) do
    Minga.Buffer.Server.batch_decorations(buf, fun)
  end

  @doc "Applies multiple text edits in a single call."
  @spec apply_text_edits(pid(), [tuple()]) :: :ok
  def apply_text_edits(buf, edits) do
    Minga.Buffer.Server.apply_text_edits(buf, edits)
  end
end
