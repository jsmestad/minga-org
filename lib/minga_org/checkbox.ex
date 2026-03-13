defmodule MingaOrg.Checkbox do
  @moduledoc """
  Checkbox toggling for org-mode lists.

  Toggles between `- [ ]` (unchecked) and `- [x]` (checked) on the
  current line.

  ## Examples

      - [ ] Buy milk     ->  - [x] Buy milk
      - [x] Buy milk     ->  - [ ] Buy milk
      - [-] In progress  ->  - [x] In progress
  """

  @doc """
  Toggles the checkbox on the current line.

  If the line has `[ ]`, changes to `[x]`. If `[x]` or `[X]`, changes
  to `[ ]`. If `[-]`, changes to `[x]`. If the line has no checkbox,
  returns state unchanged.
  """
  @spec toggle(map()) :: map()
  def toggle(state) do
    buf = state.buffers.active
    {line_num, _col} = Minga.Buffer.Server.cursor(buf)

    case Minga.Buffer.Server.line_at(buf, line_num) do
      {:ok, line_text} ->
        case toggle_checkbox_text(line_text) do
          {:ok, new_line} ->
            replace_line(buf, line_num, line_text, new_line)
            state

          :no_checkbox ->
            state
        end

      _ ->
        state
    end
  end

  @doc """
  Toggles the checkbox in a line of text.

  Returns `{:ok, new_line}` or `:no_checkbox`.
  """
  @spec toggle_checkbox_text(String.t()) :: {:ok, String.t()} | :no_checkbox
  def toggle_checkbox_text(line) do
    # Match lines like "  - [ ] text", "  - [x] text", "  * [-] text"
    # with optional leading whitespace and list markers (-, +, *, or numbered)
    regex = ~r/^(\s*(?:[-+*]|\d+[.)]) )\[([ xX\-])\](.*)$/

    case Regex.run(regex, line) do
      [_match, prefix, status, rest] ->
        new_status = toggle_status(status)
        {:ok, "#{prefix}[#{new_status}]#{rest}"}

      nil ->
        :no_checkbox
    end
  end

  # ── Private ──────────────────────────────────────────────────────────────────

  @spec toggle_status(String.t()) :: String.t()
  defp toggle_status(" "), do: "x"
  defp toggle_status("-"), do: "x"
  defp toggle_status("x"), do: " "
  defp toggle_status("X"), do: " "
  defp toggle_status(other), do: other

  @spec replace_line(pid(), non_neg_integer(), String.t(), String.t()) :: :ok
  defp replace_line(buf, line_num, old_line, new_line) do
    old_len = String.length(old_line)

    Minga.Buffer.Server.apply_text_edit(
      buf,
      line_num,
      0,
      line_num,
      old_len,
      new_line
    )
  end
end
