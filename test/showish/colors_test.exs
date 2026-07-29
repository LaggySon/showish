defmodule Showish.ColorsTest do
  use ExUnit.Case, async: true

  alias Showish.Colors

  doctest Showish.Colors

  describe "normalize/2" do
    test "expands shorthand and lowercases" do
      assert Colors.normalize("#ABC") == "#aabbcc"
      assert Colors.normalize("#1F2937") == "#1f2937"
    end

    test "falls back for anything that is not a hex color" do
      assert Colors.normalize("rebeccapurple", "#000000") == "#000000"
      assert Colors.normalize("#12345", "#000000") == "#000000"
      assert Colors.normalize(nil, "#000000") == "#000000"
    end
  end

  describe "contrast_text/1" do
    test "picks dark text on light backgrounds and light text on dark" do
      assert Colors.contrast_text("#ffffff") == "#0b0f14"
      assert Colors.contrast_text("#000000") == "#ffffff"
      assert Colors.contrast_text("#2563eb") == "#ffffff"
    end

    test "falls back when the color cannot be parsed" do
      assert Colors.contrast_text("not a color", "#ffffff") == "#ffffff"
    end
  end

  describe "rgba/3" do
    test "builds a css rgba string" do
      assert Colors.rgba("#2563eb", 0.5) == "rgba(37, 99, 235, 0.5)"
    end

    test "falls back for unparseable input" do
      assert Colors.rgba("nope", 0.5, "transparent") == "transparent"
    end
  end
end
