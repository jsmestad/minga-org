defmodule MingaOrg.TagPicker do
  @moduledoc """
  Picker source for filtering headings by tag.

  Lists all unique tags in the current org buffer. Selecting a tag
  jumps the cursor to the first heading that contains it.
  Opened via `SPC m T`.
  """

  @behaviour Minga.UI.Picker.Source

  alias MingaOrg.Buffer
  alias MingaOrg.TagCommands
  alias MingaOrg.Tags

  @impl true
  @spec title() :: String.t()
  def title, do: "Jump to tag"

  @impl true
  @spec candidates(term()) :: [Minga.UI.Picker.Item.t()]
  def candidates(%{buffers: %{active: buf}}) do
    TagCommands.all_tags_in_buffer(buf)
    |> Enum.map(fn tag ->
      %Minga.UI.Picker.Item{id: tag, label: ":#{tag}:"}
    end)
  end

  def candidates(_), do: []

  @impl true
  @spec on_select(Minga.UI.Picker.Item.t(), map()) :: map()
  def on_select(%{id: tag}, state) do
    buf = state.buffers.active
    total = Buffer.line_count(buf)

    case find_tagged_heading(buf, tag, 0, total) do
      {:ok, line} ->
        Buffer.move_to(buf, {line, 0})
        state

      :not_found ->
        state
    end
  end

  @impl true
  @spec on_cancel(map()) :: map()
  def on_cancel(state), do: state

  # ── Private ────────────────────────────────────────────────────────────────

  @spec find_tagged_heading(pid(), String.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, non_neg_integer()} | :not_found
  defp find_tagged_heading(_buf, _tag, line, total) when line >= total, do: :not_found

  defp find_tagged_heading(buf, tag, line, total) do
    with {:ok, text} <- Buffer.line_at(buf, line),
         %{tags: tags} <- Tags.parse_heading(text),
         true <- tag in tags do
      {:ok, line}
    else
      _ -> find_tagged_heading(buf, tag, line + 1, total)
    end
  end

  @doc "Opens the tag picker. MFA target for the `command/3` DSL macro."
  @spec open(map()) :: map()
  def open(state), do: Minga.Editor.PickerUI.open(state, __MODULE__)
end
