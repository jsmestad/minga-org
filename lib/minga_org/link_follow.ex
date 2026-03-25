defmodule MingaOrg.LinkFollow do
  @moduledoc """
  Follows org links at the cursor position.

  Dispatches to the appropriate handler based on link type:
  - External URLs → system browser
  - File links → open in Minga
  - Heading links → jump to heading in current buffer
  """

  alias MingaOrg.Buffer
  alias MingaOrg.Link

  @doc """
  Follows the link under the cursor.

  Returns the editor state unchanged (the side effect is opening a
  browser or navigating). This is a state -> state command function.
  """
  @spec follow(map()) :: map()
  def follow(state) do
    buf = state.workspace.buffers.active
    {line_num, col} = Buffer.cursor(buf)

    case Buffer.line_at(buf, line_num) do
      {:ok, text} ->
        case Link.link_at(text, col) do
          {:ok, link} -> execute_follow(state, buf, link)
          :none -> state
        end

      _ ->
        state
    end
  end

  # ── Private ────────────────────────────────────────────────────────────────

  @spec execute_follow(map(), pid(), Link.parsed()) :: map()
  defp execute_follow(state, buf, link) do
    case Link.follow_action(link) do
      {:browser, url} ->
        open_in_browser(url)
        state

      {:file, path} ->
        open_file(state, path)

      {:heading, name} ->
        jump_to_heading(state, buf, name)

      {:internal, _target} ->
        # Internal links not yet supported
        state
    end
  end

  @spec open_in_browser(String.t()) :: :ok
  defp open_in_browser(url) do
    cmd =
      case :os.type() do
        {:unix, :darwin} -> "open"
        {:unix, _} -> "xdg-open"
        {:win32, _} -> "start"
      end

    # Fire and forget; don't block the editor
    Task.start(fn -> System.cmd(cmd, [url], stderr_to_stdout: true) end)
    :ok
  end

  @spec open_file(map(), String.t()) :: map()
  defp open_file(state, path) do
    # Delegate to Minga's file opening command
    Minga.Editor.open_file(state, path)
  rescue
    # If the API doesn't exist or fails, return state unchanged
    _ -> state
  end

  @spec jump_to_heading(map(), pid(), String.t()) :: map()
  defp jump_to_heading(state, buf, name) do
    total = Buffer.line_count(buf)
    target = String.downcase(name)

    case find_heading_line(buf, 0, total, target) do
      {:ok, line} ->
        Buffer.move_to(buf, {line, 0})
        state

      :not_found ->
        state
    end
  end

  @spec find_heading_line(pid(), non_neg_integer(), non_neg_integer(), String.t()) ::
          {:ok, non_neg_integer()} | :not_found
  defp find_heading_line(_buf, line, total, _target) when line >= total, do: :not_found

  defp find_heading_line(buf, line, total, target) do
    with {:ok, text} <- Buffer.line_at(buf, line),
         {:ok, heading_text} <- extract_heading_text(text),
         true <- String.downcase(heading_text) == target do
      {:ok, line}
    else
      _ -> find_heading_line(buf, line + 1, total, target)
    end
  end

  @spec extract_heading_text(String.t()) :: {:ok, String.t()} | :not_heading
  defp extract_heading_text(text) do
    case Regex.run(~r/^\*+ (.+)$/, text) do
      [_match, heading] -> {:ok, String.trim(heading)}
      nil -> :not_heading
    end
  end
end
