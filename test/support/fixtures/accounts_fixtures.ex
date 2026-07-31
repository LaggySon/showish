defmodule Showish.AccountsFixtures do
  @moduledoc """
  Test helpers for creating accounts.
  """

  alias Showish.Accounts
  alias Showish.Accounts.Scope
  alias Showish.Accounts.User

  def unique_user_email, do: "operator#{System.unique_integer([:positive])}@example.com"

  def unique_google_id, do: "google-#{System.unique_integer([:positive])}"

  @doc "A Google profile of the shape `Showish.Accounts.Google` hands back."
  def google_profile(attrs \\ %{}) do
    Enum.into(attrs, %{
      google_id: unique_google_id(),
      email: unique_user_email(),
      name: "Bo Ferreira",
      avatar_url: "https://example.com/avatar.png"
    })
  end

  @doc "The claims Google's userinfo endpoint returns for that profile."
  def google_claims(attrs \\ %{}) do
    profile = google_profile(attrs)

    %{
      "sub" => profile.google_id,
      "email" => profile.email,
      "email_verified" => true,
      "name" => profile.name,
      "picture" => profile.avatar_url
    }
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> google_profile()
      |> Accounts.sign_in_with_google()

    user
  end

  @doc "An account that exists but has never signed in."
  def provisioned_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{email: unique_user_email()})
      |> Accounts.provision_user()

    user
  end

  @doc "A scope for a fresh user, or for one you already have."
  def user_scope_fixture(user_or_attrs \\ %{})

  def user_scope_fixture(%User{} = user), do: Scope.for_user(user)

  def user_scope_fixture(attrs), do: attrs |> user_fixture() |> Scope.for_user()
end
