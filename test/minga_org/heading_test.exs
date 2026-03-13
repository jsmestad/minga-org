defmodule MingaOrg.HeadingTest do
  use ExUnit.Case, async: true

  # Heading promotion/demotion tests operate on pure text
  # since the actual buffer operations require a running editor.

  describe "heading level detection" do
    test "promote removes one star" do
      assert "** Heading" = promote_text("*** Heading")
      assert "* Heading" = promote_text("** Heading")
    end

    test "promote does not go below one star" do
      assert "* Heading" = promote_text("* Heading")
    end

    test "demote adds one star" do
      assert "** Heading" = demote_text("* Heading")
      assert "*** Heading" = demote_text("** Heading")
    end

    test "promote preserves TODO keyword" do
      assert "* TODO Task" = promote_text("** TODO Task")
    end

    test "demote preserves TODO keyword" do
      assert "*** TODO Task" = demote_text("** TODO Task")
    end
  end

  # Helpers that test the pure text transformation logic
  # without needing a buffer server.

  @spec promote_text(String.t()) :: String.t()
  defp promote_text(line) do
    case MingaOrg.Todo.parse_heading(line) do
      {:ok, stars, keyword, rest} ->
        new_stars =
          if String.length(stars) > 1 do
            String.slice(stars, 1..-1//1)
          else
            stars
          end

        build_heading(new_stars, keyword, rest)

      :not_heading ->
        line
    end
  end

  @spec demote_text(String.t()) :: String.t()
  defp demote_text(line) do
    case MingaOrg.Todo.parse_heading(line) do
      {:ok, stars, keyword, rest} ->
        build_heading("*" <> stars, keyword, rest)

      :not_heading ->
        line
    end
  end

  @spec build_heading(String.t(), String.t() | nil, String.t()) :: String.t()
  defp build_heading(stars, nil, rest), do: "#{stars} #{rest}"
  defp build_heading(stars, keyword, rest), do: "#{stars} #{keyword} #{rest}"
end
