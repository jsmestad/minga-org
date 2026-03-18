defmodule MingaOrg.LinkTest do
  use ExUnit.Case, async: true

  alias MingaOrg.Link
  alias MingaOrg.Link.Parsed

  describe "parse/1" do
    test "parses link with description" do
      [link] = Link.parse("See [[https://example.com][Example]] for details")
      assert link.url == "https://example.com"
      assert link.description == "Example"
      assert link.display_text == "Example"
      assert link.link_type == :external
    end

    test "parses link without description" do
      [link] = Link.parse("Visit [[https://example.com]] today")
      assert link.url == "https://example.com"
      assert link.description == nil
      assert link.display_text == "https://example.com"
      assert link.link_type == :external
    end

    test "parses heading link" do
      [link] = Link.parse("See [[*Introduction]] above")
      assert link.url == "*Introduction"
      assert link.link_type == :heading
    end

    test "parses file link" do
      [link] = Link.parse("Open [[file:notes.org]]")
      assert link.url == "file:notes.org"
      assert link.link_type == :file
    end

    test "parses file link with description" do
      [link] = Link.parse("[[file:~/docs/readme.md][README]]")
      assert link.url == "file:~/docs/readme.md"
      assert link.description == "README"
      assert link.link_type == :file
    end

    test "parses internal link" do
      [link] = Link.parse("See [[custom-id]] for reference")
      assert link.url == "custom-id"
      assert link.link_type == :internal
    end

    test "parses multiple links in one line" do
      links = Link.parse("[[https://a.com][A]] and [[https://b.com][B]]")
      assert length(links) == 2
      assert Enum.at(links, 0).url == "https://a.com"
      assert Enum.at(links, 1).url == "https://b.com"
    end

    test "returns empty list for no links" do
      assert [] = Link.parse("No links here")
    end

    test "returns empty list for empty string" do
      assert [] = Link.parse("")
    end

    test "ignores unclosed links" do
      assert [] = Link.parse("[[unclosed link")
    end

    test "ignores single brackets" do
      assert [] = Link.parse("[not a link]")
    end

    test "correct codepoint positions" do
      [link] = Link.parse("ab [[url][desc]] end")
      assert link.start == 3
      assert link.end_ == 16
    end

    test "correct positions with unicode before link" do
      [link] = Link.parse("café [[url][desc]]")
      # café = 4 codepoints, then space = 5
      assert link.start == 5
    end

    test "link at start of line" do
      [link] = Link.parse("[[https://example.com][Click]]")
      assert link.start == 0
    end

    test "link at end of line" do
      [link] = Link.parse("end [[url]]")
      assert link.url == "url"
    end

    test "handles http link" do
      [link] = Link.parse("[[http://insecure.com]]")
      assert link.link_type == :external
    end

    test "parses link with spaces in description" do
      [link] = Link.parse("[[url][A longer description]]")
      assert link.description == "A longer description"
    end

    test "parses link with special chars in URL" do
      [link] = Link.parse("[[https://example.com/path?q=1&b=2#frag][Link]]")
      assert link.url == "https://example.com/path?q=1&b=2#frag"
    end
  end

  describe "link_at/2" do
    test "finds link at cursor position" do
      line = "See [[https://example.com][Example]] end"
      assert {:ok, link} = Link.link_at(line, 5)
      assert link.url == "https://example.com"
    end

    test "returns :none when cursor is not on a link" do
      assert :none = Link.link_at("See [[url]] end", 0)
    end

    test "returns :none for empty line" do
      assert :none = Link.link_at("", 0)
    end

    test "finds correct link when multiple exist" do
      line = "[[a][A]] and [[b][B]]"
      assert {:ok, link_a} = Link.link_at(line, 0)
      assert link_a.description == "A"
      assert {:ok, link_b} = Link.link_at(line, 14)
      assert link_b.description == "B"
    end
  end

  describe "follow_action/1" do
    test "external URL returns browser action" do
      link = %Parsed{
        url: "https://example.com",
        description: nil,
        start: 0,
        end_: 10,
        link_type: :external,
        display_text: "https://example.com"
      }

      assert {:browser, "https://example.com"} = Link.follow_action(link)
    end

    test "file link returns file action" do
      link = %Parsed{
        url: "file:notes.org",
        description: nil,
        start: 0,
        end_: 10,
        link_type: :file,
        display_text: "file:notes.org"
      }

      assert {:file, "notes.org"} = Link.follow_action(link)
    end

    test "heading link returns heading action" do
      link = %Parsed{
        url: "*Introduction",
        description: nil,
        start: 0,
        end_: 10,
        link_type: :heading,
        display_text: "*Introduction"
      }

      assert {:heading, "Introduction"} = Link.follow_action(link)
    end
  end

  describe "classify_url/1" do
    test "https is external" do
      assert :external = Link.classify_url("https://example.com")
    end

    test "http is external" do
      assert :external = Link.classify_url("http://example.com")
    end

    test "file: prefix is file" do
      assert :file = Link.classify_url("file:path.org")
    end

    test "* prefix is heading" do
      assert :heading = Link.classify_url("*My Heading")
    end

    test "anything else is internal" do
      assert :internal = Link.classify_url("custom-id")
    end
  end
end
