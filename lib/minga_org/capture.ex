defmodule MingaOrg.Capture do
  @moduledoc """
  Quick-capture for org-mode notes.

  Capture lets you jot down a thought from anywhere in the editor and
  have it land in the right org file under the right heading. Inspired
  by Doom Emacs `SPC X` and Emacs's `org-capture`.

  ## Templates

  Capture templates define the structure of captured content:

      %{
        key: "t",
        name: "TODO",
        target: "~/org/inbox.org",
        heading: "Tasks",
        template: "* TODO %{title}"
      }

  The `%{title}` placeholder is replaced with user input. Templates
  are configurable via the extension config.

  ## Capture flow

  1. User triggers capture (SPC X)
  2. Template selection (if multiple templates)
  3. User enters title/content
  4. Content is appended to the target file under the specified heading
  5. User returns to their previous buffer

  This module provides the pure logic for template rendering and
  content insertion. The UI flow (capture buffer, prompts) requires
  Minga's input/picker APIs.
  """

  defmodule Template do
    @moduledoc "A capture template definition."

    @enforce_keys [:key, :name, :target, :template]
    defstruct [:key, :name, :target, :template, heading: nil]

    @type t :: %__MODULE__{
            key: String.t(),
            name: String.t(),
            target: String.t(),
            template: String.t(),
            heading: String.t() | nil
          }
  end

  @type template :: Template.t()

  @doc """
  Returns the default capture templates.
  """
  @spec default_templates() :: [template()]
  def default_templates do
    [
      %Template{
        key: "t",
        name: "TODO",
        target: "~/org/inbox.org",
        template: "* TODO %{title}"
      },
      %Template{
        key: "n",
        name: "Note",
        target: "~/org/inbox.org",
        template: "* %{title}\n%{body}"
      },
      %Template{
        key: "j",
        name: "Journal",
        target: "~/org/journal.org",
        heading: "Entries",
        template: "* %{date} %{title}\n%{body}"
      }
    ]
  end

  @doc """
  Renders a capture template with the given bindings.

  ## Examples

      iex> template = %MingaOrg.Capture.Template{key: "t", name: "TODO", target: "~/org/inbox.org", template: "* TODO %{title}"}
      iex> MingaOrg.Capture.render(template, %{title: "Buy milk"})
      "* TODO Buy milk"
  """
  @spec render(template(), map()) :: String.t()
  def render(%Template{template: tmpl}, bindings) do
    # Add date binding if not provided
    bindings = Map.put_new(bindings, :date, Date.utc_today() |> Date.to_iso8601())
    bindings = Map.put_new(bindings, :body, "")
    bindings = Map.put_new(bindings, :title, "")

    Enum.reduce(bindings, tmpl, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", value)
    end)
    |> String.trim_trailing("\n%{body}")
    |> String.trim_trailing()
  end

  @doc """
  Inserts captured content into a file's text.

  If `heading` is specified, appends under that heading (after its
  last child). If no heading, appends at the end of the file.

  Returns the updated file content.
  """
  @spec insert_into(String.t(), String.t(), String.t() | nil) :: String.t()
  def insert_into(file_content, captured_text, nil) do
    # Append at end of file
    content = String.trim_trailing(file_content)

    if content == "" do
      captured_text <> "\n"
    else
      content <> "\n\n" <> captured_text <> "\n"
    end
  end

  def insert_into(file_content, captured_text, heading) do
    lines = String.split(file_content, "\n")

    case find_heading_and_end(lines, heading) do
      {:ok, insert_idx} ->
        {before, after_} = Enum.split(lines, insert_idx)
        new_lines = before ++ [captured_text] ++ after_
        Enum.join(new_lines, "\n")

      :not_found ->
        # Heading not found; append at end
        insert_into(file_content, captured_text, nil)
    end
  end

  @doc """
  Expands `~` in a file path to the user's home directory.
  """
  @spec expand_path(String.t()) :: String.t()
  def expand_path("~/" <> rest) do
    Path.join(System.user_home!(), rest)
  end

  def expand_path(path), do: path

  # ── Private ────────────────────────────────────────────────────────────────

  @spec find_heading_and_end([String.t()], String.t()) ::
          {:ok, non_neg_integer()} | :not_found
  defp find_heading_and_end(lines, target_heading) do
    target_down = String.downcase(target_heading)

    case find_heading_index(lines, target_down, 0) do
      {:ok, heading_idx, heading_level} ->
        # Find where this heading's content ends (next same-or-higher level heading)
        end_idx = find_section_end(lines, heading_idx + 1, heading_level)
        {:ok, end_idx}

      :not_found ->
        :not_found
    end
  end

  @spec find_heading_index([String.t()], String.t(), non_neg_integer()) ::
          {:ok, non_neg_integer(), pos_integer()} | :not_found
  defp find_heading_index([], _target, _idx), do: :not_found

  defp find_heading_index([line | rest], target, idx) do
    case Regex.run(~r/^(\*+) (.+)$/, line) do
      [_match, stars, title] ->
        if String.downcase(String.trim(title)) == target do
          {:ok, idx, String.length(stars)}
        else
          find_heading_index(rest, target, idx + 1)
        end

      nil ->
        find_heading_index(rest, target, idx + 1)
    end
  end

  @spec find_section_end([String.t()], non_neg_integer(), pos_integer()) :: non_neg_integer()
  defp find_section_end(lines, from, level) do
    lines
    |> Enum.drop(from)
    |> Enum.with_index(from)
    |> Enum.find(fn {line, _idx} ->
      case Regex.run(~r/^(\*+) /, line) do
        [_match, stars] -> String.length(stars) <= level
        nil -> false
      end
    end)
    |> case do
      {_line, idx} -> idx
      nil -> length(lines)
    end
  end
end
