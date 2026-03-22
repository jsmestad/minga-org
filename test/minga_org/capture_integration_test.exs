defmodule MingaOrg.CaptureIntegrationTest do
  use ExUnit.Case, async: true

  alias MingaOrg.Capture
  alias MingaOrg.CapturePicker
  alias MingaOrg.CapturePrompt

  describe "CapturePicker.candidates/1" do
    test "returns one candidate per default template" do
      candidates = CapturePicker.candidates(nil)
      assert length(candidates) == length(Capture.default_templates())
    end

    test "each candidate is a Picker.Item with template as id" do
      for item <- CapturePicker.candidates(nil) do
        assert %Minga.Picker.Item{} = item
        assert %Capture.Template{} = item.id
        assert is_binary(item.label)
        assert is_binary(item.description)
      end
    end

    test "labels show key and name" do
      [todo | _] = CapturePicker.candidates(nil)
      assert todo.label =~ "[t]"
      assert todo.label =~ "TODO"
    end
  end

  describe "CapturePicker.title/0" do
    test "returns a non-empty string" do
      assert is_binary(CapturePicker.title())
    end
  end

  describe "CapturePicker.on_cancel/1" do
    test "returns state unchanged" do
      state = %{some: :state}
      assert CapturePicker.on_cancel(state) == state
    end
  end

  describe "CapturePrompt.label/0" do
    test "returns a non-empty string" do
      assert is_binary(CapturePrompt.label())
    end
  end

  describe "CapturePrompt.on_cancel/1" do
    test "returns state unchanged" do
      state = %{some: :state}
      assert CapturePrompt.on_cancel(state) == state
    end
  end

  describe "CapturePrompt.on_submit/2 writes to file" do
    @tag :tmp_dir
    test "writes rendered template to target file", %{tmp_dir: tmp_dir} do
      target = Path.join(tmp_dir, "inbox.org")

      template = %Capture.Template{
        key: "t",
        name: "TODO",
        target: target,
        template: "* TODO %{title}"
      }

      state = %{prompt_ui: %{context: %{template: template}}}
      CapturePrompt.on_submit("Buy milk", state)

      assert File.exists?(target)
      content = File.read!(target)
      assert content =~ "* TODO Buy milk"
    end

    @tag :tmp_dir
    test "appends under heading when specified", %{tmp_dir: tmp_dir} do
      target = Path.join(tmp_dir, "inbox.org")
      File.write!(target, "* Tasks\n\n* Other\n")

      template = %Capture.Template{
        key: "t",
        name: "TODO",
        target: target,
        template: "* TODO %{title}",
        heading: "Tasks"
      }

      state = %{prompt_ui: %{context: %{template: template}}}
      CapturePrompt.on_submit("Review PR", state)

      content = File.read!(target)
      lines = String.split(content, "\n")
      tasks_idx = Enum.find_index(lines, &(&1 == "* Tasks"))
      other_idx = Enum.find_index(lines, &(&1 == "* Other"))
      todo_idx = Enum.find_index(lines, &(&1 =~ "TODO Review PR"))

      assert todo_idx > tasks_idx
      assert todo_idx < other_idx
    end

    @tag :tmp_dir
    test "creates target file if it does not exist", %{tmp_dir: tmp_dir} do
      target = Path.join([tmp_dir, "subdir", "new.org"])

      template = %Capture.Template{
        key: "n",
        name: "Note",
        target: target,
        template: "* %{title}"
      }

      state = %{prompt_ui: %{context: %{template: template}}}
      CapturePrompt.on_submit("New note", state)

      assert File.exists?(target)
      assert File.read!(target) =~ "* New note"
    end
  end
end
