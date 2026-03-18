defmodule MingaOrg.Inline do
  @moduledoc """
  Inline markup parser for org-mode.

  Parses org inline markup within a single line of text. Org-mode
  supports five markup types, each delimited by a specific character:

  | Delimiter | Type          | Style        |
  |-----------|---------------|--------------|
  | `*`       | bold          | bold         |
  | `/`       | italic        | italic       |
  | `~`       | code          | code bg      |
  | `=`       | verbatim      | distinct fg  |
  | `+`       | strikethrough | strikethrough|

  ## Org spec rules

  - Markup only applies within a single line (no multi-line spans)
  - Nested markup is not supported (`*/bold italic/*` is not valid)
  - Opening delimiter must be preceded by whitespace, start of line,
    or one of `-('{"`
  - Closing delimiter must be followed by whitespace, end of line,
    or one of `-.,:!?;')}"]`
  - Content between delimiters must be non-empty

  All public functions are pure (text in, spans out).
  Positions are codepoint offsets (not byte offsets) matching Minga's
  buffer column convention.
  """

  @typedoc "Markup type."
  @type markup_type :: :bold | :italic | :code | :verbatim | :strikethrough

  defmodule Span do
    @moduledoc "A parsed inline markup span with codepoint positions."

    @enforce_keys [:type, :start, :end_, :content_start, :content_end, :content]
    defstruct [:type, :start, :end_, :content_start, :content_end, :content]

    @type t :: %__MODULE__{
            type: MingaOrg.Inline.markup_type(),
            start: non_neg_integer(),
            end_: non_neg_integer(),
            content_start: non_neg_integer(),
            content_end: non_neg_integer(),
            content: String.t()
          }
  end

  @type span :: Span.t()

  @delimiter_types %{
    "*" => :bold,
    "/" => :italic,
    "~" => :code,
    "=" => :verbatim,
    "+" => :strikethrough
  }

  @delimiters Map.keys(@delimiter_types)

  # Characters that can precede an opening delimiter
  @pre_set MapSet.new([" ", "\t", "\n", "-", "(", "'", "\"", "{"])
  # Characters that can follow a closing delimiter
  @post_set MapSet.new([
              " ",
              "\t",
              "\n",
              "-",
              ".",
              ",",
              ":",
              "!",
              "?",
              ";",
              "'",
              "\"",
              ")",
              "}",
              "]"
            ])

  @doc """
  Parses all inline markup spans in a line of text.

  Returns a list of `Span` structs sorted by start position.
  All positions are codepoint offsets (matching Minga's column convention).
  Spans do not overlap (first match wins at each position).

  ## Examples

      iex> MingaOrg.Inline.parse("This is *bold* and /italic/ text")
      [
        %MingaOrg.Inline.Span{type: :bold, start: 8, end_: 14, content_start: 9, content_end: 13, content: "bold"},
        %MingaOrg.Inline.Span{type: :italic, start: 19, end_: 27, content_start: 20, content_end: 26, content: "italic"}
      ]

      iex> MingaOrg.Inline.parse("No markup here")
      []
  """
  @spec parse(String.t()) :: [span()]
  def parse(line) when is_binary(line) do
    graphemes = String.graphemes(line)

    parse_graphemes(graphemes, 0, nil, [])
    |> Enum.reverse()
  end

  @doc """
  Returns the style attributes for a given markup type.

  These map to Minga's highlight range style options.
  """
  @spec style_for(markup_type()) :: keyword()
  def style_for(:bold), do: [bold: true]
  def style_for(:italic), do: [italic: true]
  def style_for(:code), do: [bg: 0x3B3B3B]
  def style_for(:verbatim), do: [fg: 0x98C379]
  def style_for(:strikethrough), do: [strikethrough: true]

  # ── Private: parser ────────────────────────────────────────────────────────

  # Walk graphemes one at a time, tracking position (codepoint index).
  # `prev` is the previous grapheme (nil at start of line).
  @spec parse_graphemes([String.t()], non_neg_integer(), String.t() | nil, [span()]) :: [span()]
  defp parse_graphemes([], _pos, _prev, acc), do: acc

  defp parse_graphemes([g | rest], pos, prev, acc) do
    if g in @delimiters and valid_pre_grapheme?(prev) do
      case find_closing_grapheme(rest, g, pos + 1) do
        {:ok, close_pos, content_graphemes, remaining} ->
          content = Enum.join(content_graphemes)

          span = %Span{
            type: Map.fetch!(@delimiter_types, g),
            start: pos,
            end_: close_pos + 1,
            content_start: pos + 1,
            content_end: close_pos,
            content: content
          }

          # Continue parsing after the closing delimiter
          next_prev = g
          parse_after_close(remaining, close_pos + 1, next_prev, [span | acc])

        :not_found ->
          parse_graphemes(rest, pos + 1, g, acc)
      end
    else
      parse_graphemes(rest, pos + 1, g, acc)
    end
  end

  # After finding a closing delimiter, continue with the remaining graphemes.
  # The character right after the close is already validated as post-context.
  @spec parse_after_close([String.t()], non_neg_integer(), String.t(), [span()]) :: [span()]
  defp parse_after_close(remaining, pos, prev, acc) do
    parse_graphemes(remaining, pos, prev, acc)
  end

  # Check pre-context: nil (start of line) or a member of @pre_set.
  @spec valid_pre_grapheme?(String.t() | nil) :: boolean()
  defp valid_pre_grapheme?(nil), do: true
  defp valid_pre_grapheme?(prev), do: MapSet.member?(@pre_set, prev)

  # Search for the closing delimiter in the remaining graphemes.
  # Must have at least 1 grapheme of content between open and close.
  # Returns {:ok, close_pos, content_graphemes, remaining_after_close} or :not_found.
  @spec find_closing_grapheme([String.t()], String.t(), non_neg_integer()) ::
          {:ok, non_neg_integer(), [String.t()], [String.t()]} | :not_found
  defp find_closing_grapheme(graphemes, delimiter, start_pos) do
    do_find_close(graphemes, delimiter, start_pos, [])
  end

  @spec do_find_close([String.t()], String.t(), non_neg_integer(), [String.t()]) ::
          {:ok, non_neg_integer(), [String.t()], [String.t()]} | :not_found
  defp do_find_close([], _delimiter, _pos, _content), do: :not_found

  defp do_find_close([g | rest], delimiter, pos, content) do
    if g == delimiter and content != [] and valid_post_grapheme?(rest) do
      {:ok, pos, Enum.reverse(content), rest}
    else
      do_find_close(rest, delimiter, pos + 1, [g | content])
    end
  end

  # Check post-context: end of line (empty rest) or next grapheme in @post_set.
  @spec valid_post_grapheme?([String.t()]) :: boolean()
  defp valid_post_grapheme?([]), do: true
  defp valid_post_grapheme?([next | _]), do: MapSet.member?(@post_set, next)
end
