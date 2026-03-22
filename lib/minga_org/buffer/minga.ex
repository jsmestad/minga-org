defmodule MingaOrg.Buffer.Minga do
  @moduledoc """
  Production buffer backend that delegates to `Minga.Buffer.Server`.

  Used at runtime when the extension is loaded into the Minga editor.
  """

  @behaviour MingaOrg.Buffer

  @impl true
  def line_at(buf, line_num) do
    case Minga.Buffer.Server.get_lines(buf, line_num, 1) do
      [line] -> {:ok, line}
      [] -> :error
    end
  end

  @impl true
  def cursor(buf), do: Minga.Buffer.Server.cursor(buf)

  @impl true
  def insert_char(buf, text), do: Minga.Buffer.Server.insert_char(buf, text)

  @impl true
  def filetype(buf), do: Minga.Buffer.Server.filetype(buf)

  @impl true
  def get_lines(buf, start_line, count),
    do: Minga.Buffer.Server.get_lines(buf, start_line, count)

  @impl true
  def line_count(buf), do: Minga.Buffer.Server.line_count(buf)

  @impl true
  def move_to(buf, pos), do: Minga.Buffer.Server.move_to(buf, pos)

  @impl true
  def apply_text_edit(buf, start_line, start_col, end_line, end_col, new_text),
    do:
      Minga.Buffer.Server.apply_text_edit(buf, start_line, start_col, end_line, end_col, new_text)

  @impl true
  def batch_decorations(buf, fun) when is_function(fun, 1),
    do: Minga.Buffer.Server.batch_decorations(buf, fun)

  @impl true
  def apply_text_edits(buf, edits), do: Minga.Buffer.Server.apply_text_edits(buf, edits)
end
