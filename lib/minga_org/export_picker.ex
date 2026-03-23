defmodule MingaOrg.ExportPicker do
  @moduledoc """
  Picker source for org export format selection.

  Lists all pandoc output formats and triggers export on selection.
  Opened via `SPC m e`.
  """

  @behaviour Minga.Picker.Source

  alias MingaOrg.Export

  @impl true
  @spec title() :: String.t()
  def title, do: "Export org file"

  @impl true
  @spec candidates(term()) :: [Minga.Picker.Item.t()]
  def candidates(_context) do
    Enum.map(Export.formats(), fn {format_id, display_name} ->
      %Minga.Picker.Item{id: format_id, label: display_name, description: format_id}
    end)
  end

  @impl true
  @spec on_select(Minga.Picker.Item.t(), map()) :: map()
  def on_select(%{id: format}, state) do
    Export.export_command(state, format)
  end

  @impl true
  @spec on_cancel(map()) :: map()
  def on_cancel(state), do: state

  @doc "Opens the export picker. MFA target for the `command/3` DSL macro."
  @spec open(map()) :: map()
  def open(state), do: Minga.Editor.PickerUI.open(state, __MODULE__)
end
