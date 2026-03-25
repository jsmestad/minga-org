defmodule MingaOrg.Advice do
  @moduledoc """
  Registers command advice for org-mode behavior.

  Uses Minga's advice system to intercept editor commands and add
  org-specific behavior when the active buffer is an `.org` file.
  """

  alias MingaOrg.Buffer
  alias MingaOrg.List
  alias MingaOrg.Markup
  alias MingaOrg.Pretty
  alias MingaOrg.TagAnnotations

  @typedoc "An advice definition: {phase, command, function}."
  @type advice_def :: {:around | :after | :before, atom(), function()}

  @doc """
  Returns the list of org-mode advice definitions.

  Each tuple is `{phase, command, function}`.
  """
  @spec advice_definitions() :: [advice_def()]
  def advice_definitions do
    refresh_commands = [:move_up, :move_down, :move_left, :move_right, :insert_newline]

    around = [{:around, :insert_newline, &smart_newline/2}]

    after_advice =
      for cmd <- refresh_commands,
          fun <- [&Markup.refresh/1, &Pretty.refresh/1, &TagAnnotations.refresh/1] do
        {:after, cmd, fun}
      end

    around ++ after_advice
  end

  @doc """
  Registers all org-mode advice hooks.

  Called during `MingaOrg.init/1`.
  """
  @spec register() :: :ok
  def register do
    for {phase, command, fun} <- advice_definitions() do
      Minga.Config.Advice.register(phase, command, fun)
    end

    :ok
  end

  # ── Smart newline (list continuation) ──────────────────────────────────────

  @doc false
  @spec smart_newline((map() -> map()), map()) :: map()
  def smart_newline(execute, state) do
    buf = state.workspace.buffers.active

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
    Buffer.insert_char(buf, "\n" <> prefix)
  end

  @spec replace_with_exit(pid(), non_neg_integer(), String.t()) :: :ok
  defp replace_with_exit(buf, line_num, line_text) do
    replacement = List.exit_list_replacement(line_text)
    old_len = String.length(line_text)
    Buffer.apply_text_edit(buf, line_num, 0, line_num, old_len, replacement)
  end
end
