defmodule MingaOrg.Markup do
  @moduledoc """
  Applies inline markup decorations to an org buffer.

  Parses visible lines for inline markup and applies highlight ranges
  (for styled content) and conceal ranges (for hidden delimiters) via
  Minga's decoration system.

  Decorations are applied in a batch to avoid per-line GenServer
  round-trips. All org markup decorations use the `:org_markup` group
  for bulk removal on refresh.

  ## Refresh strategy

  `refresh/1` is called after buffer changes (via advice on relevant
  commands) or when the cursor moves to a new line (to reveal/conceal
  delimiters). It clears all `:org_markup` decorations and reapplies
  them for the current buffer content.
  """

  alias MingaOrg.Buffer
  alias MingaOrg.Inline

  @group :org_markup

  @doc """
  Refreshes inline markup decorations for the active org buffer.

  Clears existing org markup decorations and reapplies them based on
  current buffer content. The cursor line is excluded from concealing
  (delimiters are visible for editing).

  This is a state -> state function suitable for use as command advice.
  """
  @spec refresh(map()) :: map()
  def refresh(state) do
    buf = state.workspace.buffers.active

    if Buffer.filetype(buf) == :org do
      apply_decorations(buf)
    end

    state
  end

  @doc """
  Applies inline markup decorations for all lines in the buffer.

  Uses `batch_decorations/2` for efficient bulk application.
  The cursor line has highlights but no conceals (delimiters visible).
  """
  @spec apply_decorations(pid()) :: :ok
  def apply_decorations(buf) do
    total = Buffer.line_count(buf)
    {cursor_line, _col} = Buffer.cursor(buf)

    # Single GenServer call to fetch all lines
    lines = Buffer.get_lines(buf, 0, total)

    # Compute decoration descriptors (pure calculation)
    descriptors = compute_descriptors(lines, cursor_line)

    # Apply decorations in a single batch (action)
    Buffer.batch_decorations(buf, fn decs ->
      decs = Minga.Buffer.Decorations.remove_group(decs, @group)
      apply_descriptors(decs, descriptors)
    end)
  end

  @doc """
  Computes decoration descriptors for a list of lines.

  Pure function: takes lines and cursor position, returns a list of
  decoration operations. No side effects.
  """
  @spec compute_descriptors([String.t()], non_neg_integer()) :: [descriptor()]
  def compute_descriptors(lines, cursor_line) do
    lines
    |> Enum.with_index()
    |> Enum.flat_map(fn {text, line_num} ->
      spans = Inline.parse(text)
      descriptors_for_spans(line_num, spans, line_num == cursor_line)
    end)
  end

  @typedoc "A decoration descriptor (pure data, no side effects)."
  @type descriptor ::
          {:highlight, non_neg_integer(), Inline.span()}
          | {:conceal, non_neg_integer(), non_neg_integer()}

  # ── Private ────────────────────────────────────────────────────────────────

  @spec descriptors_for_spans(non_neg_integer(), [Inline.span()], boolean()) :: [descriptor()]
  defp descriptors_for_spans(_line_num, [], _cursor_line), do: []

  defp descriptors_for_spans(line_num, spans, cursor_line) do
    Enum.flat_map(spans, fn span ->
      highlight = [{:highlight, line_num, span}]

      conceals =
        if cursor_line do
          []
        else
          [
            {:conceal, line_num, span.start},
            {:conceal, line_num, span.end_ - 1}
          ]
        end

      highlight ++ conceals
    end)
  end

  @spec apply_descriptors(struct(), [descriptor()]) :: struct()
  defp apply_descriptors(decs, descriptors) do
    Enum.reduce(descriptors, decs, fn descriptor, decs ->
      apply_descriptor(decs, descriptor)
    end)
  end

  @spec apply_descriptor(struct(), descriptor()) :: struct()
  defp apply_descriptor(decs, {:highlight, line_num, span}) do
    style = Inline.style_for(span.type)
    start_pos = {line_num, span.content_start}
    end_pos = {line_num, span.content_end}

    {_id, decs} =
      Minga.Buffer.Decorations.add_highlight(decs, start_pos, end_pos,
        style: style,
        group: @group
      )

    decs
  end

  defp apply_descriptor(decs, {:conceal, line_num, col}) do
    start_pos = {line_num, col}
    end_pos = {line_num, col + 1}

    {_id, decs} =
      Minga.Buffer.Decorations.add_conceal(decs, start_pos, end_pos, group: @group)

    decs
  end
end
