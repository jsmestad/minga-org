defmodule MingaOrg.InlineTest do
  use ExUnit.Case, async: true

  alias MingaOrg.Inline
  alias MingaOrg.Inline.Span

  describe "parse/1" do
    test "parses bold markup" do
      assert [%Span{type: :bold, content: "bold", start: 0, end_: 6}] =
               Inline.parse("*bold* text")
    end

    test "parses italic markup" do
      assert [%Span{type: :italic, content: "italic"}] = Inline.parse("/italic/ text")
    end

    test "parses code markup" do
      assert [%Span{type: :code, content: "code"}] = Inline.parse("~code~ text")
    end

    test "parses verbatim markup" do
      assert [%Span{type: :verbatim, content: "verbatim"}] = Inline.parse("=verbatim= text")
    end

    test "parses strikethrough markup" do
      assert [%Span{type: :strikethrough, content: "deleted"}] = Inline.parse("+deleted+ text")
    end

    test "parses multiple markup spans in one line" do
      spans = Inline.parse("This is *bold* and /italic/ text")
      assert length(spans) == 2
      assert Enum.at(spans, 0).type == :bold
      assert Enum.at(spans, 0).content == "bold"
      assert Enum.at(spans, 1).type == :italic
      assert Enum.at(spans, 1).content == "italic"
    end

    test "returns empty list for no markup" do
      assert [] = Inline.parse("No markup here")
    end

    test "returns empty list for empty string" do
      assert [] = Inline.parse("")
    end

    test "requires non-empty content" do
      assert [] = Inline.parse("** not bold")
    end

    test "markup at start of line" do
      assert [%Span{type: :bold, content: "start", start: 0}] = Inline.parse("*start* of line")
    end

    test "markup at end of line" do
      assert [%Span{type: :bold, content: "end"}] = Inline.parse("at the *end*")
    end

    test "markup spanning entire line" do
      assert [%Span{type: :bold, content: "all bold"}] = Inline.parse("*all bold*")
    end

    test "opening delimiter must be preceded by whitespace or start of line" do
      assert [] = Inline.parse("no*bold*here")
    end

    test "closing delimiter must be followed by whitespace or end of line" do
      assert [] = Inline.parse("*bold*nope")
    end

    test "closing delimiter followed by punctuation is valid" do
      assert [%Span{type: :bold, content: "bold"}] = Inline.parse("*bold*.")
      assert [%Span{type: :bold, content: "bold"}] = Inline.parse("*bold*,")
      assert [%Span{type: :bold, content: "bold"}] = Inline.parse("*bold*!")
      assert [%Span{type: :bold, content: "bold"}] = Inline.parse("*bold*?")
      assert [%Span{type: :bold, content: "bold"}] = Inline.parse("*bold*;")
    end

    test "opening delimiter after punctuation is valid" do
      assert [%Span{type: :bold, content: "bold"}] = Inline.parse("(*bold*)")
      assert [%Span{type: :bold, content: "bold"}] = Inline.parse("\"*bold*\"")
    end

    test "does not nest markup" do
      spans = Inline.parse("*bold /text/*")
      assert length(spans) == 1
      assert hd(spans).type == :bold
      assert hd(spans).content == "bold /text/"
    end

    test "handles adjacent markup spans" do
      spans = Inline.parse("*bold* /italic/")
      assert length(spans) == 2
      assert Enum.at(spans, 0).type == :bold
      assert Enum.at(spans, 1).type == :italic
    end

    test "handles markup with unicode content" do
      assert [%Span{type: :bold, content: "ünïcödé"}] = Inline.parse("*ünïcödé*")
    end

    test "codepoint positions correct for ASCII" do
      [span] = Inline.parse("hello *world* end")
      assert span.start == 6
      assert span.content_start == 7
      assert span.content_end == 12
      assert span.end_ == 13
      assert span.content == "world"
    end

    test "codepoint positions correct with multi-byte characters before markup" do
      # "café " is 5 codepoints (c=1, a=1, f=1, é=1, space=1)
      # but 6 bytes (é is 2 bytes in UTF-8)
      [span] = Inline.parse("café *bold*")
      assert span.start == 5
      assert span.content_start == 6
      assert span.content_end == 10
      assert span.end_ == 11
    end

    test "codepoint positions correct with emoji before markup" do
      # "🎉 " is 2 codepoints (emoji=1, space=1) but 5 bytes
      [span] = Inline.parse("🎉 *bold*")
      assert span.start == 2
      assert span.content_start == 3
      assert span.content_end == 7
      assert span.end_ == 8
    end

    test "handles code with special characters inside" do
      assert [%Span{type: :code, content: "x + y = z"}] = Inline.parse("~x + y = z~")
    end

    test "single character content is valid" do
      assert [%Span{type: :bold, content: "x"}] = Inline.parse("*x*")
    end

    test "unmatched opening delimiter is ignored" do
      assert [] = Inline.parse("*no closing")
    end

    test "unmatched closing delimiter is ignored" do
      assert [] = Inline.parse("no opening*")
    end

    test "multiple same-type spans" do
      spans = Inline.parse("*one* and *two*")
      assert length(spans) == 2
      assert Enum.at(spans, 0).content == "one"
      assert Enum.at(spans, 1).content == "two"
    end

    test "mixed types interleaved" do
      spans = Inline.parse("*bold* then ~code~ then /italic/")
      types = Enum.map(spans, & &1.type)
      assert types == [:bold, :code, :italic]
    end

    test "delimiter inside code/verbatim is literal" do
      assert [%Span{type: :code, content: "code *with* stars"}] =
               Inline.parse("~code *with* stars~")
    end
  end

  describe "style_for/1" do
    test "bold returns bold style" do
      assert [bold: true] = Inline.style_for(:bold)
    end

    test "italic returns italic style" do
      assert [italic: true] = Inline.style_for(:italic)
    end

    test "code returns background style" do
      assert [bg: _] = Inline.style_for(:code)
    end

    test "verbatim returns foreground style" do
      assert [fg: _] = Inline.style_for(:verbatim)
    end

    test "strikethrough returns strikethrough style" do
      assert [strikethrough: true] = Inline.style_for(:strikethrough)
    end
  end
end
