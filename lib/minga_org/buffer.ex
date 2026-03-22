defmodule MingaOrg.Buffer do
  @moduledoc """
  Buffer access behaviour for minga-org.

  Defines the callback contract that all buffer backends must implement.
  The active backend is selected at compile time via:

      config :minga_org, buffer_backend: MingaOrg.Buffer.Minga

  Production uses `MingaOrg.Buffer.Minga` (delegates to `Minga.Buffer.Server`).
  Tests use `MingaOrg.Buffer.Stub` (in-memory Agent).
  """

  @callback line_at(pid(), non_neg_integer()) :: {:ok, String.t()} | :error
  @callback cursor(pid()) :: {non_neg_integer(), non_neg_integer()}
  @callback insert_char(pid(), String.t()) :: :ok
  @callback filetype(pid()) :: atom()
  @callback get_lines(pid(), non_neg_integer(), non_neg_integer()) :: [String.t()]
  @callback line_count(pid()) :: non_neg_integer()
  @callback move_to(pid(), {non_neg_integer(), non_neg_integer()}) :: :ok
  @callback apply_text_edit(
              pid(),
              non_neg_integer(),
              non_neg_integer(),
              non_neg_integer(),
              non_neg_integer(),
              String.t()
            ) :: :ok
  @callback batch_decorations(pid(), (struct() -> struct())) :: :ok
  @callback apply_text_edits(pid(), [tuple()]) :: :ok

  @backend Application.compile_env(:minga_org, :buffer_backend, MingaOrg.Buffer.Minga)

  @doc "Returns the text of a single line, or `:error` if out of range."
  @spec line_at(pid(), non_neg_integer()) :: {:ok, String.t()} | :error
  defdelegate line_at(buf, line_num), to: @backend

  @doc "Returns the cursor position as `{line, col}`."
  @spec cursor(pid()) :: {non_neg_integer(), non_neg_integer()}
  defdelegate cursor(buf), to: @backend

  @doc "Inserts text at the cursor position."
  @spec insert_char(pid(), String.t()) :: :ok
  defdelegate insert_char(buf, text), to: @backend

  @doc "Returns the detected filetype atom for this buffer."
  @spec filetype(pid()) :: atom()
  defdelegate filetype(buf), to: @backend

  @doc "Returns a range of lines as a list of strings."
  @spec get_lines(pid(), non_neg_integer(), non_neg_integer()) :: [String.t()]
  defdelegate get_lines(buf, start_line, count), to: @backend

  @doc "Returns the total number of lines in the buffer."
  @spec line_count(pid()) :: non_neg_integer()
  defdelegate line_count(buf), to: @backend

  @doc "Moves the cursor to the given position."
  @spec move_to(pid(), {non_neg_integer(), non_neg_integer()}) :: :ok
  defdelegate move_to(buf, pos), to: @backend

  @doc "Replaces a range of text with new text."
  @spec apply_text_edit(
          pid(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t()
        ) :: :ok
  defdelegate apply_text_edit(buf, start_line, start_col, end_line, end_col, new_text),
    to: @backend

  @doc "Executes a batch of decoration operations atomically."
  @spec batch_decorations(pid(), (struct() -> struct())) :: :ok
  defdelegate batch_decorations(buf, fun), to: @backend

  @doc "Applies multiple text edits in a single call."
  @spec apply_text_edits(pid(), [tuple()]) :: :ok
  defdelegate apply_text_edits(buf, edits), to: @backend
end
