defmodule MingaOrg.TagsTest do
  use ExUnit.Case, async: true

  alias MingaOrg.Tags

  describe "parse_heading/1" do
    test "parses heading with tags" do
      result = Tags.parse_heading("* My Heading :work:urgent:")
      assert result.stars == "*"
      assert result.title == "My Heading"
      assert result.tags == ["work", "urgent"]
    end

    test "parses heading without tags" do
      result = Tags.parse_heading("** No tags here")
      assert result.stars == "**"
      assert result.title == "No tags here"
      assert result.tags == []
    end

    test "parses heading with single tag" do
      result = Tags.parse_heading("* Task :todo:")
      assert result.tags == ["todo"]
    end

    test "returns not_heading for non-heading" do
      assert :not_heading = Tags.parse_heading("Not a heading")
    end

    test "returns not_heading for empty string" do
      assert :not_heading = Tags.parse_heading("")
    end

    test "handles tags with numbers and special chars" do
      result = Tags.parse_heading("* Item :tag1:@context:project_x:")
      assert result.tags == ["tag1", "@context", "project_x"]
    end
  end

  describe "add_tag/2" do
    test "adds tag to untagged heading" do
      assert "* Heading :work:" = Tags.add_tag("* Heading", "work")
    end

    test "adds tag to already-tagged heading" do
      assert "* Heading :work:urgent:" = Tags.add_tag("* Heading :work:", "urgent")
    end

    test "does not duplicate existing tag" do
      assert "* Heading :work:" = Tags.add_tag("* Heading :work:", "work")
    end

    test "returns non-heading unchanged" do
      assert "Not a heading" = Tags.add_tag("Not a heading", "tag")
    end
  end

  describe "remove_tag/2" do
    test "removes a tag" do
      assert "* Heading :urgent:" = Tags.remove_tag("* Heading :work:urgent:", "work")
    end

    test "removes last tag" do
      assert "* Heading" = Tags.remove_tag("* Heading :work:", "work")
    end

    test "no-op when tag doesn't exist" do
      assert "* Heading :work:" = Tags.remove_tag("* Heading :work:", "missing")
    end
  end

  describe "toggle_tag/2" do
    test "adds tag when absent" do
      assert "* Heading :work:" = Tags.toggle_tag("* Heading", "work")
    end

    test "removes tag when present" do
      assert "* Heading" = Tags.toggle_tag("* Heading :work:", "work")
    end
  end

  describe "collect_all_tags/1" do
    test "collects all unique tags from lines" do
      lines = [
        "* Task 1 :work:urgent:",
        "Some body text",
        "** Sub task :work:review:",
        "* Task 2 :personal:"
      ]

      assert ["personal", "review", "urgent", "work"] = Tags.collect_all_tags(lines)
    end

    test "returns empty for no headings" do
      assert [] = Tags.collect_all_tags(["No headings", "at all"])
    end

    test "returns empty for headings without tags" do
      assert [] = Tags.collect_all_tags(["* Heading 1", "* Heading 2"])
    end
  end

  describe "format_heading/3" do
    test "formats heading with tags" do
      assert "* Title :a:b:" = Tags.format_heading("*", "Title", ["a", "b"])
    end

    test "formats heading without tags" do
      assert "** Title" = Tags.format_heading("**", "Title", [])
    end
  end
end
