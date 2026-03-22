defmodule MingaOrg.Link do
  @moduledoc """
  Org link parser and follow dispatcher.

  Parses org-style links within a line of text and provides link-follow
  logic that dispatches to the appropriate handler based on link type.

  ## Link syntax

  - `[[url][description]]` — link with description
  - `[[url]]` — link without description (URL is displayed)
  - `[[*Heading Name]]` — internal link to heading
  - `[[file:path]]` — link to file

  All public functions are pure (text in, data out) except `follow/2`
  which performs system actions.
  """

  defmodule Parsed do
    @moduledoc "A parsed org link with codepoint positions."

    @enforce_keys [:url, :description, :start, :end_, :link_type]
    defstruct [:url, :description, :start, :end_, :link_type, :display_text]

    @type link_type :: :external | :heading | :file | :internal

    @type t :: %__MODULE__{
            url: String.t(),
            description: String.t() | nil,
            start: non_neg_integer(),
            end_: non_neg_integer(),
            link_type: link_type(),
            display_text: String.t()
          }
  end

  @type parsed :: Parsed.t()

  @doc """
  Parses all org links in a line of text.

  Returns a list of `Parsed` structs sorted by start position.
  Positions are codepoint offsets.

  ## Examples

      iex> MingaOrg.Link.parse("See [[https://example.com][Example]] for details")
      [%MingaOrg.Link.Parsed{url: "https://example.com", description: "Example", ...}]

      iex> MingaOrg.Link.parse("No links here")
      []
  """
  @spec parse(String.t()) :: [parsed()]
  def parse(line) when is_binary(line) do
    graphemes = String.graphemes(line)

    parse_links(graphemes, 0, [])
    |> Enum.reverse()
  end

  @doc """
  Finds the link at the given codepoint column, if any.

  Returns `{:ok, parsed}` or `:none`.
  """
  @spec link_at(String.t(), non_neg_integer()) :: {:ok, parsed()} | :none
  def link_at(line, col) do
    links = parse(line)

    case Enum.find(links, fn link -> col >= link.start and col < link.end_ end) do
      nil -> :none
      link -> {:ok, link}
    end
  end

  @doc """
  Determines the follow action for a parsed link.

  Returns `{:browser, url}`, `{:file, path}`, `{:heading, name}`,
  or `{:internal, target}`.
  """
  @spec follow_action(parsed()) ::
          {:browser, String.t()}
          | {:file, String.t()}
          | {:heading, String.t()}
          | {:internal, String.t()}
  def follow_action(%Parsed{link_type: :external, url: url}), do: {:browser, url}
  def follow_action(%Parsed{link_type: :file, url: "file:" <> path}), do: {:file, path}
  def follow_action(%Parsed{link_type: :heading, url: "*" <> name}), do: {:heading, name}
  def follow_action(%Parsed{link_type: :internal, url: url}), do: {:internal, url}

  @doc """
  Classifies a URL string into a link type.
  """
  @spec classify_url(String.t()) :: Parsed.link_type()
  def classify_url("http://" <> _), do: :external
  def classify_url("https://" <> _), do: :external
  def classify_url("file:" <> _), do: :file
  def classify_url("*" <> _), do: :heading
  def classify_url(_), do: :internal

  # ── Private: parser ────────────────────────────────────────────────────────

  @spec parse_links([String.t()], non_neg_integer(), [parsed()]) :: [parsed()]
  defp parse_links([], _pos, acc), do: acc

  defp parse_links(["[", "[" | rest], pos, acc) do
    case find_link_end(rest, pos + 2, [], nil) do
      {:ok, url, desc, end_pos, remaining} ->
        link_type = classify_url(url)
        display = desc || url

        parsed = %Parsed{
          url: url,
          description: desc,
          start: pos,
          end_: end_pos,
          link_type: link_type,
          display_text: display
        }

        parse_links(remaining, end_pos, [parsed | acc])

      :not_found ->
        parse_links(rest, pos + 2, acc)
    end
  end

  defp parse_links([_ | rest], pos, acc) do
    parse_links(rest, pos + 1, acc)
  end

  # Parse the inside of [[ ... ]], looking for ][desc]] or just ]]
  @spec find_link_end([String.t()], non_neg_integer(), [String.t()], String.t() | nil) ::
          {:ok, String.t(), String.t() | nil, non_neg_integer(), [String.t()]} | :not_found
  defp find_link_end([], _pos, _url_acc, _desc), do: :not_found

  # Found ][  — start of description
  defp find_link_end(["]", "[" | rest], pos, url_acc, nil) do
    url = url_acc |> Enum.reverse() |> Enum.join()
    find_description_end(rest, pos + 2, url, [])
  end

  # Found ]] — end of link (no description)
  defp find_link_end(["]", "]" | rest], pos, url_acc, nil) do
    url = url_acc |> Enum.reverse() |> Enum.join()
    {:ok, url, nil, pos + 2, rest}
  end

  defp find_link_end([g | rest], pos, url_acc, desc) do
    find_link_end(rest, pos + 1, [g | url_acc], desc)
  end

  # Parse the description part after ][, looking for ]]
  @spec find_description_end([String.t()], non_neg_integer(), String.t(), [String.t()]) ::
          {:ok, String.t(), String.t(), non_neg_integer(), [String.t()]} | :not_found
  defp find_description_end([], _pos, _url, _desc_acc), do: :not_found

  defp find_description_end(["]", "]" | rest], pos, url, desc_acc) do
    desc = desc_acc |> Enum.reverse() |> Enum.join()
    {:ok, url, desc, pos + 2, rest}
  end

  defp find_description_end([g | rest], pos, url, desc_acc) do
    find_description_end(rest, pos + 1, url, [g | desc_acc])
  end
end
