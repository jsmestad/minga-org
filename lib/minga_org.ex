defmodule MingaOrg do
  @moduledoc """
  Org-mode support for the Minga editor.

  Provides syntax highlighting, heading folding, TODO cycling, checkbox
  toggling, and org-specific keybindings. Install via your Minga config:

      extension :minga_org, git: "https://github.com/jsmestad/minga-org",
        conceal: true,
        pretty_bullets: true,
        heading_bullets: ["◉", "○", "◈", "◇"],
        todo_keywords: ["TODO", "DONE"]

  All keybindings are scoped to `SPC m` and only active when editing
  `.org` files.
  """

  use Minga.Extension

  option :conceal, :boolean,
    default: true,
    description: "Hide markup delimiters and show styled content"

  option :pretty_bullets, :boolean,
    default: true,
    description: "Replace heading stars with Unicode bullets"

  option :heading_bullets, :string_list,
    default: ["◉", "○", "◈", "◇"],
    description: "Unicode bullets for heading levels (cycles when depth exceeds list length)"

  option :list_bullet, :string,
    default: "•",
    description: "Replacement character for list item bullets"

  option :todo_keywords, :string_list,
    default: ["TODO", "DONE"],
    description: "TODO keyword cycle sequence"

  option :capture_templates, :any,
    default: nil,
    description: "Capture template definitions (nil uses built-in defaults)"

  @impl true
  @spec name() :: :minga_org
  def name, do: :minga_org

  @impl true
  @spec description() :: String.t()
  def description, do: "Org-mode support: syntax highlighting, headings, TODOs, checkboxes"

  @impl true
  @spec version() :: String.t()
  def version, do: "0.1.0"

  @impl true
  @spec init(keyword()) :: {:ok, map()} | {:error, term()}
  def init(config) do
    todo_keywords = Keyword.get(config, :todo_keywords, ["TODO", "DONE"])

    MingaOrg.Grammar.register()
    MingaOrg.Keybindings.register()
    MingaOrg.Commands.register(todo_keywords)
    MingaOrg.Advice.register()

    {:ok, %{todo_keywords: todo_keywords}}
  end
end
