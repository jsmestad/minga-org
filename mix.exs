defmodule MingaOrg.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/jsmestad/minga-org"

  def project do
    [
      app: :minga_org,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      dialyzer: [
        plt_add_apps: [:mix, :minga],
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      deps: deps(),
      aliases: aliases(),
      description: "Org-mode support for the Minga editor",
      package: package(),
      source_url: @source_url,
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:minga, path: minga_path(), only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.0", only: [:dev, :test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp minga_path do
    System.get_env("MINGA_PATH", "../minga")
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: [
        "lib",
        "vendor",
        "queries",
        "mix.exs",
        "README.md",
        "LICENSE"
      ]
    ]
  end

  defp aliases do
    [
      lint: [
        "format --check-formatted",
        "credo --strict",
        "compile",
        "dialyzer"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      assets: %{"assets" => "assets"},
      extras: ["README.md"],
      groups_for_modules: [
        "Extension Entry": [MingaOrg],
        "Editing Commands": [
          MingaOrg.Checkbox,
          MingaOrg.Heading,
          MingaOrg.Todo,
          MingaOrg.TableCommands,
          MingaOrg.TagCommands
        ],
        Rendering: [
          MingaOrg.Markup,
          MingaOrg.LinkMarkup,
          MingaOrg.Pretty,
          MingaOrg.Inline
        ],
        "Links & Navigation": [
          MingaOrg.Link,
          MingaOrg.LinkFollow
        ],
        "Capture & Export": [
          MingaOrg.Capture,
          MingaOrg.CapturePicker,
          MingaOrg.CapturePrompt,
          MingaOrg.Export,
          MingaOrg.ExportPicker
        ],
        Pickers: [
          MingaOrg.TagPicker
        ],
        Infrastructure: [
          MingaOrg.Buffer,
          MingaOrg.Buffer.Minga,
          MingaOrg.Commands,
          MingaOrg.Keybindings,
          MingaOrg.Advice,
          MingaOrg.Grammar
        ],
        "Pure Data": [
          MingaOrg.Inline.Span,
          MingaOrg.Link.Parsed,
          MingaOrg.Capture.Template,
          MingaOrg.Table,
          MingaOrg.Tags,
          MingaOrg.List
        ]
      ]
    ]
  end
end
