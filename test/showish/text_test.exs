defmodule Showish.TextTest do
  use ExUnit.Case, async: true

  alias Showish.Text

  doctest Showish.Text

  describe "present?/1 and blank?/1" do
    test "a field of nothing but whitespace counts as empty" do
      refute Text.present?("   ")
      assert Text.blank?("\n\t")
    end

    test "nil and non-strings are tolerated, because schemas and forms both feed this" do
      refute Text.present?(nil)
      assert Text.present?(:caster)
      assert Text.present?(7)
    end
  end

  describe "presence/2" do
    test "trims what is there" do
      assert Text.presence("  Grand Finals  ") == "Grand Finals"
    end

    test "falls back when there is nothing" do
      assert Text.presence(nil, "TBD") == "TBD"
      assert Text.presence("  ", "TBD") == "TBD"
    end

    test "falls back to an empty string by default" do
      assert Text.presence(nil) == ""
    end
  end

  describe "first_present/2" do
    test "takes the first value with something in it" do
      assert Text.first_present([nil, "  ", "Kings", "Harbour Kings"], "TBD") == "Kings"
    end

    test "falls back when every value is empty" do
      assert Text.first_present([nil, "", "  "], "TBD") == "TBD"
    end
  end

  describe "join_present/2" do
    test "leaves no separator behind for the values that are empty" do
      assert Text.join_present(["Game 1", "", nil, "Control"]) == "Game 1 · Control"
    end

    test "is empty when everything is" do
      assert Text.join_present([nil, "  "]) == ""
    end

    test "takes a separator of its own" do
      assert Text.join_present(["Kings", "Foxes"], " vs ") == "Kings vs Foxes"
    end
  end
end
