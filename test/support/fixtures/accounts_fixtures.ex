defmodule Showish.AccountsFixtures do
  @moduledoc """
  Test helpers for creating accounts.
  """

  alias Showish.Accounts
  alias Showish.Accounts.Scope
  alias Showish.Accounts.User

  def unique_user_email, do: "operator#{System.unique_integer([:positive])}@example.com"

  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.register_user()

    user
  end

  @doc "A scope for a fresh user, or for one you already have."
  def user_scope_fixture(user_or_attrs \\ %{})

  def user_scope_fixture(%User{} = user), do: Scope.for_user(user)

  def user_scope_fixture(attrs), do: attrs |> user_fixture() |> Scope.for_user()
end
