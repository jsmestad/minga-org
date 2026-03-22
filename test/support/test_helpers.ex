defmodule MingaOrg.TestHelpers do
  @moduledoc """
  Helpers for buffer integration tests.

  Provides `start_buffer!/1` and `make_state/1` to set up an in-memory
  buffer and the minimal editor state map that extension functions expect.
  """

  @doc "Starts a stub buffer with the given options."
  @spec start_buffer!(keyword()) :: pid()
  def start_buffer!(opts \\ []) do
    {:ok, pid} = MingaOrg.Buffer.Stub.start_link(opts)
    pid
  end

  @doc "Builds a minimal editor state map pointing to the given buffer."
  @spec make_state(pid()) :: map()
  def make_state(buf_pid) do
    %{buffers: %{active: buf_pid}}
  end
end
