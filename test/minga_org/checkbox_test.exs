defmodule MingaOrg.CheckboxTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MingaOrg.Checkbox
  alias MingaOrg.Generators

  describe "toggle_checkbox_text/1" do
    test "checks an unchecked checkbox" do
      assert {:ok, "- [x] Buy milk"} = Checkbox.toggle_checkbox_text("- [ ] Buy milk")
    end

    test "unchecks a checked checkbox" do
      assert {:ok, "- [ ] Buy milk"} = Checkbox.toggle_checkbox_text("- [x] Buy milk")
      assert {:ok, "- [ ] Buy milk"} = Checkbox.toggle_checkbox_text("- [X] Buy milk")
    end

    test "checks an in-progress checkbox" do
      assert {:ok, "- [x] Working"} = Checkbox.toggle_checkbox_text("- [-] Working")
    end

    test "handles leading whitespace" do
      assert {:ok, "  - [x] Indented"} = Checkbox.toggle_checkbox_text("  - [ ] Indented")
      assert {:ok, "    - [ ] Deep"} = Checkbox.toggle_checkbox_text("    - [x] Deep")
    end

    test "handles different list markers" do
      assert {:ok, "+ [x] Plus"} = Checkbox.toggle_checkbox_text("+ [ ] Plus")
      assert {:ok, "* [x] Star"} = Checkbox.toggle_checkbox_text("* [ ] Star")
      assert {:ok, "1. [x] Numbered"} = Checkbox.toggle_checkbox_text("1. [ ] Numbered")
      assert {:ok, "2) [x] Paren"} = Checkbox.toggle_checkbox_text("2) [ ] Paren")
    end

    test "returns :no_checkbox for lines without checkboxes" do
      assert :no_checkbox = Checkbox.toggle_checkbox_text("- Plain list item")
      assert :no_checkbox = Checkbox.toggle_checkbox_text("** Heading")
      assert :no_checkbox = Checkbox.toggle_checkbox_text("Just text")
      assert :no_checkbox = Checkbox.toggle_checkbox_text("")
    end

    test "preserves text after checkbox" do
      assert {:ok, "- [x] Buy milk @store :errand:"} =
               Checkbox.toggle_checkbox_text("- [ ] Buy milk @store :errand:")
    end
  end

  describe "properties" do
    property "toggling a stable checkbox twice returns to original" do
      # Only [ ] and [x] are stable roundtrips. [-] and [X] normalize
      # on the first toggle ([-] -> [x], [X] -> [ ]).
      check all(line <- Generators.checkbox_line(statuses: [" ", "x"])) do
        {:ok, toggled_once} = Checkbox.toggle_checkbox_text(line)
        {:ok, toggled_twice} = Checkbox.toggle_checkbox_text(toggled_once)
        assert toggled_twice == line
      end
    end
  end
end
