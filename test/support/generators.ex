defmodule MingaOrg.Generators do
  @moduledoc """
  StreamData generators for org-mode structures.

  Used by property tests to explore the input space of org headings,
  checkboxes, inline markup, and lists.
  """

  use ExUnitProperties

  @todo_keywords ["TODO", "DONE", "IN-PROGRESS", "WAITING"]

  @doc "Generates an org heading line like `** TODO Buy groceries`."
  @spec org_heading() :: StreamData.t(String.t())
  def org_heading do
    gen all(
          level <- integer(1..6),
          keyword <- one_of([constant(nil), member_of(@todo_keywords)]),
          content <-
            string(:printable, min_length: 1, max_length: 50)
            |> filter(&(!String.starts_with?(&1, " ")))
            |> filter(&(!Regex.match?(~r/^[A-Z][A-Z\-]+\s/, &1)))
        ) do
      stars = String.duplicate("*", level)

      case keyword do
        nil -> "#{stars} #{content}"
        kw -> "#{stars} #{kw} #{content}"
      end
    end
  end

  @doc """
  Generates a checkbox line like `- [ ] Task item`.

  Options:
  - `:statuses` - list of checkbox statuses to use (default: all)
  """
  @spec checkbox_line(keyword()) :: StreamData.t(String.t())
  def checkbox_line(opts \\ []) do
    statuses = Keyword.get(opts, :statuses, [" ", "x", "X", "-"])

    gen all(
          indent <- indent(),
          bullet <- member_of(["-", "+", "*"]),
          status <- member_of(statuses),
          content <-
            string(:printable, min_length: 1, max_length: 40)
            |> filter(&(!String.starts_with?(&1, " ")))
        ) do
      "#{indent}#{bullet} [#{status}] #{content}"
    end
  end

  @doc "Generates text with inline markup like `some *bold* text`."
  @spec inline_markup_text() :: StreamData.t(String.t())
  def inline_markup_text do
    gen all(
          prefix <- string(:alphanumeric, min_length: 0, max_length: 10),
          delimiter <- member_of(["*", "/", "~", "=", "+"]),
          content <-
            string(:alphanumeric, min_length: 1, max_length: 20)
            |> filter(&(!String.contains?(&1, delimiter))),
          suffix <- string(:alphanumeric, min_length: 0, max_length: 10)
        ) do
      "#{prefix} #{delimiter}#{content}#{delimiter} #{suffix}"
    end
  end

  @doc "Generates an unordered list line."
  @spec unordered_list_line() :: StreamData.t(String.t())
  def unordered_list_line do
    gen all(
          indent <- indent(),
          bullet <- member_of(["-", "+", "*"]),
          content <-
            string(:printable, min_length: 1, max_length: 40)
            |> filter(&(!String.starts_with?(&1, " ")))
        ) do
      "#{indent}#{bullet} #{content}"
    end
  end

  @doc "Generates an ordered list line."
  @spec ordered_list_line() :: StreamData.t(String.t())
  def ordered_list_line do
    gen all(
          indent <- indent(),
          number <- integer(1..999),
          separator <- member_of([".", ")"]),
          content <-
            string(:printable, min_length: 1, max_length: 40)
            |> filter(&(!String.starts_with?(&1, " ")))
        ) do
      "#{indent}#{number}#{separator} #{content}"
    end
  end

  # ── Private helpers ────────────────────────────────────────────────────────

  @spec indent() :: StreamData.t(String.t())
  defp indent do
    gen all(depth <- integer(0..4)) do
      String.duplicate("  ", depth)
    end
  end
end
