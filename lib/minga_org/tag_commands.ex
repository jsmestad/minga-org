defmodule MingaOrg.TagCommands do
  @moduledoc """
  Editor commands for org heading tag management.

  Provides state -> state command functions for toggling and
  managing tags on org headings.
  """

  alias MingaOrg.Buffer
  alias MingaOrg.Tags

  @doc """
  Toggles the tag under the cursor or at a prompted position.

  For now, this operates on the current heading line. The tag name
  would come from a picker or prompt (deferred until Minga's picker
  API is available). This command can be called with a specific tag
  via the command registry.

  Returns editor state unchanged if not on a heading.
  """
  @spec toggle_tag_on_heading(map(), String.t()) :: map()
  def toggle_tag_on_heading(state, tag) do
    buf = state.buffers.active
    {line_num, _col} = Buffer.cursor(buf)

    case find_heading_line(buf, line_num) do
      {:ok, heading_line_num} ->
        case Buffer.line_at(buf, heading_line_num) do
          {:ok, line_text} ->
            new_line = Tags.toggle_tag(line_text, tag)

            if new_line != line_text do
              old_len = String.length(line_text)

              Buffer.apply_text_edit(
                buf,
                heading_line_num,
                0,
                heading_line_num,
                old_len,
                new_line
              )
            end

            state

          _ ->
            state
        end

      :not_heading ->
        state
    end
  end

  @doc """
  Collects all tags in the current buffer.

  Returns a sorted list of unique tag strings. Useful for building
  a tag picker or completion list.
  """
  @spec all_tags_in_buffer(pid()) :: [String.t()]
  def all_tags_in_buffer(buf) do
    total = Buffer.line_count(buf)
    lines = Buffer.get_lines(buf, 0, total)
    Tags.collect_all_tags(lines)
  end

  # ── Private ────────────────────────────────────────────────────────────────

  # Walk upward from cursor to find the nearest heading line.
  @spec find_heading_line(pid(), non_neg_integer()) :: {:ok, non_neg_integer()} | :not_heading
  defp find_heading_line(_buf, line) when line < 0, do: :not_heading

  defp find_heading_line(buf, line) do
    case Buffer.line_at(buf, line) do
      {:ok, text} ->
        if Tags.parse_heading(text) != :not_heading do
          {:ok, line}
        else
          find_heading_line(buf, line - 1)
        end

      _ ->
        find_heading_line(buf, line - 1)
    end
  end
end
