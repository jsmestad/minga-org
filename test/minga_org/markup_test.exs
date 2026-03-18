defmodule MingaOrg.MarkupTest do
  use ExUnit.Case, async: true

  alias MingaOrg.Markup

  describe "compute_descriptors/2" do
    test "returns empty for lines without markup" do
      assert [] = Markup.compute_descriptors(["plain text", "no markup"], 0)
    end

    test "produces highlight and conceal descriptors for markup" do
      descriptors = Markup.compute_descriptors(["*bold* text"], 99)

      highlights = Enum.filter(descriptors, &match?({:highlight, _, _}, &1))
      conceals = Enum.filter(descriptors, &match?({:conceal, _, _}, &1))

      assert length(highlights) == 1
      assert length(conceals) == 2

      [{:highlight, 0, span}] = highlights
      assert span.type == :bold
      assert span.content == "bold"
    end

    test "skips conceals on cursor line" do
      descriptors = Markup.compute_descriptors(["*bold* text"], 0)

      highlights = Enum.filter(descriptors, &match?({:highlight, _, _}, &1))
      conceals = Enum.filter(descriptors, &match?({:conceal, _, _}, &1))

      assert length(highlights) == 1
      assert length(conceals) == 0
    end

    test "handles multiple lines with different markup" do
      lines = ["*bold*", "plain", "/italic/"]
      descriptors = Markup.compute_descriptors(lines, 99)

      highlights = Enum.filter(descriptors, &match?({:highlight, _, _}, &1))
      assert length(highlights) == 2

      types = Enum.map(highlights, fn {:highlight, _, span} -> span.type end)
      assert :bold in types
      assert :italic in types
    end

    test "conceal positions match delimiter positions" do
      descriptors = Markup.compute_descriptors(["hello *world* end"], 99)

      conceals =
        descriptors
        |> Enum.filter(&match?({:conceal, _, _}, &1))
        |> Enum.map(fn {:conceal, _line, col} -> col end)
        |> Enum.sort()

      # Opening * at col 6, closing * at col 12
      assert conceals == [6, 12]
    end
  end
end
