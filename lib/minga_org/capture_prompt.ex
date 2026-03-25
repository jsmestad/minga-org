defmodule MingaOrg.CapturePrompt do
  @moduledoc """
  Prompt handler for capture title input.

  Receives the selected template via `state.prompt_ui.context.template`,
  renders the template with the user's input, and writes the result
  to the target file.
  """

  @behaviour Minga.UI.Prompt.Handler

  alias MingaOrg.Capture

  @impl true
  @spec label() :: String.t()
  def label, do: "Title: "

  @impl true
  @spec on_submit(String.t(), map()) :: map()
  def on_submit(title, state) do
    template = state.prompt_ui.context.template
    rendered = Capture.render(template, %{title: title})
    target_path = Capture.expand_path(template.target)

    write_capture(target_path, rendered, template.heading)

    state
  end

  @impl true
  @spec on_cancel(map()) :: map()
  def on_cancel(state), do: state

  # ── Private ────────────────────────────────────────────────────────────────

  @spec write_capture(String.t(), String.t(), String.t() | nil) :: :ok | {:error, term()}
  defp write_capture(path, content, heading) do
    dir = Path.dirname(path)
    File.mkdir_p!(dir)

    existing = read_or_empty(path)
    updated = Capture.insert_into(existing, content, heading)
    File.write(path, updated)
  end

  @spec read_or_empty(String.t()) :: String.t()
  defp read_or_empty(path) do
    case File.read(path) do
      {:ok, content} -> content
      {:error, :enoent} -> ""
    end
  end
end
