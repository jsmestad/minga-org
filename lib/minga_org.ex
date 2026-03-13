defmodule MingaOrg do
  @moduledoc """
  Org-mode support for the Minga editor.

  Provides syntax highlighting, heading folding, TODO cycling, checkbox
  toggling, and org-specific keybindings. Install via your Minga config:

      extension :minga_org, hex: "minga_org", version: "~> 0.1"
      extension :minga_org, git: "https://github.com/jsmestad/minga-org"

  All keybindings are scoped to `SPC m` and only active when editing
  `.org` files.

  ## Extension Callbacks

  This module implements the `Minga.Extension` behaviour. When compiled
  standalone (for testing or Hex publishing), the behaviour annotation
  is omitted since Minga modules aren't available. When loaded into a
  running Minga editor, Minga validates the callbacks at runtime.
  """

  # Provide the default child_spec that Minga's extension supervisor expects.
  @spec child_spec(keyword()) :: map()
  def child_spec(config) do
    %{
      id: __MODULE__,
      start: {Agent, :start_link, [fn -> config end]},
      restart: :permanent,
      type: :worker
    }
  end

  @spec name() :: :minga_org
  def name, do: :minga_org

  @spec description() :: String.t()
  def description, do: "Org-mode support: syntax highlighting, headings, TODOs, checkboxes"

  @spec version() :: String.t()
  def version, do: "0.1.0"

  @spec init(keyword()) :: {:ok, map()} | {:error, term()}
  def init(config) do
    todo_keywords = Keyword.get(config, :todo_keywords, ["TODO", "DONE"])

    MingaOrg.Grammar.register()
    MingaOrg.Keybindings.register()
    MingaOrg.Commands.register(todo_keywords)

    {:ok, %{todo_keywords: todo_keywords}}
  end
end
