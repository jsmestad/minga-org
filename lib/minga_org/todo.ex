defmodule MingaOrg.Todo do
  @moduledoc """
  Keyword cycling for org-mode headings (TODO/DONE states).

  Cycles the TODO keyword on the current heading line through the
  configured sequence. Default sequence: `TODO` -> `DONE` -> (none).

  ## Examples

  With default keywords `["TODO", "DONE"]`:

      * TODO Buy groceries    ->  * DONE Buy groceries
      * DONE Buy groceries    ->  * Buy groceries
      * Buy groceries         ->  * TODO Buy groceries
  """

  alias MingaOrg.Buffer

  @doc """
  Cycles the TODO keyword on the current heading line.

  Reads `todo_keywords` from the extension's config at call time via
  `Minga.Config.Options.get_extension_option/2`. This is the MFA target
  for the `command/3` DSL macro.
  """
  @spec cycle(map()) :: map()
  def cycle(state) do
    keywords =
      Minga.Config.Options.get_extension_option(:minga_org, :todo_keywords) ||
        ["TODO", "DONE"]

    cycle(state, keywords)
  end

  @doc """
  Cycles the TODO keyword on the current heading line.

  `keywords` is the ordered list of TODO states (e.g., `["TODO", "DONE"]`).
  If the current line is not a heading, returns state unchanged.
  """
  @spec cycle(map(), [String.t()]) :: map()
  def cycle(state, keywords) when is_list(keywords) do
    buf = state.buffers.active
    {line_num, _col} = Buffer.cursor(buf)

    case Buffer.line_at(buf, line_num) do
      {:ok, line_text} ->
        if heading?(line_text) do
          new_line = cycle_keyword(line_text, keywords)
          replace_line(buf, line_num, line_text, new_line)
        end

        state

      _ ->
        state
    end
  end

  @doc """
  Returns true if the line is an org heading (starts with one or more `*`).
  """
  @spec heading?(String.t()) :: boolean()
  def heading?(line) when is_binary(line) do
    String.match?(line, ~r/^\*+ /)
  end

  @doc """
  Cycles the TODO keyword on a heading line string.

  Returns the new line text with the next keyword in the sequence,
  or the keyword removed if it was the last in the sequence.
  """
  @spec cycle_keyword(String.t(), [String.t()]) :: String.t()
  def cycle_keyword(line, keywords) do
    case parse_heading(line) do
      {:ok, stars, current_keyword, rest} ->
        next = next_keyword(current_keyword, keywords)
        build_heading(stars, next, rest)

      :not_heading ->
        line
    end
  end

  @doc """
  Parses an org heading into its components.

  Returns `{:ok, stars, keyword_or_nil, rest_of_text}` or `:not_heading`.
  """
  @spec parse_heading(String.t()) ::
          {:ok, String.t(), String.t() | nil, String.t()} | :not_heading
  def parse_heading(line) do
    case Regex.run(~r/^(\*+) (.*)$/, line) do
      [_match, stars, rest] ->
        {keyword, text} = extract_keyword(rest)
        {:ok, stars, keyword, text}

      nil ->
        :not_heading
    end
  end

  # ── Private ──────────────────────────────────────────────────────────────────

  @spec extract_keyword(String.t()) :: {String.t() | nil, String.t()}
  defp extract_keyword(text) do
    case Regex.run(~r/^([A-Z][A-Z\-]+)\s+(.*)$/, text) do
      [_match, keyword, rest] -> {keyword, rest}
      nil -> {nil, text}
    end
  end

  @spec next_keyword(String.t() | nil, [String.t()]) :: String.t() | nil
  defp next_keyword(nil, [first | _rest]), do: first
  defp next_keyword(_current, []), do: nil

  defp next_keyword(current, keywords) do
    case Enum.find_index(keywords, &(&1 == current)) do
      nil ->
        List.first(keywords)

      idx ->
        next_idx = idx + 1

        if next_idx >= length(keywords) do
          nil
        else
          Enum.at(keywords, next_idx)
        end
    end
  end

  @spec build_heading(String.t(), String.t() | nil, String.t()) :: String.t()
  defp build_heading(stars, nil, rest), do: "#{stars} #{rest}"
  defp build_heading(stars, keyword, rest), do: "#{stars} #{keyword} #{rest}"

  @spec replace_line(pid(), non_neg_integer(), String.t(), String.t()) :: :ok
  defp replace_line(buf, line_num, old_line, new_line) do
    old_len = String.length(old_line)
    Buffer.apply_text_edit(buf, line_num, 0, line_num, old_len, new_line)
  end
end
