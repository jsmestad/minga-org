defmodule MingaOrg.Pretty do
  @moduledoc """
  Pretty bullets for org-mode headings and list items.

  Replaces heading stars (`*`, `**`, `***`) with styled Unicode bullets
  that vary by depth, and list bullets (`-`, `+`) with cleaner symbols.
  Inspired by `org-superstar-mode` and `org-modern` in Emacs.

  The buffer text is never modified; only the display changes via
  Minga's conceal mechanism (replace concealed characters with a
  Unicode replacement).

  All public functions are pure.
  """

  @default_heading_bullets ["◉", "○", "◈", "◇"]
  @default_list_bullet "•"

  @typedoc "Configuration for pretty bullets."
  @type config :: %{
          heading_bullets: [String.t()],
          list_bullet: String.t(),
          enabled: boolean()
        }

  alias MingaOrg.Buffer

  @group :org_pretty

  @typedoc "A decoration descriptor for pretty bullets."
  @type descriptor ::
          {:conceal_replace, non_neg_integer(), non_neg_integer(), non_neg_integer(), String.t()}

  @doc """
  Returns the default configuration.
  """
  @spec default_config() :: config()
  def default_config do
    %{
      heading_bullets: @default_heading_bullets,
      list_bullet: @default_list_bullet,
      enabled: true
    }
  end

  @doc """
  Refreshes pretty bullet decorations for the active org buffer.

  This is a state -> state function suitable for use as command advice.
  """
  @spec refresh(map()) :: map()
  def refresh(state) do
    buf = state.buffers.active

    if Buffer.filetype(buf) == :org do
      apply_decorations(buf)
    end

    state
  end

  @doc """
  Applies pretty bullet decorations for all lines in the buffer.

  Fetches all lines in a single call, computes decorations, and
  applies them in a batch.
  """
  @spec apply_decorations(pid()) :: :ok
  def apply_decorations(buf) do
    total = Buffer.line_count(buf)
    {cursor_line, _col} = Buffer.cursor(buf)
    lines = Buffer.get_lines(buf, 0, total)
    descriptors = compute_decorations(lines, cursor_line)

    Buffer.batch_decorations(buf, fn decs ->
      decs = Minga.Buffer.Decorations.remove_group(decs, @group)

      Enum.reduce(descriptors, decs, fn {:conceal_replace, line, start_col, end_col, replacement},
                                        decs ->
        {_id, decs} =
          Minga.Buffer.Decorations.add_conceal(decs, {line, start_col}, {line, end_col},
            replacement: replacement,
            group: @group
          )

        decs
      end)
    end)
  end

  @doc """
  Returns the Unicode bullet for a heading at the given level (1-indexed).

  Cycles through the bullet set for levels deeper than the set length.

  ## Examples

      iex> MingaOrg.Pretty.heading_bullet(1)
      "◉"

      iex> MingaOrg.Pretty.heading_bullet(2)
      "○"

      iex> MingaOrg.Pretty.heading_bullet(5)
      "◉"
  """
  @spec heading_bullet(pos_integer()) :: String.t()
  def heading_bullet(level), do: heading_bullet(level, @default_heading_bullets)

  @spec heading_bullet(pos_integer(), [String.t()]) :: String.t()
  def heading_bullet(level, bullets) when level >= 1 do
    idx = rem(level - 1, length(bullets))
    Enum.at(bullets, idx)
  end

  @doc """
  Computes pretty bullet decorations for a list of lines.

  Returns a list of conceal-with-replacement descriptors. Each descriptor
  specifies a line, start column, end column, and replacement character.

  Heading lines: the stars + space are concealed and replaced with a
  single Unicode bullet (depth-dependent).

  List lines: the bullet character is concealed and replaced with the
  configured Unicode symbol.

  The cursor line is excluded (raw characters visible for editing).
  """
  @spec compute_decorations([String.t()], non_neg_integer(), config()) :: [descriptor()]
  def compute_decorations(lines, cursor_line, config \\ default_config()) do
    if not config.enabled do
      []
    else
      lines
      |> Enum.with_index()
      |> Enum.flat_map(fn {line, line_num} ->
        if line_num == cursor_line do
          []
        else
          decorations_for_line(line, line_num, config)
        end
      end)
    end
  end

  # ── Private ────────────────────────────────────────────────────────────────

  @spec decorations_for_line(String.t(), non_neg_integer(), config()) :: [descriptor()]
  defp decorations_for_line(line, line_num, config) do
    case classify_line(line) do
      {:heading, level, star_count} ->
        bullet = heading_bullet(level, config.heading_bullets)
        # Conceal all stars + the trailing space, replace with the bullet
        [{:conceal_replace, line_num, 0, star_count + 1, bullet}]

      {:list_bullet, col} ->
        [{:conceal_replace, line_num, col, col + 1, config.list_bullet}]

      :other ->
        []
    end
  end

  @spec classify_line(String.t()) ::
          {:heading, pos_integer(), pos_integer()} | {:list_bullet, non_neg_integer()} | :other
  defp classify_line(line) do
    case Regex.run(~r/^(\*+) /, line) do
      [_match, stars] ->
        {:heading, String.length(stars), String.length(stars)}

      nil ->
        case Regex.run(~r/^(\s*)([-+]) /, line) do
          [_match, indent, _bullet] ->
            {:list_bullet, String.length(indent)}

          nil ->
            :other
        end
    end
  end
end
