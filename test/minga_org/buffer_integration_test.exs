defmodule MingaOrg.BufferIntegrationTest do
  use ExUnit.Case, async: true

  import MingaOrg.TestHelpers

  alias MingaOrg.Buffer.Stub
  alias MingaOrg.Checkbox
  alias MingaOrg.Heading
  alias MingaOrg.Todo

  describe "TODO cycling writes back to buffer" do
    test "cycles TODO keyword on heading line" do
      buf = start_buffer!(lines: ["* Buy groceries", "Some text"], cursor: {0, 0})
      state = make_state(buf)

      Todo.cycle(state, ["TODO", "DONE"])

      assert Stub.lines(buf) == ["* TODO Buy groceries", "Some text"]
    end

    test "cycles through full keyword sequence" do
      buf = start_buffer!(lines: ["* Task"], cursor: {0, 0})
      state = make_state(buf)

      Todo.cycle(state, ["TODO", "DONE"])
      assert Stub.lines(buf) == ["* TODO Task"]

      Stub.move_to(buf, {0, 0})
      Todo.cycle(state, ["TODO", "DONE"])
      assert Stub.lines(buf) == ["* DONE Task"]

      Stub.move_to(buf, {0, 0})
      Todo.cycle(state, ["TODO", "DONE"])
      assert Stub.lines(buf) == ["* Task"]
    end
  end

  describe "checkbox toggle writes back to buffer" do
    test "toggles checkbox from unchecked to checked" do
      buf = start_buffer!(lines: ["- [ ] Buy milk", "- [ ] Get bread"], cursor: {0, 0})
      state = make_state(buf)

      Checkbox.toggle(state)

      assert Stub.lines(buf) == ["- [x] Buy milk", "- [ ] Get bread"]
    end

    test "toggles checkbox on second line" do
      buf = start_buffer!(lines: ["- [x] Done", "- [ ] Pending"], cursor: {1, 0})
      state = make_state(buf)

      Checkbox.toggle(state)

      assert Stub.lines(buf) == ["- [x] Done", "- [x] Pending"]
    end
  end

  describe "heading promote/demote transforms correctly" do
    test "demoting a heading adds a star" do
      buf = start_buffer!(lines: ["* Top level", "Some body"], cursor: {0, 0})
      state = make_state(buf)

      Heading.demote(state)

      assert Stub.lines(buf) == ["** Top level", "Some body"]
    end

    test "promoting a heading removes a star" do
      buf = start_buffer!(lines: ["** Sub heading", "Body text"], cursor: {0, 0})
      state = make_state(buf)

      Heading.promote(state)

      assert Stub.lines(buf) == ["* Sub heading", "Body text"]
    end

    test "promoting a top-level heading is a no-op" do
      buf = start_buffer!(lines: ["* Already top", "Text"], cursor: {0, 0})
      state = make_state(buf)

      Heading.promote(state)

      assert Stub.lines(buf) == ["* Already top", "Text"]
    end
  end

  describe "heading move swaps lines" do
    test "moving heading down swaps with next section" do
      buf =
        start_buffer!(
          lines: ["* First", "Body one", "* Second", "Body two"],
          cursor: {0, 0}
        )

      state = make_state(buf)

      Heading.move_down(state)

      lines = Stub.lines(buf)
      # First heading + body should now be after Second heading + body
      assert hd(lines) == "* Second"
    end
  end

  describe "smart newline inserts continuation prefix" do
    test "continues unordered list" do
      buf = start_buffer!(lines: ["- Item one"], cursor: {0, 10})
      state = make_state(buf)

      # Simulate smart_newline with an execute function
      execute = fn s -> s end
      MingaOrg.Advice.smart_newline(execute, state)

      lines = Stub.lines(buf)
      assert length(lines) == 2
      assert Enum.at(lines, 1) == "- "
    end
  end
end
