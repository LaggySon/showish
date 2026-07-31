defmodule Showish.AccountsTest do
  use Showish.DataCase, async: true

  import Showish.AccountsFixtures

  alias Showish.Accounts
  alias Showish.Accounts.User

  describe "sign_in_with_google/1" do
    test "creates an account the first time someone signs in" do
      profile = google_profile(email: "bo@example.com", name: "Bo Ferreira")

      assert {:ok, %User{} = user} = Accounts.sign_in_with_google(profile)
      assert user.email == "bo@example.com"
      assert user.google_id == profile.google_id
      assert user.name == "Bo Ferreira"
      assert user.avatar_url == profile.avatar_url
    end

    test "signs the same person back in rather than creating a second account" do
      profile = google_profile()
      {:ok, first} = Accounts.sign_in_with_google(profile)

      assert {:ok, second} = Accounts.sign_in_with_google(profile)
      assert second.id == first.id
      assert Repo.aggregate(User, :count) == 1
    end

    test "picks up a name or picture changed at Google" do
      profile = google_profile(name: "Bo", avatar_url: "https://example.com/old.png")
      {:ok, user} = Accounts.sign_in_with_google(profile)

      assert {:ok, updated} =
               Accounts.sign_in_with_google(%{
                 profile
                 | name: "Bo Ferreira",
                   avatar_url: "https://example.com/new.png"
               })

      assert updated.id == user.id
      assert updated.name == "Bo Ferreira"
      assert updated.avatar_url == "https://example.com/new.png"
    end

    test "claims an account that was provisioned by address" do
      provisioned = provisioned_user_fixture(%{email: "waiting@example.com"})
      refute provisioned.google_id

      profile = google_profile(email: "waiting@example.com")

      assert {:ok, user} = Accounts.sign_in_with_google(profile)
      assert user.id == provisioned.id
      assert user.google_id == profile.google_id
      assert Repo.aggregate(User, :count) == 1
    end

    test "follows the subject id when someone changes their address at Google" do
      profile = google_profile(email: "old@example.com")
      {:ok, user} = Accounts.sign_in_with_google(profile)

      assert {:ok, updated} = Accounts.sign_in_with_google(%{profile | email: "new@example.com"})
      assert updated.id == user.id
      assert updated.email == "new@example.com"
    end

    test "will not let a second Google account take over an address in use" do
      existing = user_fixture(%{email: "taken@example.com"})

      assert {:error, :email_taken} =
               Accounts.sign_in_with_google(google_profile(email: "taken@example.com"))

      assert Accounts.get_user!(existing.id).google_id == existing.google_id
      assert Repo.aggregate(User, :count) == 1
    end
  end

  describe "provision_user/1" do
    test "creates an account that has never signed in" do
      assert {:ok, user} = Accounts.provision_user(%{email: "waiting@example.com"})
      assert user.email == "waiting@example.com"
      refute user.google_id
    end

    test "rejects an address that is not one" do
      assert {:error, changeset} = Accounts.provision_user(%{email: "not an address"})
      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "refuses an address that is already here" do
      user_fixture(%{email: "taken@example.com"})

      assert {:error, changeset} = Accounts.provision_user(%{email: "taken@example.com"})
      assert "has already been taken" in errors_on(changeset).email
    end
  end

  describe "get_user_by_email/1" do
    test "is case-insensitive" do
      user = user_fixture(%{email: "Bo@Example.com"})

      assert Accounts.get_user_by_email("bo@example.com").id == user.id
    end
  end

  describe "session tokens" do
    setup do
      %{user: user_fixture()}
    end

    test "a generated token identifies its user", %{user: user} do
      token = Accounts.generate_user_session_token(user)

      assert Accounts.get_user_by_session_token(token).id == user.id
    end

    test "an unknown or deleted token identifies nobody", %{user: user} do
      token = Accounts.generate_user_session_token(user)

      refute Accounts.get_user_by_session_token("made up")

      :ok = Accounts.delete_user_session_token(token)
      refute Accounts.get_user_by_session_token(token)
    end

    test "signing out everywhere revokes every session", %{user: user} do
      one = Accounts.generate_user_session_token(user)
      two = Accounts.generate_user_session_token(user)

      :ok = Accounts.delete_all_user_session_tokens(user)

      refute Accounts.get_user_by_session_token(one)
      refute Accounts.get_user_by_session_token(two)
    end
  end
end
