defmodule MingaOrg.Tags do
  @moduledoc """
  Heading tag parsing and management for org-mode.

  Org headings can have tags at the end of the line:

      * My Heading                                           :work:urgent:

  This module provides pure functions for:
  - Parsing tags from heading lines
  - Adding/removing tags
  - Collecting all tags used in a buffer
  - Checking tag inheritance

  tree-sitter-org parses `tag_list` and `tag` nodes natively, so
  syntax highlighting comes from the query file. This module handles
  the editing and filtering operations.
  """

  @tag_regex ~r/:([a-zA-Z0-9_@#%]+(?::[a-zA-Z0-9_@#%]+)*):$/

  @typedoc "A parsed heading with tag information."
  @type heading_info :: %{
          stars: String.t(),
          title: String.t(),
          tags: [String.t()],
          raw_tags: String.t() | nil
        }

  @doc """
  Parses a heading line to extract the title and tags.

  ## Examples

      iex> MingaOrg.Tags.parse_heading("* My Heading :work:urgent:")
      %{stars: "*", title: "My Heading", tags: ["work", "urgent"], raw_tags: ":work:urgent:"}

      iex> MingaOrg.Tags.parse_heading("** No tags here")
      %{stars: "**", title: "No tags here", tags: [], raw_tags: nil}
  """
  @spec parse_heading(String.t()) :: heading_info() | :not_heading
  def parse_heading(line) do
    case Regex.run(~r/^(\*+) (.+)$/, line) do
      [_match, stars, rest] ->
        {title, tags, raw_tags} = extract_tags(String.trim(rest))
        %{stars: stars, title: title, tags: tags, raw_tags: raw_tags}

      nil ->
        :not_heading
    end
  end

  @doc """
  Adds a tag to a heading line. Returns the updated line.

  If the heading already has tags, appends to the tag list.
  If no tags exist, adds the tag list at the end.

  ## Examples

      iex> MingaOrg.Tags.add_tag("* Heading", "work")
      "* Heading :work:"

      iex> MingaOrg.Tags.add_tag("* Heading :work:", "urgent")
      "* Heading :work:urgent:"
  """
  @spec add_tag(String.t(), String.t()) :: String.t()
  def add_tag(line, tag) do
    case parse_heading(line) do
      :not_heading ->
        line

      %{stars: stars, title: title, tags: tags} ->
        if tag in tags do
          line
        else
          new_tags = tags ++ [tag]
          format_heading(stars, title, new_tags)
        end
    end
  end

  @doc """
  Removes a tag from a heading line. Returns the updated line.

  ## Examples

      iex> MingaOrg.Tags.remove_tag("* Heading :work:urgent:", "work")
      "* Heading :urgent:"
  """
  @spec remove_tag(String.t(), String.t()) :: String.t()
  def remove_tag(line, tag) do
    case parse_heading(line) do
      :not_heading ->
        line

      %{stars: stars, title: title, tags: tags} ->
        new_tags = Enum.reject(tags, &(&1 == tag))
        format_heading(stars, title, new_tags)
    end
  end

  @doc """
  Toggles a tag on a heading line.

  Adds the tag if absent, removes it if present.
  """
  @spec toggle_tag(String.t(), String.t()) :: String.t()
  def toggle_tag(line, tag) do
    case parse_heading(line) do
      :not_heading ->
        line

      %{tags: tags} ->
        if tag in tags do
          remove_tag(line, tag)
        else
          add_tag(line, tag)
        end
    end
  end

  @doc """
  Collects all unique tags from a list of lines.

  Returns a sorted list of tag strings.
  """
  @spec collect_all_tags([String.t()]) :: [String.t()]
  def collect_all_tags(lines) do
    lines
    |> Enum.flat_map(fn line ->
      case parse_heading(line) do
        %{tags: tags} -> tags
        :not_heading -> []
      end
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Formats a heading line with the given tags.
  """
  @spec format_heading(String.t(), String.t(), [String.t()]) :: String.t()
  def format_heading(stars, title, []) do
    "#{stars} #{title}"
  end

  def format_heading(stars, title, tags) do
    tag_str = ":" <> Enum.join(tags, ":") <> ":"
    "#{stars} #{title} #{tag_str}"
  end

  # ── Private ────────────────────────────────────────────────────────────────

  @spec extract_tags(String.t()) :: {String.t(), [String.t()], String.t() | nil}
  defp extract_tags(rest) do
    case Regex.run(@tag_regex, rest) do
      [raw_tags, _] ->
        title = rest |> String.replace(raw_tags, "") |> String.trim_trailing()

        tags =
          raw_tags
          |> String.trim_leading(":")
          |> String.trim_trailing(":")
          |> String.split(":")

        {title, tags, raw_tags}

      nil ->
        {rest, [], nil}
    end
  end
end
