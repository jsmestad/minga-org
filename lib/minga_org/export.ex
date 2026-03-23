defmodule MingaOrg.Export do
  @moduledoc """
  Export org files via pandoc.

  Delegates all conversion to [pandoc](https://pandoc.org/), which has
  full org-mode reader support. Supported output formats include HTML,
  Markdown, PDF, LaTeX, and any format pandoc supports.

  Export runs asynchronously so the editor isn't blocked during
  conversion.
  """

  @default_formats [
    {"html", "HTML"},
    {"markdown", "Markdown"},
    {"pdf", "PDF"},
    {"latex", "LaTeX"},
    {"docx", "Word (docx)"},
    {"rst", "reStructuredText"},
    {"asciidoc", "AsciiDoc"}
  ]

  @doc """
  Returns the list of available export formats.

  Each entry is `{pandoc_format, display_name}`.
  """
  @spec formats() :: [{String.t(), String.t()}]
  def formats, do: @default_formats

  @doc """
  Checks if pandoc is installed and returns its version.

  Returns `{:ok, version}` or `{:error, reason}`.
  """
  @spec check_pandoc() :: {:ok, String.t()} | {:error, String.t()}
  def check_pandoc do
    case System.cmd("pandoc", ["--version"], stderr_to_stdout: true) do
      {output, 0} ->
        version = output |> String.split("\n") |> hd() |> String.trim()
        {:ok, version}

      {_, _} ->
        {:error, "pandoc not found. Install it: https://pandoc.org/installing.html"}
    end
  rescue
    ErlangError ->
      {:error, "pandoc not found. Install it: https://pandoc.org/installing.html"}
  end

  @doc """
  Exports the given file to the specified format.

  Returns `{:ok, output_path}` on success or `{:error, reason}` on failure.
  The output file is written next to the source file with the appropriate
  extension.

  ## Examples

      iex> MingaOrg.Export.export("/path/to/notes.org", "html")
      {:ok, "/path/to/notes.html"}
  """
  @spec export(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def export(input_path, format) do
    output_path = output_path_for(input_path, format)

    args = [input_path, "-o", output_path, "--from=org", "--to=#{format}"]

    case System.cmd("pandoc", args, stderr_to_stdout: true) do
      {_output, 0} ->
        {:ok, output_path}

      {error_output, _code} ->
        {:error, "pandoc export failed: #{String.trim(error_output)}"}
    end
  rescue
    ErlangError ->
      {:error, "pandoc not found. Install it: https://pandoc.org/installing.html"}
  end

  @doc """
  Exports the active buffer's file asynchronously.

  This is a state -> state command function. The export runs in a
  background task. Success/failure is logged to *Messages*.
  """
  @spec export_command(map(), String.t()) :: map()
  def export_command(state, format) do
    buf = state.buffers.active

    case get_file_path(buf) do
      {:ok, path} ->
        Task.start(fn -> run_export(path, format) end)
        state

      :no_file ->
        state
    end
  end

  @spec run_export(String.t(), String.t()) :: :ok
  defp run_export(path, format) do
    case export(path, format) do
      {:ok, output} ->
        Minga.Editor.log_to_messages("Exported to #{output}")

      {:error, reason} ->
        Minga.Editor.log_to_messages("Export failed: #{reason}")
    end
  end

  @doc """
  Computes the output file path for a given input and format.

  ## Examples

      iex> MingaOrg.Export.output_path_for("/path/to/notes.org", "html")
      "/path/to/notes.html"

      iex> MingaOrg.Export.output_path_for("/path/to/notes.org", "pdf")
      "/path/to/notes.pdf"
  """
  @spec output_path_for(String.t(), String.t()) :: String.t()
  def output_path_for(input_path, format) do
    ext = format_extension(format)
    base = Path.rootname(input_path)
    "#{base}.#{ext}"
  end

  # ── Private ────────────────────────────────────────────────────────────────

  @spec format_extension(String.t()) :: String.t()
  defp format_extension("markdown"), do: "md"
  defp format_extension("latex"), do: "tex"
  defp format_extension("asciidoc"), do: "adoc"
  defp format_extension("rst"), do: "rst"
  defp format_extension(format), do: format

  @spec get_file_path(pid()) :: {:ok, String.t()} | :no_file
  defp get_file_path(buf) do
    path = Minga.Buffer.Server.file_path(buf)
    if path, do: {:ok, path}, else: :no_file
  rescue
    _ -> :no_file
  end
end
