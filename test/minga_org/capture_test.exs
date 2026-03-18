defmodule MingaOrg.CaptureTest do
  use ExUnit.Case, async: true

  alias MingaOrg.Capture
  alias MingaOrg.Capture.Template

  describe "render/2" do
    test "renders TODO template" do
      tmpl = %Template{
        key: "t",
        name: "TODO",
        target: "~/org/inbox.org",
        template: "* TODO %{title}"
      }

      assert "* TODO Buy milk" = Capture.render(tmpl, %{title: "Buy milk"})
    end

    test "renders note template with body" do
      tmpl = %Template{
        key: "n",
        name: "Note",
        target: "~/org/inbox.org",
        template: "* %{title}\n%{body}"
      }

      result = Capture.render(tmpl, %{title: "Meeting", body: "Discussed project X"})
      assert result == "* Meeting\nDiscussed project X"
    end

    test "renders template with empty body" do
      tmpl = %Template{
        key: "n",
        name: "Note",
        target: "~/org/inbox.org",
        template: "* %{title}\n%{body}"
      }

      assert "* Quick note" = Capture.render(tmpl, %{title: "Quick note"})
    end

    test "renders journal template with date" do
      tmpl = %Template{
        key: "j",
        name: "Journal",
        target: "~/org/journal.org",
        heading: "Entries",
        template: "* %{date} %{title}\n%{body}"
      }

      result = Capture.render(tmpl, %{title: "Today", date: "2026-03-18"})
      assert result == "* 2026-03-18 Today"
    end

    test "provides default date if not given" do
      tmpl = %Template{key: "j", name: "J", target: "f", template: "* %{date} %{title}"}
      result = Capture.render(tmpl, %{title: "Entry"})
      # Should contain today's date
      assert String.contains?(result, "Entry")
      assert String.match?(result, ~r/\d{4}-\d{2}-\d{2}/)
    end
  end

  describe "insert_into/3" do
    test "appends to empty file" do
      assert "* TODO Task\n" = Capture.insert_into("", "* TODO Task", nil)
    end

    test "appends to end of file" do
      content = "* Heading\nSome text"
      result = Capture.insert_into(content, "* TODO New", nil)
      assert result == "* Heading\nSome text\n\n* TODO New\n"
    end

    test "inserts under specific heading" do
      content = "* Tasks\n- Old task\n* Notes\nSome notes"
      result = Capture.insert_into(content, "- New task", "Tasks")
      lines = String.split(result, "\n")
      # New task should be between "- Old task" and "* Notes"
      assert Enum.at(lines, 2) == "- New task"
    end

    test "falls back to end if heading not found" do
      content = "* Other\nText"
      result = Capture.insert_into(content, "* TODO New", "Missing Heading")
      assert String.contains?(result, "* TODO New")
    end

    test "inserts at end of deeply nested section" do
      content = "* H1\n** H2\nBody\n* H3\nOther"
      result = Capture.insert_into(content, "New line", "H1")
      lines = String.split(result, "\n")
      # Should be inserted before * H3 (at index 3)
      assert Enum.at(lines, 3) == "New line"
    end

    test "case-insensitive heading match" do
      content = "* My Tasks\n- item"
      result = Capture.insert_into(content, "- new", "my tasks")
      assert String.contains?(result, "- new")
    end
  end

  describe "expand_path/1" do
    test "expands tilde" do
      result = Capture.expand_path("~/org/inbox.org")
      refute String.starts_with?(result, "~")
      assert String.ends_with?(result, "org/inbox.org")
    end

    test "leaves absolute paths unchanged" do
      assert "/absolute/path" = Capture.expand_path("/absolute/path")
    end

    test "leaves relative paths unchanged" do
      assert "relative/path" = Capture.expand_path("relative/path")
    end
  end

  describe "default_templates/0" do
    test "returns non-empty list" do
      templates = Capture.default_templates()
      assert length(templates) >= 2
    end

    test "includes TODO template" do
      templates = Capture.default_templates()
      assert Enum.any?(templates, &(&1.name == "TODO"))
    end

    test "includes Note template" do
      templates = Capture.default_templates()
      assert Enum.any?(templates, &(&1.name == "Note"))
    end
  end
end
