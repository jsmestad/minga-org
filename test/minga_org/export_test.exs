defmodule MingaOrg.ExportTest do
  use ExUnit.Case, async: true

  alias MingaOrg.Export

  describe "output_path_for/2" do
    test "html extension" do
      assert "/path/notes.html" = Export.output_path_for("/path/notes.org", "html")
    end

    test "pdf extension" do
      assert "/path/notes.pdf" = Export.output_path_for("/path/notes.org", "pdf")
    end

    test "markdown gets .md extension" do
      assert "/path/notes.md" = Export.output_path_for("/path/notes.org", "markdown")
    end

    test "latex gets .tex extension" do
      assert "/path/notes.tex" = Export.output_path_for("/path/notes.org", "latex")
    end

    test "asciidoc gets .adoc extension" do
      assert "/path/notes.adoc" = Export.output_path_for("/path/notes.org", "asciidoc")
    end

    test "rst gets .rst extension" do
      assert "/path/notes.rst" = Export.output_path_for("/path/notes.org", "rst")
    end

    test "docx gets .docx extension" do
      assert "/path/notes.docx" = Export.output_path_for("/path/notes.org", "docx")
    end

    test "handles nested paths" do
      assert "/a/b/c/doc.html" = Export.output_path_for("/a/b/c/doc.org", "html")
    end
  end

  describe "formats/0" do
    test "returns a non-empty list of format tuples" do
      formats = Export.formats()
      assert length(formats) > 0
      assert {"html", "HTML"} in formats
      assert {"pdf", "PDF"} in formats
    end
  end

  describe "check_pandoc/0" do
    test "returns ok or error (integration test)" do
      result = Export.check_pandoc()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
