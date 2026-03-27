defmodule MingaOrg.TagAnnotations do
  @moduledoc """
  Renders org heading tags as pill badge annotations.

  Parses heading lines for tags and replaces the raw `:tag1:tag2:` syntax
  with colored pill badges using Minga's line annotation API. Each tag
  becomes a separate `:inline_pill` annotation positioned after the
  heading text.

  On non-cursor lines, the raw tag text is concealed and pills are shown.
  On the cursor line, raw syntax is visible for editing (no pills, no conceals).

  All decorations use the `:org_tags` group for bulk clear/refresh.

  ## Color strategy

  Tags get a background color by hashing the tag name into a predefined
  palette. This gives consistent colors per tag name without configuration.
  Users can override individual tag colors via the extension config.
  """

  alias MingaOrg.Buffer
  alias MingaOrg.Tags

  @group :org_tags

  # Visually distinct pill colors (indigo, emerald, amber, rose, sky, violet, orange, teal).
  # Foreground is always white for contrast.
  @default_palette [
    0x6366F1,
    0x10B981,
    0xF59E0B,
    0xF43F5E,
    0x0EA5E9,
    0x8B5CF6,
    0xF97316,
    0x14B8A6
  ]

  @default_fg 0xFFFFFF

  @typedoc "Configuration for tag pill annotations."
  @type config :: %{
          palette: [non_neg_integer()],
          fg: non_neg_integer(),
          tag_colors: %{String.t() => non_neg_integer()},
          enabled: boolean()
        }

  @typedoc "A decoration descriptor for tag annotations."
  @type descriptor ::
          {:annotation, non_neg_integer(), String.t(), non_neg_integer(), non_neg_integer()}
          | {:conceal, non_neg_integer(), non_neg_integer(), non_neg_integer()}

  @doc """
  Returns the default configuration.
  """
  @spec default_config() :: config()
  def default_config do
    %{
      palette: @default_palette,
      fg: @default_fg,
      tag_colors: %{},
      enabled: true
    }
  end

  @doc """
  Refreshes tag pill annotations for the active org buffer.

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
  Applies tag pill annotations for all lines in the buffer.

  Fetches all lines in a single call, computes descriptors, and
  applies them in a batch.
  """
  @spec apply_decorations(pid()) :: :ok
  def apply_decorations(buf) do
    total = Buffer.line_count(buf)
    {cursor_line, _col} = Buffer.cursor(buf)
    lines = Buffer.get_lines(buf, 0, total)

    tag_colors = Minga.Config.Options.get_extension_option(:minga_org, :tag_colors) || %{}
    config = %{default_config() | tag_colors: tag_colors}
    descriptors = compute_descriptors(lines, cursor_line, config)

    Buffer.batch_decorations(buf, fn decs ->
      decs = Minga.Core.Decorations.remove_group(decs, @group)

      Enum.reduce(descriptors, decs, fn desc, decs ->
        apply_descriptor(decs, desc)
      end)
    end)
  end

  @doc """
  Computes tag annotation descriptors for a list of lines.

  Pure function. Returns a list of annotation and conceal descriptors.
  The cursor line is excluded (raw syntax visible for editing).

  ## Example

      compute_descriptors(["* Heading :work:urgent:"], 99)
      #=> [
      #=>   {:conceal, 0, 9, 23},
      #=>   {:annotation, 0, "work", bg_color, 0xFFFFFF},
      #=>   {:annotation, 0, "urgent", bg_color, 0xFFFFFF}
      #=> ]
  """
  @spec compute_descriptors([String.t()], non_neg_integer(), config()) :: [descriptor()]
  def compute_descriptors(lines, cursor_line, config \\ default_config())

  def compute_descriptors(_lines, _cursor_line, %{enabled: false}), do: []

  def compute_descriptors(lines, cursor_line, config) do
    lines
    |> Enum.with_index()
    |> Enum.reject(fn {_line, line_num} -> line_num == cursor_line end)
    |> Enum.flat_map(fn {line, line_num} ->
      descriptors_for_line(line, line_num, config)
    end)
  end

  @doc """
  Returns the background color for a tag name.

  If the tag has an explicit color in the config, that's used.
  Otherwise, the tag name is hashed into the palette.

  ## Examples

      iex> MingaOrg.TagAnnotations.color_for_tag("work", MingaOrg.TagAnnotations.default_config())
      0x14B8A6
  """
  @spec color_for_tag(String.t(), config()) :: non_neg_integer()
  def color_for_tag(tag, %{tag_colors: overrides, palette: palette}) do
    case Map.get(overrides, tag) do
      nil -> Enum.at(palette, hash_index(tag, length(palette)))
      color -> color
    end
  end

  # ── Private ────────────────────────────────────────────────────────────────

  @spec descriptors_for_line(String.t(), non_neg_integer(), config()) :: [descriptor()]
  defp descriptors_for_line(line, line_num, config) do
    case Tags.parse_heading(line) do
      %{raw_tags: nil} ->
        []

      %{tags: tags, raw_tags: raw_tags} when is_binary(raw_tags) ->
        conceal = build_conceal(line, line_num, raw_tags)
        annotations = build_annotations(line_num, tags, config)
        [conceal | annotations]

      :not_heading ->
        []
    end
  end

  @spec build_conceal(String.t(), non_neg_integer(), String.t()) :: descriptor()
  defp build_conceal(line, line_num, raw_tags) do
    line_len = String.length(line)
    tag_len = String.length(raw_tags)
    # Conceal the space before tags + the tag text itself
    start_col = max(line_len - tag_len - 1, 0)
    {:conceal, line_num, start_col, line_len}
  end

  @spec build_annotations(non_neg_integer(), [String.t()], config()) :: [descriptor()]
  defp build_annotations(line_num, tags, config) do
    Enum.map(tags, fn tag ->
      bg = color_for_tag(tag, config)
      {:annotation, line_num, tag, bg, config.fg}
    end)
  end

  @spec hash_index(String.t(), pos_integer()) :: non_neg_integer()
  defp hash_index(tag, palette_size) do
    <<hash::unsigned-32, _rest::binary>> = :erlang.md5(tag)
    rem(hash, palette_size)
  end

  @spec apply_descriptor(struct(), descriptor()) :: struct()
  defp apply_descriptor(decs, {:conceal, line_num, start_col, end_col}) do
    {_id, decs} =
      Minga.Core.Decorations.add_conceal(decs, {line_num, start_col}, {line_num, end_col},
        group: @group
      )

    decs
  end

  defp apply_descriptor(decs, {:annotation, line_num, text, bg, fg}) do
    {_id, decs} =
      Minga.Core.Decorations.add_annotation(decs, line_num, text,
        kind: :inline_pill,
        bg: bg,
        fg: fg,
        group: @group
      )

    decs
  end
end
