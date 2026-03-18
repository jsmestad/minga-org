defmodule MingaOrg.List do
  @moduledoc """
  Smart list continuation for org-mode.

  Parses the current line to detect list context (unordered, ordered,
  checkbox) and generates the appropriate continuation prefix for a
  new line. Handles empty-bullet detection for exiting list context.

  All public functions are pure (text in, text out) so they can be
  tested without a running editor.
  """

  @typedoc """
  Parsed list item prefix.

  - `:unordered` — bullet is `-`, `+`, or `*`
  - `:ordered_dot` — bullet is `N.`
  - `:ordered_paren` — bullet is `N)`
  """
  @type bullet_style :: :unordered | :ordered_dot | :ordered_paren

  @typedoc "Result of parsing a list line."
  @type parse_result ::
          {:list_item,
           %{indent: String.t(), bullet: String.t(), style: bullet_style(), content: String.t()}}
          | :not_a_list_item

  @typedoc "Action the editor should take after Enter on a list line."
  @type continuation_action ::
          {:continue, String.t()}
          | :exit_list
          | :passthrough

  # ── Parsing ────────────────────────────────────────────────────────────────

  # Matches: optional indent, bullet (unordered or ordered), space, rest
  # Unordered: -, +, * followed by space
  # Ordered: digits followed by . or ) then space
  @list_regex ~r/^(\s*)([-+*]|\d+[.)]) (.*)$/

  @doc """
  Parses a line to extract list item structure.

  Returns `{:list_item, map}` with indent, bullet, style, and content,
  or `:not_a_list_item`.

  ## Examples

      iex> MingaOrg.List.parse_line("- Buy milk")
      {:list_item, %{indent: "", bullet: "-", style: :unordered, content: "Buy milk"}}

      iex> MingaOrg.List.parse_line("  1. First item")
      {:list_item, %{indent: "  ", bullet: "1.", style: :ordered_dot, content: "First item"}}

      iex> MingaOrg.List.parse_line("Not a list")
      :not_a_list_item
  """
  @spec parse_line(String.t()) :: parse_result()
  def parse_line(line) do
    case Regex.run(@list_regex, line) do
      [_match, indent, "*", _content] when indent == "" ->
        # * at column 0 is a heading, not a list bullet
        :not_a_list_item

      [_match, indent, bullet, content] ->
        {:list_item,
         %{
           indent: indent,
           bullet: bullet,
           style: classify_bullet(bullet),
           content: content
         }}

      nil ->
        :not_a_list_item
    end
  end

  @doc """
  Determines what action to take when Enter is pressed on a list line.

  - If the line is a list item with content, returns `{:continue, prefix}`
    where prefix is the text to insert (newline + indent + next bullet + space).
  - If the line is a list item with no content (empty bullet), returns
    `:exit_list` indicating the bullet should be removed and list context exited.
  - If the line is not a list item, returns `:passthrough` to use default
    newline behavior.

  ## Examples

      iex> MingaOrg.List.continuation_action("- Buy milk")
      {:continue, "- "}

      iex> MingaOrg.List.continuation_action("  3. Third")
      {:continue, "  4. "}

      iex> MingaOrg.List.continuation_action("- ")
      :exit_list

      iex> MingaOrg.List.continuation_action("Not a list")
      :passthrough
  """
  @spec continuation_action(String.t()) :: continuation_action()
  def continuation_action(line) do
    case parse_line(line) do
      {:list_item, %{content: content} = parsed} ->
        if empty_list_content?(content) do
          :exit_list
        else
          {:continue, build_continuation_prefix(parsed)}
        end

      :not_a_list_item ->
        :passthrough
    end
  end

  @doc """
  Builds the text prefix for continuing a list on the next line.

  For unordered lists, reuses the same bullet. For ordered lists,
  increments the number.

  ## Examples

      iex> MingaOrg.List.build_continuation_prefix(%{indent: "", bullet: "-", style: :unordered, content: "item"})
      "- "

      iex> MingaOrg.List.build_continuation_prefix(%{indent: "  ", bullet: "3.", style: :ordered_dot, content: "item"})
      "  4. "
  """
  @spec build_continuation_prefix(%{
          indent: String.t(),
          bullet: String.t(),
          style: bullet_style(),
          content: String.t()
        }) ::
          String.t()
  def build_continuation_prefix(%{indent: indent, bullet: bullet, style: style, content: content}) do
    next_bullet = next_bullet(bullet, style)
    checkbox_prefix = if checkbox_line?(content), do: "[ ] ", else: ""
    "#{indent}#{next_bullet} #{checkbox_prefix}"
  end

  @doc """
  Returns the text that should replace the current line when exiting
  a list (Enter on an empty bullet). Returns just the indentation
  (or empty string for a top-level list).
  """
  @spec exit_list_replacement(String.t()) :: String.t()
  def exit_list_replacement(line) do
    case parse_line(line) do
      {:list_item, %{indent: indent}} -> indent
      :not_a_list_item -> line
    end
  end

  # ── Private ────────────────────────────────────────────────────────────────

  @spec checkbox_line?(String.t()) :: boolean()
  defp checkbox_line?(content) do
    String.match?(content, ~r/^\[[ xX\-]\] /)
  end

  # Content is "empty" if it's blank or just a checkbox with no text after it.
  @spec empty_list_content?(String.t()) :: boolean()
  defp empty_list_content?(""), do: true

  defp empty_list_content?(content) do
    String.match?(content, ~r/^\[[ xX\-]\]\s*$/)
  end

  @spec classify_bullet(String.t()) :: bullet_style()
  defp classify_bullet(bullet) when bullet in ["-", "+", "*"], do: :unordered

  defp classify_bullet(bullet) do
    if String.ends_with?(bullet, "."), do: :ordered_dot, else: :ordered_paren
  end

  @spec next_bullet(String.t(), bullet_style()) :: String.t()
  defp next_bullet(bullet, :unordered), do: bullet

  defp next_bullet(bullet, :ordered_dot) do
    num = bullet |> String.trim_trailing(".") |> String.to_integer()
    "#{num + 1}."
  end

  defp next_bullet(bullet, :ordered_paren) do
    num = bullet |> String.trim_trailing(")") |> String.to_integer()
    "#{num + 1})"
  end
end
