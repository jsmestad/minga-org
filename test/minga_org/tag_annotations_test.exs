defmodule MingaOrg.TagAnnotationsTest do
  use ExUnit.Case, async: true

  alias MingaOrg.TagAnnotations

  doctest MingaOrg.TagAnnotations

  describe "compute_descriptors/3" do
    test "heading with tags produces conceal and annotation descriptors" do
      lines = ["* Heading :work:urgent:"]
      descs = TagAnnotations.compute_descriptors(lines, 99)

      assert length(descs) == 3

      # Conceal the " :work:urgent:" portion (space + raw tags)
      assert {:conceal, 0, start_col, end_col} = Enum.at(descs, 0)
      assert start_col == 9
      assert end_col == 23

      # Annotation for each tag
      assert {:annotation, 0, "work", _bg1, 0xFFFFFF} = Enum.at(descs, 1)
      assert {:annotation, 0, "urgent", _bg2, 0xFFFFFF} = Enum.at(descs, 2)
    end

    test "heading without tags produces no descriptors" do
      lines = ["* Heading without tags"]
      assert [] = TagAnnotations.compute_descriptors(lines, 99)
    end

    test "non-heading lines produce no descriptors" do
      lines = ["Just some body text", "- list item", ""]
      assert [] = TagAnnotations.compute_descriptors(lines, 99)
    end

    test "cursor line is excluded" do
      lines = ["* Heading :work:"]
      assert [] = TagAnnotations.compute_descriptors(lines, 0)
    end

    test "disabled config produces no descriptors" do
      config = %{TagAnnotations.default_config() | enabled: false}
      lines = ["* Heading :work:"]
      assert [] = TagAnnotations.compute_descriptors(lines, 99, config)
    end

    test "multiple headings produce descriptors for each" do
      lines = [
        "* Task 1 :work:",
        "Body text",
        "** Sub task :review:urgent:"
      ]

      descs = TagAnnotations.compute_descriptors(lines, 99)

      # Line 0: 1 conceal + 1 annotation = 2
      # Line 2: 1 conceal + 2 annotations = 3
      assert length(descs) == 5

      line_0_descs = Enum.filter(descs, fn d -> elem(d, 1) == 0 end)
      line_2_descs = Enum.filter(descs, fn d -> elem(d, 1) == 2 end)

      assert length(line_0_descs) == 2
      assert length(line_2_descs) == 3
    end

    test "single tag produces one conceal and one annotation" do
      lines = ["* Todo :next:"]
      descs = TagAnnotations.compute_descriptors(lines, 99)

      assert length(descs) == 2
      assert {:conceal, 0, _, _} = Enum.at(descs, 0)
      assert {:annotation, 0, "next", _, _} = Enum.at(descs, 1)
    end

    test "conceal covers the space before tags" do
      # "** AB :x:" has title "AB" at positions 0-4 ("** AB"), then " :x:" at 5-9
      lines = ["** AB :x:"]
      [{:conceal, 0, start_col, end_col} | _] = TagAnnotations.compute_descriptors(lines, 99)

      # The raw_tags is ":x:", which is 3 chars. The line is 9 chars.
      # start_col = 9 - 3 - 1 = 5 (the space before the colon)
      assert start_col == 5
      assert end_col == 9
    end

    test "deeply nested heading works" do
      lines = ["**** Deep :nested:tags:here:"]
      descs = TagAnnotations.compute_descriptors(lines, 99)

      # 1 conceal + 3 annotations
      assert length(descs) == 4

      annotations = Enum.filter(descs, fn d -> elem(d, 0) == :annotation end)
      tag_names = Enum.map(annotations, fn {:annotation, _, name, _, _} -> name end)
      assert tag_names == ["nested", "tags", "here"]
    end
  end

  describe "color_for_tag/2" do
    test "returns a color from the palette" do
      config = TagAnnotations.default_config()
      color = TagAnnotations.color_for_tag("work", config)
      assert color in config.palette
    end

    test "same tag always gets the same color" do
      config = TagAnnotations.default_config()

      assert TagAnnotations.color_for_tag("work", config) ==
               TagAnnotations.color_for_tag("work", config)
    end

    test "different tags get deterministic colors from the palette" do
      config = TagAnnotations.default_config()
      # MD5 hash picks a palette index; verify known values
      assert TagAnnotations.color_for_tag("work", config) == 0x14B8A6
      assert TagAnnotations.color_for_tag("urgent", config) == 0xF97316
      assert TagAnnotations.color_for_tag("personal", config) == 0x6366F1

      # Different tags get different colors (these three hash to distinct indices)
      colors = [
        TagAnnotations.color_for_tag("work", config),
        TagAnnotations.color_for_tag("urgent", config),
        TagAnnotations.color_for_tag("personal", config)
      ]

      assert length(Enum.uniq(colors)) == 3
    end

    test "explicit tag_colors override the palette" do
      config = %{TagAnnotations.default_config() | tag_colors: %{"work" => 0xFF0000}}
      assert TagAnnotations.color_for_tag("work", config) == 0xFF0000
    end

    test "non-overridden tags still use the palette" do
      config = %{TagAnnotations.default_config() | tag_colors: %{"work" => 0xFF0000}}
      color = TagAnnotations.color_for_tag("personal", config)
      assert color in config.palette
    end
  end

  describe "default_config/0" do
    test "returns expected defaults" do
      config = TagAnnotations.default_config()
      assert config.enabled == true
      assert config.fg == 0xFFFFFF
      assert length(config.palette) == 8
      assert config.tag_colors == %{}
    end
  end
end
