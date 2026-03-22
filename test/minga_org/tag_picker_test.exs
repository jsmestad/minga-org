defmodule MingaOrg.TagPickerTest do
  use ExUnit.Case, async: true

  import MingaOrg.TestHelpers

  alias MingaOrg.Buffer.Stub
  alias MingaOrg.TagPicker

  describe "candidates/1" do
    test "returns unique tags from buffer headings" do
      buf =
        start_buffer!(
          lines: [
            "* Heading one :work:",
            "Some body text",
            "* Heading two :work:urgent:",
            "* Heading three :personal:"
          ]
        )

      state = make_state(buf)
      candidates = TagPicker.candidates(state)
      ids = Enum.map(candidates, & &1.id)

      assert "work" in ids
      assert "urgent" in ids
      assert "personal" in ids
    end

    test "returns empty list when no tags exist" do
      buf = start_buffer!(lines: ["* Plain heading", "Body text"])
      state = make_state(buf)

      assert TagPicker.candidates(state) == []
    end

    test "each candidate is a Picker.Item with tag label" do
      buf = start_buffer!(lines: ["* Task :work:"])
      state = make_state(buf)
      [item] = TagPicker.candidates(state)

      assert %Minga.Picker.Item{} = item
      assert item.id == "work"
      assert item.label == ":work:"
    end
  end

  describe "on_select/2" do
    test "jumps to first heading with selected tag" do
      buf =
        start_buffer!(
          lines: [
            "* Intro",
            "Body",
            "* Task :work:",
            "Details",
            "* Other :personal:"
          ],
          cursor: {0, 0}
        )

      state = make_state(buf)
      TagPicker.on_select(%{id: "work"}, state)

      assert Stub.cursor(buf) == {2, 0}
    end

    test "does nothing when tag not found" do
      buf = start_buffer!(lines: ["* No tags here"], cursor: {0, 0})
      state = make_state(buf)

      TagPicker.on_select(%{id: "nonexistent"}, state)

      assert Stub.cursor(buf) == {0, 0}
    end
  end

  describe "title/0" do
    test "returns a non-empty string" do
      assert is_binary(TagPicker.title())
    end
  end

  describe "on_cancel/1" do
    test "returns state unchanged" do
      state = %{some: :state}
      assert TagPicker.on_cancel(state) == state
    end
  end
end
