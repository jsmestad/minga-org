defmodule MingaOrg.PrettyTest do
  use ExUnit.Case, async: true

  alias MingaOrg.Pretty

  describe "heading_bullet/1" do
    test "level 1 returns first bullet" do
      assert "◉" = Pretty.heading_bullet(1)
    end

    test "level 2 returns second bullet" do
      assert "○" = Pretty.heading_bullet(2)
    end

    test "level 3 returns third bullet" do
      assert "◈" = Pretty.heading_bullet(3)
    end

    test "level 4 returns fourth bullet" do
      assert "◇" = Pretty.heading_bullet(4)
    end

    test "level 5 cycles back to first" do
      assert "◉" = Pretty.heading_bullet(5)
    end

    test "custom bullet set" do
      assert "A" = Pretty.heading_bullet(1, ["A", "B"])
      assert "B" = Pretty.heading_bullet(2, ["A", "B"])
      assert "A" = Pretty.heading_bullet(3, ["A", "B"])
    end
  end

  describe "compute_decorations/3" do
    test "heading stars get replaced with bullet" do
      lines = ["* Heading 1"]
      [desc] = Pretty.compute_decorations(lines, 99)
      assert {:conceal_replace, 0, 0, 2, "◉"} = desc
    end

    test "level 2 heading gets second bullet" do
      lines = ["** Heading 2"]
      [desc] = Pretty.compute_decorations(lines, 99)
      assert {:conceal_replace, 0, 0, 3, "○"} = desc
    end

    test "level 3 heading" do
      lines = ["*** Heading 3"]
      [desc] = Pretty.compute_decorations(lines, 99)
      assert {:conceal_replace, 0, 0, 4, "◈"} = desc
    end

    test "list bullet gets replaced" do
      lines = ["- Item"]
      [desc] = Pretty.compute_decorations(lines, 99)
      assert {:conceal_replace, 0, 0, 1, "•"} = desc
    end

    test "plus bullet gets replaced" do
      lines = ["+ Item"]
      [desc] = Pretty.compute_decorations(lines, 99)
      assert {:conceal_replace, 0, 0, 1, "•"} = desc
    end

    test "indented list bullet has correct column" do
      lines = ["  - Nested"]
      [desc] = Pretty.compute_decorations(lines, 99)
      assert {:conceal_replace, 0, 2, 3, "•"} = desc
    end

    test "cursor line is excluded" do
      lines = ["* Heading"]
      assert [] = Pretty.compute_decorations(lines, 0)
    end

    test "plain text produces no decorations" do
      lines = ["Just some text"]
      assert [] = Pretty.compute_decorations(lines, 99)
    end

    test "disabled config produces no decorations" do
      config = %{Pretty.default_config() | enabled: false}
      lines = ["* Heading"]
      assert [] = Pretty.compute_decorations(lines, 99, config)
    end

    test "multiple lines produce multiple decorations" do
      lines = ["* H1", "** H2", "- Item", "text"]
      descs = Pretty.compute_decorations(lines, 99)
      assert length(descs) == 3
    end

    test "custom bullet config" do
      config = %{Pretty.default_config() | heading_bullets: ["▸"], list_bullet: "⁃"}
      lines = ["* Heading", "- Item"]
      descs = Pretty.compute_decorations(lines, 99, config)

      assert {:conceal_replace, 0, 0, 2, "▸"} = Enum.at(descs, 0)
      assert {:conceal_replace, 1, 0, 1, "⁃"} = Enum.at(descs, 1)
    end
  end

  describe "default_config/0" do
    test "returns expected defaults" do
      config = Pretty.default_config()
      assert config.heading_bullets == ["◉", "○", "◈", "◇"]
      assert config.list_bullet == "•"
      assert config.enabled == true
    end
  end
end
