defmodule Showish.SeedsTest do
  use Showish.DataCase, async: false

  import Showish.AccountsFixtures

  alias Showish.Accounts
  alias Showish.Broadcasts
  alias Showish.Seeds

  test "makes an esports and a baseball example for their owner" do
    assert Seeds.run(email: "reviewer@example.com") == [
             created: "demo",
             created: "demo-baseball",
             created: "Acme Esports (theme)",
             created: "Ballpark (theme)"
           ]

    owner = Accounts.get_user_by_email("reviewer@example.com")
    scope = user_scope_fixture(owner)

    esports = Broadcasts.get_show_by_slug!(scope, "demo")
    assert length(esports.games) == 5
    assert esports.current_game == 4

    baseball = Broadcasts.get_show_by_slug!(scope, "demo-baseball")
    assert baseball.sport == "baseball"
    assert length(baseball.sport_state["lineups"]["1"]) == 9
  end

  test "keeps examples that exist, so a preview keeps a reviewer's changes" do
    Seeds.run(email: "reviewer@example.com")
    scope = "reviewer@example.com" |> Accounts.get_user_by_email() |> user_scope_fixture()
    show = Broadcasts.get_show_by_slug!(scope, "demo")
    {:ok, _show} = Broadcasts.update_show(scope, show, %{"title" => "Edited in review"})

    assert Seeds.run(email: "reviewer@example.com") == [
             kept: "demo",
             kept: "demo-baseball",
             kept: "Acme Esports (theme)",
             kept: "Ballpark (theme)"
           ]

    assert Broadcasts.get_show_by_slug!(scope, "demo").title == "Edited in review"

    assert Seeds.run(email: "reviewer@example.com", reset: true) == [
             reset: "demo",
             reset: "demo-baseball",
             reset: "Acme Esports (theme)",
             reset: "Ballpark (theme)"
           ]

    assert Broadcasts.get_show_by_slug!(scope, "demo").title == "Showish Invitational"
  end

  test "never takes over a slug somebody else owns, but gives everyone the themes" do
    Seeds.run(email: "first@example.com")

    assert Seeds.run(email: "second@example.com", reset: true) == [
             {:skipped, "demo", :owned_by_someone_else},
             {:skipped, "demo-baseball", :owned_by_someone_else},
             {:created, "Acme Esports (theme)"},
             {:created, "Ballpark (theme)"}
           ]
  end

  test "the example themes are valid themes the Look menu can use" do
    Seeds.run(email: "reviewer@example.com")
    scope = "reviewer@example.com" |> Accounts.get_user_by_email() |> user_scope_fixture()

    assert [%{name: "Acme Esports", base: "broadcast"}, %{name: "Ballpark", base: "laggish"}] =
             Showish.Themes.list_themes(scope)
  end

  describe "the owner" do
    setup do
      previous = {System.get_env("SEED_EMAIL"), Application.get_env(:showish, Accounts.Allowlist)}

      on_exit(fn ->
        {email, allowlist} = previous
        if email, do: System.put_env("SEED_EMAIL", email), else: System.delete_env("SEED_EMAIL")

        if allowlist,
          do: Application.put_env(:showish, Accounts.Allowlist, allowlist),
          else: Application.delete_env(:showish, Accounts.Allowlist)
      end)
    end

    test "is SEED_EMAIL, then the first allowed address, then the example address" do
      System.delete_env("SEED_EMAIL")
      Application.put_env(:showish, Accounts.Allowlist, emails: [])
      assert Seeds.owner_email() == "operator@example.com"

      Application.put_env(:showish, Accounts.Allowlist,
        emails: "Reviewer@Example.com, other@example.com"
      )

      assert Seeds.owner_email() == "reviewer@example.com"

      System.put_env("SEED_EMAIL", "seed@example.com")
      assert Seeds.owner_email() == "seed@example.com"
    end
  end
end
