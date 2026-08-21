defmodule Showish.Baseball.NotationTest do
  use ExUnit.Case, async: true

  alias Showish.Baseball.Notation

  describe "interpret/2" do
    test "makes non-empty error notation authoritative over the selected out" do
      assert {:ok, %{result: "reached_on_error", notation: "E1"}} =
               Notation.interpret("e1", "out")

      assert {:ok, %{result: "reached_on_error", notation: "6-E3"}} =
               Notation.interpret("6–E3", "out")
    end

    test "canonicalizes fielder sequences and recognizes double and triple plays" do
      assert {:ok, %{result: "out", notation: "6-3"}} = Notation.interpret("63")

      assert {:ok, %{result: "double_play", notation: "4-6-3"}} =
               Notation.interpret("463")

      assert {:ok, %{result: "double_play", notation: "6-4-3 DP"}} =
               Notation.interpret("6-4-3 DP")

      assert {:ok, %{result: "triple_play", notation: "5-4-3 TP"}} =
               Notation.interpret("543 TP")
    end

    test "recognizes hits with scorebook and Retrosheet-style location suffixes" do
      for {notation, result} <- [
            {"1B7", "single"},
            {"S7/G.1-3", "single"},
            {"2B8", "double"},
            {"D8", "double"},
            {"3B9", "triple"},
            {"T9", "triple"},
            {"HR", "home_run"},
            {"=", "home_run"}
          ] do
        assert {:ok, %{result: ^result}} = Notation.interpret(notation)
      end
    end

    test "recognizes walks, hit batters, sacrifices, choices, and interference" do
      for {notation, result} <- [
            {"BB", "walk"},
            {"IBB", "walk"},
            {"HBP", "hit_by_pitch"},
            {"SF8", "sacrifice_fly"},
            {"SH3", "sacrifice_bunt"},
            {"FC6", "fielders_choice"},
            {"C/E2", "interference"},
            {"CI", "interference"}
          ] do
        assert {:ok, %{result: ^result}} = Notation.interpret(notation)
      end
    end

    test "recognizes strikeouts, dropped-third-strike reaches, and batted outs" do
      for notation <- ~w(K ꓘ KC KL KS K2-3) do
        assert {:ok, %{result: "strikeout"}} = Notation.interpret(notation)
      end

      for notation <- ["K+E2", "K WP", "KPB"] do
        assert {:ok, %{result: "strikeout_reached"}} = Notation.interpret(notation)
      end

      for notation <- ~w(F8 L6 P3 G63 U3) do
        assert {:ok, %{result: "out"}} = Notation.interpret(notation)
      end
    end

    test "uses the selected quick result only when notation is blank" do
      assert {:ok, %{result: "single", notation: ""}} = Notation.interpret("", "single")
      assert {:ok, %{result: "single", notation: ""}} = Notation.interpret(nil, "reached")
      assert {:error, :scorebook_notation_required} = Notation.interpret("", "auto")
    end

    test "allows a selected result to disambiguate a lone hit-location number" do
      assert {:ok, %{result: "single", notation: "9"}} = Notation.interpret("9", "single")
      assert {:ok, %{result: "out", notation: "9"}} = Notation.interpret("9", "auto")
    end

    test "does not silently turn runner events or invalid text into plate appearances" do
      for notation <- ~w(WP PB BK SB2 CS3 PO1) do
        assert {:error, :runner_event_does_not_end_at_bat} =
                 Notation.interpret(notation, "out")
      end

      assert {:error, :unrecognized_scorebook_notation} = Notation.interpret("NOT A PLAY", "out")

      assert {:error, :scorebook_notation_too_long} =
               Notation.interpret(String.duplicate("X", 41))
    end
  end
end
