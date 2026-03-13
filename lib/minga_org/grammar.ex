defmodule MingaOrg.Grammar do
  @moduledoc """
  Registers the tree-sitter-org grammar with Minga.

  Compiles the vendored grammar sources into a shared library on first
  load, registers the filetype mapping (`.org` -> `:org`), and sends
  the highlight query to the parser.
  """

  @doc """
  Registers the org grammar, filetype, and highlight query.

  Called during `MingaOrg.init/1`. Safe to call multiple times; the
  compiled shared library is cached.
  """
  @spec register() :: :ok | {:error, String.t()}
  def register do
    source_dir = source_dir()
    highlights = highlights_path()

    Minga.TreeSitter.register_grammar("org", source_dir,
      highlights: highlights,
      filetype_extensions: [".org"],
      filetype_atom: :org
    )
  end

  @doc "Returns the path to the vendored grammar source directory."
  @spec source_dir() :: String.t()
  def source_dir do
    Path.join([extension_root(), "vendor", "tree-sitter-org", "src"])
  end

  @doc "Returns the path to the highlight query file."
  @spec highlights_path() :: String.t()
  def highlights_path do
    Path.join([extension_root(), "queries", "org", "highlights.scm"])
  end

  @spec extension_root() :: String.t()
  defp extension_root do
    # In a Hex package, :code.priv_dir won't have our files.
    # The extension is loaded from its source directory, so we walk
    # up from the compiled beam file to find the project root.
    __DIR__
    |> Path.join("..")
    |> Path.expand()
    |> Path.join("..")
    |> Path.expand()
  end
end
