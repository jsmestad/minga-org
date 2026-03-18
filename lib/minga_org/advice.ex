defmodule MingaOrg.Advice do
  @moduledoc """
  Registers command advice for org-mode behavior.

  Uses Minga's advice system to intercept editor commands and add
  org-specific behavior when the active buffer is an `.org` file.
  """

  alias MingaOrg.Buffer
  alias MingaOrg.List
  alias MingaOrg.Markup

  @doc """
  Registers all org-mode advice hooks.

  Called during `MingaOrg.init/1`.
  """
  @spec register() :: :ok
  def register do
    Minga.Config.Advice.register(:around, :insert_newline, &smart_newline/2)

    # Refresh inline markup decorations after cursor movement and edits.
    # :after advice runs after the command completes, so decorations
    # reflect the new cursor position (revealing delimiters on cursor line).
    for cmd <- [:move_up, :move_down, :move_left, :move_right, :insert_newline] do
      Minga.Config.Advice.register(:after, cmd, &Markup.refresh/1)
    end

    :ok
  end

  # ── Smart newline (list continuation) ──────────────────────────────────────

  @doc false
  @spec smart_newline((map() -> map()), map()) :: map()
  def smart_newline(execute, state) do
    buf = state.buffers.active

    if Buffer.filetype(buf) == :org do
      handle_org_newline(execute, state, buf)
    else
      execute.(state)
    end
  end

  @spec handle_org_newline((map() -> map()), map(), pid()) :: map()
  defp handle_org_newline(execute, state, buf) do
    {line_num, _col} = Buffer.cursor(buf)

    case Buffer.line_at(buf, line_num) do
      {:ok, line_text} ->
        case List.continuation_action(line_text) do
          {:continue, prefix} ->
            insert_continuation(buf, prefix)
            state

          :exit_list ->
            replace_with_exit(buf, line_num, line_text)
            state

          :passthrough ->
            execute.(state)
        end

      _ ->
        execute.(state)
    end
  end

  @spec insert_continuation(pid(), String.t()) :: :ok
  defp insert_continuation(buf, prefix) do
    # Insert newline + the continuation prefix at cursor position
    Buffer.insert_char(buf, "\n" <> prefix)
  end

  @spec replace_with_exit(pid(), non_neg_integer(), String.t()) :: :ok
  defp replace_with_exit(buf, line_num, line_text) do
    # Replace the entire empty-bullet line with just its indentation
    replacement = List.exit_list_replacement(line_text)
    old_len = String.length(line_text)
    Buffer.apply_text_edit(buf, line_num, 0, line_num, old_len, replacement)
  end
end
