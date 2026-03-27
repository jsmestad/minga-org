defmodule MingaOrg.ExportPickerTest do
  use ExUnit.Case, async: true

  alias MingaOrg.Export
  alias MingaOrg.ExportPicker

  describe "candidates/1" do
    test "returns one candidate per format" do
      candidates = ExportPicker.candidates(nil)
      assert length(candidates) == length(Export.formats())
    end

    test "each candidate has an id matching the pandoc format" do
      ids = ExportPicker.candidates(nil) |> Enum.map(& &1.id)

      assert "html" in ids
      assert "pdf" in ids
      assert "markdown" in ids
    end

    test "each candidate is a Picker.Item struct" do
      for item <- ExportPicker.candidates(nil) do
        assert %Minga.UI.Picker.Item{} = item
        assert is_binary(item.label)
        assert is_binary(item.description)
      end
    end
  end

  describe "title/0" do
    test "returns a non-empty string" do
      assert is_binary(ExportPicker.title())
    end
  end

  describe "on_cancel/1" do
    test "returns state unchanged" do
      state = %{some: :state}
      assert ExportPicker.on_cancel(state) == state
    end
  end
end
