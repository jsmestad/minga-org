defmodule MingaOrg.CapturePicker do
  @moduledoc """
  Picker source for capture template selection.

  Lists available capture templates. Selecting one opens a title
  prompt via `MingaOrg.CapturePrompt`.
  Opened via `SPC X`.
  """

  @behaviour Minga.Picker.Source

  alias MingaOrg.Capture

  @impl true
  @spec title() :: String.t()
  def title, do: "Capture template"

  @impl true
  @spec candidates(term()) :: [Minga.Picker.Item.t()]
  def candidates(_context) do
    templates()
    |> Enum.map(fn template ->
      %Minga.Picker.Item{
        id: template,
        label: "[#{template.key}] #{template.name}",
        description: template.target
      }
    end)
  end

  @impl true
  @spec on_select(Minga.Picker.Item.t(), map()) :: map()
  def on_select(%{id: template}, state) do
    Minga.Editor.PromptUI.open(state, MingaOrg.CapturePrompt, context: %{template: template})
  end

  @impl true
  @spec on_cancel(map()) :: map()
  def on_cancel(state), do: state

  # ── Private ────────────────────────────────────────────────────────────────

  @spec templates() :: [Capture.template()]
  defp templates do
    case Minga.Config.Options.get_extension_option(:minga_org, :capture_templates) do
      nil -> Capture.default_templates()
      custom -> custom
    end
  rescue
    # Config.Options not available (test env or standalone compilation)
    _ -> Capture.default_templates()
  end

  @doc "Opens the capture picker. MFA target for the `command/3` DSL macro."
  @spec open(map()) :: map()
  def open(state), do: Minga.Editor.PickerUI.open(state, __MODULE__)
end
