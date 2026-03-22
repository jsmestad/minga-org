defmodule MingaOrg.LinkMarkupTest do
  use ExUnit.Case, async: true

  alias MingaOrg.LinkMarkup

  describe "compute_descriptors/2" do
    test "link with description produces highlight on desc and conceals brackets" do
      lines = ["See [[https://example.com][Example]] end"]
      descs = LinkMarkup.compute_descriptors(lines, 99)

      highlights = Enum.filter(descs, &match?({:highlight, _, _, _}, &1))
      conceals = Enum.filter(descs, &match?({:conceal, _, _, _}, &1))

      assert length(highlights) == 1
      assert length(conceals) == 2

      [{:highlight, 0, desc_start, desc_end}] = highlights
      # "[[https://example.com][" = 2 + 19 + 2 = 23 chars from position 4
      # "Example" starts at 4 + 23 = 27, but let me compute:
      # "See " = 4 chars, [[ = 2, url = 19, ][ = 2 → desc starts at 4+2+19+2 = 27
      assert desc_start == 27
      # "Example" = 7 chars → desc ends at 34
      assert desc_end == 34
    end

    test "link without description highlights URL" do
      lines = ["[[https://example.com]]"]
      descs = LinkMarkup.compute_descriptors(lines, 99)

      highlights = Enum.filter(descs, &match?({:highlight, _, _, _}, &1))
      conceals = Enum.filter(descs, &match?({:conceal, _, _, _}, &1))

      assert length(highlights) == 1
      assert length(conceals) == 2

      [{:highlight, 0, url_start, url_end}] = highlights
      # [[ = 2, url ends before ]] = 20
      assert url_start == 2
      assert url_end == 21
    end

    test "cursor line gets highlights but no conceals" do
      lines = ["[[url][desc]]"]
      descs = LinkMarkup.compute_descriptors(lines, 0)

      highlights = Enum.filter(descs, &match?({:highlight, _, _, _}, &1))
      conceals = Enum.filter(descs, &match?({:conceal, _, _, _}, &1))

      assert length(highlights) == 1
      assert length(conceals) == 0
    end

    test "no links produces no descriptors" do
      assert [] = LinkMarkup.compute_descriptors(["plain text"], 99)
    end

    test "multiple links on one line" do
      lines = ["[[a][A]] and [[b][B]]"]
      descs = LinkMarkup.compute_descriptors(lines, 99)

      highlights = Enum.filter(descs, &match?({:highlight, _, _, _}, &1))
      assert length(highlights) == 2
    end
  end
end
