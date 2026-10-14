defmodule Showish.Accounts.AllowlistTest do
  # Not async: every test here moves the list in the application environment,
  # which is global.
  use Showish.DataCase, async: false

  import Showish.AccountsFixtures

  alias Showish.Accounts
  alias Showish.Accounts.Allowlist
  alias Showish.Accounts.User

  setup do
    original = Application.get_env(:showish, Allowlist)
    on_exit(fn -> restore(original) end)
  end

  defp put_list(emails), do: Application.put_env(:showish, Allowlist, emails: emails)

  # Putting `nil` back is not the same as never having set the key: the key then
  # exists holding nil, and `Application.get_env/3` hands back the nil rather
  # than its default.
  defp restore(nil), do: Application.delete_env(:showish, Allowlist)
  defp restore(original), do: Application.put_env(:showish, Allowlist, original)

  describe "with no list configured" do
    test "lets everyone in" do
      Application.delete_env(:showish, Allowlist)

      assert Allowlist.emails() == []
      refute Allowlist.enforced?()
      assert Allowlist.allows?("anyone@example.com")
    end

    test "treats an empty list the same as no list" do
      put_list([])

      refute Allowlist.enforced?()
      assert Allowlist.allows?("anyone@example.com")
    end

    test "treats a variable set to nothing but separators the same as no list" do
      put_list(" , ,")

      refute Allowlist.enforced?()
      assert Allowlist.allows?("anyone@example.com")
    end
  end

  describe "with a list configured" do
    setup do
      put_list(["operator@example.com", "producer@example.com"])
      :ok
    end

    test "admits an address on the list" do
      assert Allowlist.enforced?()
      assert Allowlist.allows?("operator@example.com")
      assert Allowlist.allows?("producer@example.com")
    end

    test "turns away an address that is not" do
      refute Allowlist.allows?("stranger@example.com")
    end

    test "does not match on a substring" do
      refute Allowlist.allows?("operator@example.com.attacker.test")
      refute Allowlist.allows?("notoperator@example.com")
    end

    test "ignores case, because Google may not return the address as it was typed in" do
      assert Allowlist.allows?("Operator@Example.COM")
    end

    test "turns away anything that is not a string" do
      refute Allowlist.allows?(nil)
    end
  end

  describe "the comma-separated form an environment variable arrives in" do
    test "is split, trimmed and lowercased" do
      put_list(" Operator@example.com ,producer@example.com,, ")

      assert Allowlist.emails() == ["operator@example.com", "producer@example.com"]
      assert Allowlist.allows?("producer@example.com")
      refute Allowlist.allows?("stranger@example.com")
    end

    test "holds a single address" do
      put_list("solo@example.com")

      assert Allowlist.enforced?()
      assert Allowlist.allows?("solo@example.com")
      refute Allowlist.allows?("stranger@example.com")
    end
  end

  describe "Accounts.sign_in_with_google/1 against a list" do
    test "signs in an address on the list" do
      put_list("bo@example.com")

      assert {:ok, %User{email: "bo@example.com"}} =
               Accounts.sign_in_with_google(google_profile(email: "bo@example.com"))
    end

    test "refuses an address that is not, and leaves no account behind" do
      put_list("bo@example.com")

      assert {:error, :not_allowed} =
               Accounts.sign_in_with_google(google_profile(email: "stranger@example.com"))

      assert Repo.aggregate(User, :count) == 0
    end

    test "locks out someone taken off the list after they had signed in" do
      put_list("bo@example.com")
      profile = google_profile(email: "bo@example.com")
      assert {:ok, _user} = Accounts.sign_in_with_google(profile)

      put_list("someone-else@example.com")

      assert {:error, :not_allowed} = Accounts.sign_in_with_google(profile)
    end

    test "will not sign in a provisioned account that is not on the list" do
      provisioned_user_fixture(%{email: "waiting@example.com"})
      put_list("bo@example.com")

      assert {:error, :not_allowed} =
               Accounts.sign_in_with_google(google_profile(email: "waiting@example.com"))
    end
  end
end
