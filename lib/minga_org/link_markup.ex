defmodule MingaOrg.LinkMarkup do
  @moduledoc """
  Applies link decorations to an org buffer.

  For each org link, applies:
  - Highlight range on the display text (underline + link color)
  - Conceal ranges to hide bracket syntax and URL (on non-cursor lines)

  For `[[url][desc]]`: conceals `[[url][` and `]]`, displays `desc` styled.
  For `[[url]]`: conceals `[[` and `]]`, displays `url` styled.
  """

  alias MingaOrg.Buffer
  alias MingaOrg.Link

  @group :org_links
  @link_style [underline: true, fg: 0x61AFEF]

  @typedoc "A decoration descriptor for links."
  @type descriptor ::
          {:highlight, non_neg_integer(), non_neg_integer(), non_neg_integer()}
          | {:conceal, non_neg_integer(), non_neg_integer(), non_neg_integer()}

  @doc """
  Refreshes link decorations for the active org buffer.

  State -> state function for use as command advice.
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
  Applies link decorations for all lines in the buffer.
  """
  @spec apply_decorations(pid()) :: :ok
  def apply_decorations(buf) do
    total = Buffer.line_count(buf)
    {cursor_line, _col} = Buffer.cursor(buf)
    lines = Buffer.get_lines(buf, 0, total)
    descriptors = compute_descriptors(lines, cursor_line)

    Buffer.batch_decorations(buf, fn decs ->
      decs = Minga.Buffer.Decorations.remove_group(decs, @group)

      Enum.reduce(descriptors, decs, fn desc, decs ->
        apply_descriptor(decs, desc)
      end)
    end)
  end

  @doc """
  Computes link decoration descriptors for a list of lines.

  Pure function. Cursor line gets highlights only (no concealing).
  """
  @spec compute_descriptors([String.t()], non_neg_integer()) :: [descriptor()]
  def compute_descriptors(lines, cursor_line) do
    lines
    |> Enum.with_index()
    |> Enum.flat_map(fn {text, line_num} ->
      links = Link.parse(text)
      descriptors_for_links(line_num, links, line_num == cursor_line)
    end)
  end

  # ── Private ────────────────────────────────────────────────────────────────

  @spec descriptors_for_links(non_neg_integer(), [Link.parsed()], boolean()) :: [descriptor()]
  defp descriptors_for_links(_line_num, [], _cursor_line), do: []

  defp descriptors_for_links(line_num, links, cursor_line) do
    Enum.flat_map(links, fn link ->
      {display_start, display_end, conceal_ranges} = link_regions(link)

      highlight = [{:highlight, line_num, display_start, display_end}]
      conceals = build_conceals(line_num, conceal_ranges, cursor_line)

      highlight ++ conceals
    end)
  end

  @spec build_conceals(non_neg_integer(), [{non_neg_integer(), non_neg_integer()}], boolean()) ::
          [descriptor()]
  defp build_conceals(_line_num, _ranges, true), do: []

  defp build_conceals(line_num, ranges, false) do
    Enum.map(ranges, fn {from, to} -> {:conceal, line_num, from, to} end)
  end

  # Compute the display region and conceal regions for a link.
  # For [[url][desc]]: display desc, conceal [[url][ and ]]
  # For [[url]]: display url, conceal [[ and ]]
  @spec link_regions(Link.parsed()) ::
          {non_neg_integer(), non_neg_integer(), [{non_neg_integer(), non_neg_integer()}]}
  defp link_regions(%Link.Parsed{start: start, end_: end_, url: url, description: desc}) do
    if desc != nil do
      # [[url][desc]]
      # Conceal from [[ to start of desc, and the trailing ]]
      url_len = String.length(url)
      # [[url][ = 2 + url_len + 2 = url_len + 4 codepoints from start
      desc_start = start + 2 + url_len + 2
      desc_end = end_ - 2

      conceal_before = {start, desc_start}
      conceal_after = {desc_end, end_}

      {desc_start, desc_end, [conceal_before, conceal_after]}
    else
      # [[url]]
      # Conceal [[ and ]]
      url_start = start + 2
      url_end = end_ - 2

      conceal_before = {start, url_start}
      conceal_after = {url_end, end_}

      {url_start, url_end, [conceal_before, conceal_after]}
    end
  end

  @spec apply_descriptor(struct(), descriptor()) :: struct()
  defp apply_descriptor(decs, {:highlight, line_num, from, to}) do
    {_id, decs} =
      Minga.Buffer.Decorations.add_highlight(decs, {line_num, from}, {line_num, to},
        style: @link_style,
        group: @group
      )

    decs
  end

  defp apply_descriptor(decs, {:conceal, line_num, from, to}) do
    {_id, decs} =
      Minga.Buffer.Decorations.add_conceal(decs, {line_num, from}, {line_num, to}, group: @group)

    decs
  end
end
